local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local volumetricsConfig = require(script.Parent.Config)

local moduleFolder = script.Parent
local beamColorSequence = ColorSequence.new(volumetricsConfig.beam.color)

local cameraAnchorPartTemplate = Instance.new("Part")
cameraAnchorPartTemplate.CanCollide = false
cameraAnchorPartTemplate.CanQuery = false
cameraAnchorPartTemplate.CanTouch = false
cameraAnchorPartTemplate.CastShadow = false
cameraAnchorPartTemplate.Massless = true
cameraAnchorPartTemplate.Anchored = true
cameraAnchorPartTemplate.Transparency = volumetricsConfig.cameraAnchor.transparency
cameraAnchorPartTemplate.Size = volumetricsConfig.cameraAnchor.defaultSizeStuds
cameraAnchorPartTemplate.Material = volumetricsConfig.cameraAnchor.material

local volumetricsRenderer = {}
volumetricsRenderer.__index = volumetricsRenderer

volumetricsRenderer.__vars = {
	depth = 0,
	layerSpacingStuds = 0,
	transparency = 0.996,
	lightEmission = 1,
	isVisible = true,
	renderMethod = 1,
	previousRenderMethod = 1,
	particlesSkyCulled = false,
}

volumetricsRenderer.renderMethods = {
	Beams = 1,
	Billboards = 2,
	Particles = 3,
	Trails = 4,
}

export type volumetricsRendererInfo = {
	camera: Camera,
	depth: number,
	layerSpacingStuds: number,
	renderMethod: number?,
	transparency: number?,
	lightEmission: number?,
	isVisible: boolean?,
}

local function disconnectCameraConnections(renderer)
	local cameraConnections = renderer.cameraConnections

	for _, connection in pairs(cameraConnections) do
		connection:Disconnect()
	end

	table.clear(cameraConnections)
end

local function refreshCameraProperties(renderer)
	local camera = renderer.camera

	renderer.fieldOfViewDegrees = camera.FieldOfView
	renderer.viewportSizePixels = camera.ViewportSize
end

local function connectCameraSignals(renderer)
	local camera = renderer.camera
	local cameraConnections = renderer.cameraConnections
	local performanceConfig = volumetricsConfig.performance

	cameraConnections.fieldOfViewChanged = camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
		local fieldOfViewDegrees = camera.FieldOfView
		if
			math.abs(fieldOfViewDegrees - renderer.fieldOfViewDegrees)
			< performanceConfig.fieldOfViewRefreshThresholdDegrees
		then
			return
		end

		renderer.fieldOfViewDegrees = fieldOfViewDegrees
		renderer:renderVolumetrics()
	end)

	cameraConnections.viewportSizeChanged = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local viewportSizePixels = camera.ViewportSize
		local viewportChange = viewportSizePixels - renderer.viewportSizePixels
		if
			math.abs(viewportChange.X) < performanceConfig.viewportRefreshThresholdPixels
			and math.abs(viewportChange.Y) < performanceConfig.viewportRefreshThresholdPixels
		then
			return
		end

		renderer.viewportSizePixels = viewportSizePixels
		renderer:renderVolumetrics()
	end)
end

local function createVolumetricBeam(
	transparencySequence: NumberSequence,
	lightEmission: number,
	ratioY: number,
	layerSpacingStuds: number,
	layerDistanceStuds: number
): Beam
	local beam = Instance.new("Beam")

	local widthStuds = (ratioY * layerDistanceStuds) * (layerSpacingStuds * volumetricsConfig.beam.widthMultiplier)

	beam.Color = beamColorSequence
	beam.Transparency = transparencySequence
	beam.Segments = 1
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureSpeed = 0
	beam.LightEmission = lightEmission
	beam.LightInfluence = 1
	beam.Width0 = widthStuds
	beam.Width1 = widthStuds

	return beam
end

local function createVolumetricBillboard(transparency: number, viewportSizePixels: Vector2): BillboardGui
	local billboardGui = Instance.new("BillboardGui")
	local backgroundFrame = Instance.new("Frame")

	local framePaddingPixels = volumetricsConfig.billboard.framePaddingPixels

	billboardGui.Size = UDim2.fromOffset(viewportSizePixels.X, viewportSizePixels.Y)

	billboardGui.LightInfluence = 1
	billboardGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

	backgroundFrame.Name = "Frame"
	backgroundFrame.Position = UDim2.fromOffset(-framePaddingPixels, -framePaddingPixels)

	backgroundFrame.Size = UDim2.new(1, framePaddingPixels * 2, 1, framePaddingPixels * 2)

	backgroundFrame.BackgroundTransparency = transparency
	backgroundFrame.AutoLocalize = false
	backgroundFrame.Interactable = false
	backgroundFrame.Active = false
	backgroundFrame.Parent = billboardGui

	return billboardGui
end

local function createVolumetricTrail(transparencySequence: NumberSequence, lightEmission: number): Trail
	local trail = Instance.new("Trail")

	trail.Transparency = transparencySequence
	trail.LightInfluence = 1
	trail.LightEmission = lightEmission
	trail.TextureMode = Enum.TextureMode.Static
	trail.FaceCamera = false
	trail.Lifetime = volumetricsConfig.trail.lifetimeSeconds

	return trail
end

local function updateLayerVisibility(layers: { Instance }, depth: number, isVisible: boolean)
	for layerIndex, layerInstance in ipairs(layers) do
		if layerInstance:IsA("GuiBase2d") or layerInstance:IsA("Beam") or layerInstance:IsA("Trail") then
			layerInstance.Enabled = isVisible and layerIndex <= depth
		end
	end
end

local function getBillboardFrame(billboardGui: BillboardGui): Frame?
	local frame = billboardGui:FindFirstChild("Frame")

	if frame and frame:IsA("Frame") then
		return frame
	end

	return nil
end

local function renderBillboardLayers(renderer)
	local rendererState = renderer.__vars
	local cameraAnchorPart = renderer.cameraAnchorPart
	local layers = renderer.layers
	local viewportSizePixels = renderer.viewportSizePixels

	cameraAnchorPart.Size = volumetricsConfig.cameraAnchor.defaultSizeStuds

	updateLayerVisibility(layers, rendererState.depth, rendererState.isVisible)

	for layerIndex = 1, rendererState.depth do
		local layerDistanceStuds = (layerIndex - 1) * rendererState.layerSpacingStuds

		local billboardGui = layers[layerIndex]
		local attachment

		if billboardGui == nil then
			attachment = Instance.new("Attachment")

			billboardGui = createVolumetricBillboard(rendererState.transparency, viewportSizePixels)

			billboardGui.Parent = attachment
			attachment.Parent = cameraAnchorPart

			layers[layerIndex] = billboardGui
		else
			if not billboardGui:IsA("BillboardGui") or not billboardGui.Enabled then
				continue
			end

			billboardGui.Size = UDim2.fromOffset(viewportSizePixels.X, viewportSizePixels.Y)

			local backgroundFrame = getBillboardFrame(billboardGui)

			if backgroundFrame then
				backgroundFrame.BackgroundTransparency = rendererState.transparency
			end

			attachment = billboardGui.Parent

			if not attachment or not attachment:IsA("Attachment") then
				continue
			end
		end

		billboardGui.Enabled = rendererState.isVisible

		attachment.Position = Vector3.new(0, 0, -layerDistanceStuds)
	end
end

local function renderParticleLayers(renderer)
	local rendererState = renderer.__vars
	local cameraAnchorPart = renderer.cameraAnchorPart
	local particleEmitter = renderer.particleEmitter
	local particlesConfig = volumetricsConfig.particles
	local particleFadeTask = renderer.particleFadeTask

	cameraAnchorPart.Size = volumetricsConfig.cameraAnchor.particleSizeStuds

	if particleFadeTask ~= nil then
		task.cancel(particleFadeTask)
		renderer.particleFadeTask = nil
	end

	if rendererState.particlesSkyCulled then
		particleEmitter.Enabled = false
		particleEmitter.Parent = moduleFolder
		particleEmitter:Clear()
		return
	end

	particleEmitter.Enabled = rendererState.isVisible

	if rendererState.isVisible then
		particleEmitter.Parent = cameraAnchorPart
	else
		particleEmitter.Parent = moduleFolder
	end

	if particleEmitter.Parent == moduleFolder then
		particleEmitter.TimeScale = particlesConfig.resetTimeScale
	end

	if particleEmitter.Parent == cameraAnchorPart then
		renderer.particleFadeTask = task.delay(particlesConfig.fadeDelaySeconds, function()
			--// Sky culling can start while the fade delay is pending.
			if renderer.__vars.particlesSkyCulled then
				return
			end

			local particleFadeTween =
				tweenService:Create(particleEmitter, TweenInfo.new(particlesConfig.fadeDurationSeconds), {
					TimeScale = 0,
				})

			particleFadeTween.Completed:Once(function()
				particleFadeTween:Destroy()
			end)

			particleFadeTween:Play()
		end)
	end

	particleEmitter.Transparency = NumberSequence.new(rendererState.transparency)
end

local function renderBeamLayers(renderer)
	local rendererState = renderer.__vars
	local cameraAnchorPart = renderer.cameraAnchorPart
	local layers = renderer.layers
	local fieldOfViewDegrees = renderer.fieldOfViewDegrees
	local viewportSizePixels = renderer.viewportSizePixels

	local verticalViewRatio = math.tan(math.rad(fieldOfViewDegrees / 2))
	local horizontalViewRatio = (viewportSizePixels.X * verticalViewRatio) / viewportSizePixels.Y

	local beamWidthMultiplier = math.max(rendererState.layerSpacingStuds, 1) * volumetricsConfig.beam.widthMultiplier

	local horizontalPadding = volumetricsConfig.beam.horizontalPaddingMultiplier
	local transparencySequence = NumberSequence.new(rendererState.transparency)

	cameraAnchorPart.Size = volumetricsConfig.cameraAnchor.defaultSizeStuds

	updateLayerVisibility(layers, rendererState.depth, rendererState.isVisible)

	for layerIndex = 1, rendererState.depth do
		local layerDistanceStuds = (layerIndex - 1) * rendererState.layerSpacingStuds

		local beam = layers[layerIndex]

		local startAttachment
		local endAttachment

		if beam == nil then
			beam = createVolumetricBeam(
				transparencySequence,
				rendererState.lightEmission,
				verticalViewRatio,
				rendererState.layerSpacingStuds,
				layerDistanceStuds
			)

			startAttachment = Instance.new("Attachment")
			endAttachment = Instance.new("Attachment")

			beam.Name = ("Beam%d"):format(layerIndex)
			startAttachment.Name = ("AttachmentA%d"):format(layerIndex)
			endAttachment.Name = ("AttachmentB%d"):format(layerIndex)

			beam.Attachment0 = startAttachment
			beam.Attachment1 = endAttachment

			beam.Parent = cameraAnchorPart
			startAttachment.Parent = cameraAnchorPart
			endAttachment.Parent = cameraAnchorPart

			layers[layerIndex] = beam
		else
			if not beam:IsA("Beam") or not beam.Enabled then
				continue
			end

			local widthStuds = (verticalViewRatio * layerDistanceStuds) * beamWidthMultiplier

			beam.Width0 = widthStuds
			beam.Width1 = widthStuds
			beam.Transparency = transparencySequence
			beam.LightEmission = rendererState.lightEmission

			startAttachment = beam.Attachment0
			endAttachment = beam.Attachment1
		end

		beam.Enabled = rendererState.isVisible

		startAttachment.Position =
			Vector3.new(horizontalViewRatio * layerDistanceStuds * horizontalPadding, 0, -layerDistanceStuds)
		endAttachment.Position =
			Vector3.new(-(horizontalViewRatio * layerDistanceStuds * horizontalPadding), 0, -layerDistanceStuds)
	end
end

local function renderTrailLayers(renderer)
	local rendererState = renderer.__vars
	local cameraAnchorPart = renderer.cameraAnchorPart
	local layers = renderer.layers
	local fieldOfViewDegrees = renderer.fieldOfViewDegrees
	local viewportSizePixels = renderer.viewportSizePixels

	local tangentHalfFieldOfView = math.tan(math.rad(fieldOfViewDegrees / 2))
	local horizontalViewRatio = (viewportSizePixels.X * tangentHalfFieldOfView) / viewportSizePixels.Y

	local horizontalPadding = volumetricsConfig.trail.horizontalPaddingMultiplier
	local transparencySequence = NumberSequence.new(rendererState.transparency)

	cameraAnchorPart.Size = volumetricsConfig.cameraAnchor.defaultSizeStuds

	updateLayerVisibility(layers, rendererState.depth, rendererState.isVisible)

	for layerIndex = 1, rendererState.depth do
		local layerDistanceStuds = (layerIndex - 1) * rendererState.layerSpacingStuds

		local trail = layers[layerIndex]

		local startAttachment
		local endAttachment

		if trail == nil then
			trail = createVolumetricTrail(transparencySequence, rendererState.lightEmission)

			startAttachment = Instance.new("Attachment")
			endAttachment = Instance.new("Attachment")

			trail.Name = ("Trail%d"):format(layerIndex)
			startAttachment.Name = ("AttachmentA%d"):format(layerIndex)
			endAttachment.Name = ("AttachmentB%d"):format(layerIndex)

			trail.Attachment0 = startAttachment
			trail.Attachment1 = endAttachment

			trail.Parent = cameraAnchorPart
			startAttachment.Parent = cameraAnchorPart
			endAttachment.Parent = cameraAnchorPart

			layers[layerIndex] = trail
		else
			if not trail:IsA("Trail") or not trail.Enabled then
				continue
			end

			trail.Transparency = transparencySequence
			trail.LightEmission = rendererState.lightEmission

			startAttachment = trail.Attachment0
			endAttachment = trail.Attachment1
		end

		trail.Enabled = rendererState.isVisible

		startAttachment.Position =
			Vector3.new(horizontalViewRatio * layerDistanceStuds * horizontalPadding, 0, -layerDistanceStuds)
		endAttachment.Position =
			Vector3.new(-(horizontalViewRatio * layerDistanceStuds * horizontalPadding), 0, -layerDistanceStuds)
	end
end

local function updateTrailLayers(trailLayers: { Instance })
	local trailOffsetStuds = volumetricsConfig.trail.offsetStuds
	local shouldUsePositiveOffset = math.floor(os.clock() * 120) % 2 == 0

	for _, trailLayer in ipairs(trailLayers) do
		if not trailLayer:IsA("Trail") then
			continue
		end

		local startAttachment = trailLayer.Attachment0
		local endAttachment = trailLayer.Attachment1
		local startPosition = startAttachment.Position
		local endPosition = endAttachment.Position

		local startYOffset = if shouldUsePositiveOffset
			then trailOffsetStuds + startPosition.Z
			else -trailOffsetStuds - startPosition.Z

		local endYOffset = if shouldUsePositiveOffset
			then trailOffsetStuds + endPosition.Z
			else -trailOffsetStuds - endPosition.Z

		startAttachment.Position = Vector3.new(startPosition.X, startYOffset, startPosition.Z)
		endAttachment.Position = Vector3.new(endPosition.X, endYOffset, endPosition.Z)
	end
end

local function updateParticleSkyCulling(renderer, cameraCFrame: CFrame)
	local rendererState = renderer.__vars
	local particleEmitter = renderer.particleEmitter
	local particlesConfig = volumetricsConfig.particles
	local cameraLookY = cameraCFrame.LookVector.Y

	if not rendererState.particlesSkyCulled and cameraLookY >= particlesConfig.skyCullLookY then
		rendererState.particlesSkyCulled = true

		if renderer.particleFadeTask ~= nil then
			task.cancel(renderer.particleFadeTask)
			renderer.particleFadeTask = nil
		end

		--// Disabling the emitter does not remove live particles, so clear them explicitly.
		particleEmitter.Enabled = false
		particleEmitter:Clear()
		particleEmitter.Parent = moduleFolder
		particleEmitter.TimeScale = particlesConfig.resetTimeScale

		return
	end

	if rendererState.particlesSkyCulled and cameraLookY <= particlesConfig.skyRestoreLookY then
		rendererState.particlesSkyCulled = false

		--// The fade tween may have left the emitter frozen at TimeScale 0.
		particleEmitter.TimeScale = particlesConfig.resetTimeScale

		renderParticleLayers(renderer)
	end
end

local function destroyLayer(layerInstance: Instance)
	if layerInstance:IsA("BillboardGui") then
		local attachment = layerInstance.Parent

		if attachment then
			attachment:Destroy()
		end

		return
	end

	if layerInstance:IsA("Beam") or layerInstance:IsA("Trail") then
		if layerInstance.Attachment0 then
			layerInstance.Attachment0:Destroy()
		end

		if layerInstance.Attachment1 then
			layerInstance.Attachment1:Destroy()
		end
	end

	layerInstance:Destroy()
end

local function cleanUpRenderLayers(renderer)
	local rendererState = renderer.__vars
	local layers = renderer.layers
	local cameraAnchorPart = renderer.cameraAnchorPart
	local particleEmitter = renderer.particleEmitter

	if rendererState.renderMethod == rendererState.previousRenderMethod then
		return
	end

	for _, layerInstance in ipairs(layers) do
		destroyLayer(layerInstance)
	end

	table.clear(layers)

	for _, childInstance in ipairs(cameraAnchorPart:GetChildren()) do
		if childInstance:IsA("ParticleEmitter") then
			continue
		end

		childInstance:Destroy()
	end

	particleEmitter.Parent = moduleFolder

	particleEmitter.Enabled = false

	particleEmitter:Clear()

	rendererState.particlesSkyCulled = false

	rendererState.previousRenderMethod = rendererState.renderMethod
end

function volumetricsRenderer:preload(rendererInfo: volumetricsRendererInfo)
	local rendererState = self.__vars

	rendererState.depth = rendererInfo.depth
	rendererState.layerSpacingStuds = rendererInfo.layerSpacingStuds
	rendererState.renderMethod = rendererInfo.renderMethod or volumetricsRenderer.renderMethods.Beams
	rendererState.previousRenderMethod = rendererState.renderMethod

	if rendererInfo.transparency ~= nil then
		rendererState.transparency = rendererInfo.transparency
	end

	if rendererInfo.lightEmission ~= nil then
		rendererState.lightEmission = rendererInfo.lightEmission
	end

	if rendererInfo.isVisible ~= nil then
		rendererState.isVisible = rendererInfo.isVisible
	end

	self.camera = rendererInfo.camera
	self.cameraAnchorPart = cameraAnchorPartTemplate:Clone()
	self.particleEmitter = replicatedStorage.SharedAssets.Effects.Particles.Volumetrics.ParticleEmitter:Clone()
	self.layers = {}
	self.cameraConnections = {}
	self.particleFadeTask = nil
	self.lastCameraCFrame = nil
end

function volumetricsRenderer:init()
	self:setCamera(self.camera)
	self:renderVolumetrics()
end

function volumetricsRenderer:setCamera(camera: Camera)
	if self.camera == camera and self.cameraAnchorPart.Parent == camera then
		return
	end

	disconnectCameraConnections(self)

	self.camera = camera

	self.cameraAnchorPart.Parent = camera

	refreshCameraProperties(self)

	connectCameraSignals(self)
end

function volumetricsRenderer:renderVolumetrics()
	local rendererState = self.__vars

	cleanUpRenderLayers(self)

	if rendererState.renderMethod == volumetricsRenderer.renderMethods.Beams then
		self.particleEmitter.Parent = moduleFolder

		renderBeamLayers(self)

		return
	end

	if rendererState.renderMethod == volumetricsRenderer.renderMethods.Billboards then
		self.particleEmitter.Parent = moduleFolder

		renderBillboardLayers(self)

		return
	end

	if rendererState.renderMethod == volumetricsRenderer.renderMethods.Particles then
		renderParticleLayers(self)

		return
	end

	if rendererState.renderMethod == volumetricsRenderer.renderMethods.Trails then
		self.particleEmitter.Parent = moduleFolder

		renderTrailLayers(self)
	end
end

function volumetricsRenderer:updateVolumetrics()
	local rendererState = self.__vars

	if not rendererState.isVisible then
		return
	end

	local cameraCFrame = self.camera:GetRenderCFrame()
	if cameraCFrame ~= self.lastCameraCFrame then
		self.cameraAnchorPart.CFrame = cameraCFrame
		self.lastCameraCFrame = cameraCFrame
	end

	if rendererState.renderMethod == volumetricsRenderer.renderMethods.Particles then
		updateParticleSkyCulling(self, cameraCFrame)
		return
	end

	if rendererState.renderMethod == volumetricsRenderer.renderMethods.Trails then
		updateTrailLayers(self.layers)
	end
end

function volumetricsRenderer.new(rendererInfo: volumetricsRendererInfo)
	local self = setmetatable({}, volumetricsRenderer)

	self.__vars = table.clone(volumetricsRenderer.__vars)

	self:preload(rendererInfo)
	self:init()

	return self
end

function volumetricsRenderer:destroy()
	local particleFadeTask = self.particleFadeTask

	local layers = self.layers or {}

	if particleFadeTask ~= nil then
		task.cancel(particleFadeTask)
		self.particleFadeTask = nil
	end

	for _, layerInstance in ipairs(layers) do
		destroyLayer(layerInstance)
	end

	disconnectCameraConnections(self)

	self.particleEmitter:Clear()
	self.particleEmitter:Destroy()
	self.cameraAnchorPart:Destroy()

	table.clear(layers)
end

return volumetricsRenderer
