local collectionService = game:GetService("CollectionService")
local httpService = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local lensFlareConfig = require(script.Parent.Config)

local lensFlareStyles = replicatedStorage.SharedAssets.Effects.Particles.LensFlare
local raycastConfig = lensFlareConfig.raycast

local errorHeader = "LensFlare:"
local ignoreTagName = "IgnoreLensFlare"
local baseResolutionPixels = Vector2.new(1920, 1080)
local spotlightSoftEdgeDegrees = 10
local coneSmoothSpeed = 12
local scalarComparisonEpsilon = 0.0001
local rotationComparisonEpsilonDegrees = 0.05
local minimumParticleLifetimeSeconds = 0.01
local maximumParticleLifetimeSeconds = 0.2

local lightAttributeDefaults = {
	LensFlareStrength = 1,
	LensFlareDistance = 0,
	LensFlareSizeMultiplier = 1,
	IgnoreDisabled = false,
}

local emitterAttributeDefaults = {
	ColorBlend = 0,
	Position = vector.create(1, 1, 1),
	PositionMult = 1,
	Rotates = false,
	SizeFade = NumberSequence.new(1),
	SquashFade = NumberSequence.new(0),
	TransparencyFade = NumberSequence.new(0),
}

local rayOffsets: { { number } } = table.create(raycastConfig.rayCount)

for rayIndex = 1, raycastConfig.rayCount do
	local rayAngleRadians = math.pi * 2 * ((rayIndex - 1) / raycastConfig.rayCount)

	rayOffsets[rayIndex] = {
		math.cos(rayAngleRadians) * raycastConfig.radiusPixels,
		math.sin(rayAngleRadians) * raycastConfig.radiusPixels,
	}
end

--// Method references shared by every emitter to avoid per-frame method lookups.
local particleEmitterPrototype = Instance.new("ParticleEmitter")
local emitParticles = particleEmitterPrototype.Emit
local clearParticles = particleEmitterPrototype.Clear
particleEmitterPrototype:Destroy()

local lensFlareEffect = {}
lensFlareEffect.__index = lensFlareEffect

local function evaluateKeypoints(keypoints: { NumberSequenceKeypoint }, alphaTime: number): number
	if alphaTime <= 0 then
		return keypoints[1].Value
	end

	if alphaTime >= 1 then
		return keypoints[#keypoints].Value
	end

	for keypointIndex = 1, #keypoints - 1 do
		local currentKeypoint = keypoints[keypointIndex]
		local nextKeypoint = keypoints[keypointIndex + 1]

		if alphaTime >= currentKeypoint.Time and alphaTime < nextKeypoint.Time then
			local keypointAlpha = (alphaTime - currentKeypoint.Time) / (nextKeypoint.Time - currentKeypoint.Time)

			return currentKeypoint.Value + (nextKeypoint.Value - currentKeypoint.Value) * keypointAlpha
		end
	end

	return keypoints[#keypoints].Value
end

local function refreshFadeKeypoints(emitterAttributes: { [string]: any })
	emitterAttributes.sizeFadeKeypoints = emitterAttributes.SizeFade.Keypoints
	emitterAttributes.squashFadeKeypoints = emitterAttributes.SquashFade.Keypoints
	emitterAttributes.transparencyFadeKeypoints = emitterAttributes.TransparencyFade.Keypoints
end

local function blendColorSequence(baseSequence: ColorSequence, lightColor: Color3, blendAlpha: number): ColorSequence
	local blendedKeypoints = table.create(#baseSequence.Keypoints)

	for keypointIndex, keypoint in baseSequence.Keypoints do
		blendedKeypoints[keypointIndex] =
			ColorSequenceKeypoint.new(keypoint.Time, keypoint.Value:Lerp(lightColor, blendAlpha))
	end

	return ColorSequence.new(blendedKeypoints)
end

local function getSourcePosition(light: Light): Vector3?
	local lightParent = light.Parent

	if lightParent == nil then
		return nil
	end

	if lightParent:IsA("Attachment") then
		return lightParent.WorldPosition
	end

	if lightParent:IsA("BasePart") then
		return lightParent.Position
	end

	return nil
end

local function getSpotlightForwardVector(spotlight: SpotLight): Vector3
	local lightParent = spotlight.Parent

	if lightParent and lightParent:IsA("Attachment") then
		return lightParent.WorldCFrame.LookVector
	end

	if lightParent and lightParent:IsA("BasePart") then
		local parentCFrame = lightParent.CFrame
		local lightFace = spotlight.Face

		if lightFace == Enum.NormalId.Front then
			return parentCFrame.LookVector
		elseif lightFace == Enum.NormalId.Back then
			return -parentCFrame.LookVector
		elseif lightFace == Enum.NormalId.Right then
			return parentCFrame.RightVector
		elseif lightFace == Enum.NormalId.Left then
			return -parentCFrame.RightVector
		elseif lightFace == Enum.NormalId.Top then
			return parentCFrame.UpVector
		end

		return -parentCFrame.UpVector
	end

	return Vector3.new(0, 0, -1)
end

local function calculateSpotlightConeAlpha(
	spotlight: SpotLight,
	sourcePosition: Vector3,
	cameraPosition: Vector3
): number
	local forwardVector = getSpotlightForwardVector(spotlight)
	local toCameraVector = (cameraPosition - sourcePosition).Unit

	local angleDegrees = math.deg(math.acos(math.clamp(forwardVector:Dot(toCameraVector), -1, 1)))
	local halfConeAngleDegrees = spotlight.Angle * 0.5
	local outerConeAngleDegrees = halfConeAngleDegrees + spotlightSoftEdgeDegrees

	if angleDegrees >= outerConeAngleDegrees then
		return 0
	end

	if angleDegrees <= halfConeAngleDegrees then
		return 1
	end

	local edgeAlpha = (angleDegrees - halfConeAngleDegrees) / (outerConeAngleDegrees - halfConeAngleDegrees)

	return 1 - edgeAlpha * edgeAlpha * (3 - 2 * edgeAlpha)
end

local function isScalarClose(cachedValue: number?, newValue: number, epsilon: number): boolean
	return cachedValue ~= nil and math.abs(cachedValue - newValue) <= epsilon
end

function lensFlareEffect:clearFlare()
	if self.alpha == 0 then
		return
	end

	self.alpha = 0

	for _, flareEmitter in ipairs(self.flareEmitters) do
		clearParticles(flareEmitter)
	end
end

function lensFlareEffect:update(deltaTime: number)
	debug.profilebegin("LensFlareUpdate")

	local camera = self.camera
	local light = self.light
	local sourcePosition = getSourcePosition(light)

	if sourcePosition == nil then
		self:clearFlare()
		debug.profileend()
		return
	end

	local lightAttributes = self.attributeCache[light]
	local flareStrength: number = lightAttributes.LensFlareStrength

	if flareStrength <= 0 then
		self:clearFlare()
		debug.profileend()
		return
	end

	local cameraCFrame = camera.CFrame
	local cameraPosition = cameraCFrame.Position
	local sourceDirection = sourcePosition - cameraPosition
	local sourceDistanceStuds = vector.magnitude(sourceDirection)

	local offScreenAlpha = math.clamp(
		vector.angle(cameraCFrame.LookVector, sourceDirection) / math.rad(camera.DiagonalFieldOfView) * 2,
		0,
		1
	)

	local flareDistanceSetting: number = lightAttributes.LensFlareDistance

	if flareDistanceSetting > 0 then
		offScreenAlpha += sourceDistanceStuds / flareDistanceSetting
	end

	if offScreenAlpha >= 1 then
		self:clearFlare()
		debug.profileend()
		return
	end

	local spotlight: SpotLight? = if light:IsA("SpotLight") then light :: SpotLight else nil
	local coneAlpha = 1

	if spotlight ~= nil then
		coneAlpha = calculateSpotlightConeAlpha(spotlight, sourcePosition, cameraPosition)
	end

	local smoothedConeAlpha = self.smoothedConeAlpha or coneAlpha

	smoothedConeAlpha += (coneAlpha - smoothedConeAlpha) * math.clamp(deltaTime * coneSmoothSpeed, 0, 1)
	self.smoothedConeAlpha = smoothedConeAlpha
	coneAlpha = smoothedConeAlpha

	local visualAlpha = if spotlight ~= nil then 1 - coneAlpha * (1 - offScreenAlpha) else offScreenAlpha
	local screenPosition = camera:WorldToViewportPoint(sourcePosition)
	local viewportRayOrigin = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y, 1).Origin
	local cameraSpaceOffset = cameraCFrame:ToObjectSpace(CFrame.new(viewportRayOrigin)).Position

	local raycastParameters = self.raycastParams
	local resolutionScale = (camera.ViewportSize / baseResolutionPixels).Magnitude
	local blockedRayCount = 0

	debug.profilebegin("LensFlareRaycasts")

	for _, rayOffset in ipairs(rayOffsets) do
		local viewportRay = camera:ViewportPointToRay(
			screenPosition.X + rayOffset[1] * resolutionScale,
			screenPosition.Y + rayOffset[2] * resolutionScale,
			1
		)
		local raycastResult =
			workspace:Raycast(viewportRay.Origin, viewportRay.Direction * sourceDistanceStuds, raycastParameters)

		if raycastResult == nil then
			continue
		end

		local hitPart = raycastResult.Instance

		if
			hitPart:IsA("BasePart")
			and (
				hitPart.Transparency > raycastConfig.transparencyThreshold
				or hitPart.LocalTransparencyModifier > raycastConfig.transparencyThreshold
			)
		then
			raycastParameters:AddToFilter(hitPart)
		else
			blockedRayCount += 1
		end
	end

	debug.profileend()

	local blockedAlpha = blockedRayCount / raycastConfig.rayCount
	local newAlpha = if light.Enabled then flareStrength * (1 - offScreenAlpha) * (1 - blockedAlpha) * coneAlpha else 0

	if newAlpha <= 0 then
		self:clearFlare()
		debug.profileend()
		return
	end

	local flareEmitters = self.flareEmitters
	local propertyCache = self.propertyCache
	local lifetimeSeconds =
		math.clamp(math.round(deltaTime * 600) / 200, minimumParticleLifetimeSeconds, maximumParticleLifetimeSeconds)

	--// Unchanged flares only need a re-emit, not a full property recompute.
	if newAlpha == self.alpha and not self.forceRecompute then
		for _, flareEmitter in ipairs(flareEmitters) do
			local emitterProperties = propertyCache[flareEmitter]

			clearParticles(flareEmitter)

			if emitterProperties.lifetimeSeconds ~= lifetimeSeconds then
				flareEmitter.Lifetime = NumberRange.new(lifetimeSeconds)
				emitterProperties.lifetimeSeconds = lifetimeSeconds
			end

			emitParticles(flareEmitter, 1)
		end

		debug.profileend()
		return
	end

	local attachments = self.attachments
	local attributeCache = self.attributeCache
	local lightColor = light.Color
	local emitterTransparencyModifier = 1 - flareStrength
	local zOffset = math.min(-cameraSpaceOffset.Z * 0.8, 0)
	local sizeMultiplier: number = lightAttributes.LensFlareSizeMultiplier

	for emitterIndex, flareEmitter in ipairs(flareEmitters) do
		local attachment = attachments[emitterIndex]
		local emitterAttributes = attributeCache[flareEmitter]
		local emitterProperties = propertyCache[flareEmitter]

		clearParticles(flareEmitter)

		local positionScale: vector = emitterAttributes.Position
		local positionMultiplier: number = emitterAttributes.PositionMult

		attachment.Position = vector.create(
			cameraSpaceOffset.X * positionScale.x * positionMultiplier,
			cameraSpaceOffset.Y * positionScale.y * positionMultiplier,
			cameraSpaceOffset.Z
		)

		local sizeValue = evaluateKeypoints(emitterAttributes.sizeFadeKeypoints, visualAlpha) * sizeMultiplier

		if not isScalarClose(emitterProperties.sizeValue, sizeValue, scalarComparisonEpsilon) then
			flareEmitter.Size = NumberSequence.new(sizeValue)
			emitterProperties.sizeValue = sizeValue
		end

		local squashValue = evaluateKeypoints(emitterAttributes.squashFadeKeypoints, offScreenAlpha)

		if not isScalarClose(emitterProperties.squashValue, squashValue, scalarComparisonEpsilon) then
			flareEmitter.Squash = NumberSequence.new(squashValue)
			emitterProperties.squashValue = squashValue
		end

		local transparencyValue =
			math.lerp(evaluateKeypoints(emitterAttributes.transparencyFadeKeypoints, visualAlpha), 1, blockedAlpha)

		if not isScalarClose(emitterProperties.transparencyValue, transparencyValue, scalarComparisonEpsilon) then
			flareEmitter.Transparency = NumberSequence.new(transparencyValue)
			emitterProperties.transparencyValue = transparencyValue
		end

		if emitterProperties.transparencyModifier ~= emitterTransparencyModifier then
			flareEmitter.LocalTransparencyModifier = emitterTransparencyModifier
			emitterProperties.transparencyModifier = emitterTransparencyModifier
		end

		local colorBlendAlpha = math.clamp(emitterAttributes.ColorBlend, 0, 1)

		if
			emitterProperties.blendedLightColor ~= lightColor
			or emitterProperties.blendedColorAlpha ~= colorBlendAlpha
		then
			flareEmitter.Color = blendColorSequence(emitterProperties.baseColorSequence, lightColor, colorBlendAlpha)
			emitterProperties.blendedLightColor = lightColor
			emitterProperties.blendedColorAlpha = colorBlendAlpha
		end

		if emitterAttributes.Rotates then
			local rotationDegrees = math.deg(math.atan2(cameraSpaceOffset.Y, cameraSpaceOffset.X))

			if
				not isScalarClose(emitterProperties.rotationDegrees, rotationDegrees, rotationComparisonEpsilonDegrees)
			then
				flareEmitter.Rotation = NumberRange.new(rotationDegrees)
				emitterProperties.rotationDegrees = rotationDegrees
			end
		end

		if not isScalarClose(emitterProperties.zOffset, zOffset, scalarComparisonEpsilon) then
			flareEmitter.ZOffset = zOffset
			emitterProperties.zOffset = zOffset
		end

		if emitterProperties.lifetimeSeconds ~= lifetimeSeconds then
			flareEmitter.Lifetime = NumberRange.new(lifetimeSeconds)
			emitterProperties.lifetimeSeconds = lifetimeSeconds
		end

		emitParticles(flareEmitter, 1)
	end

	self.alpha = newAlpha
	self.forceRecompute = false

	debug.profileend()
end

function lensFlareEffect:setGloballyDisabled(isGloballyDisabled: boolean)
	self.globallyDisabled = isGloballyDisabled
end

function lensFlareEffect:onRenderStep(deltaTime: number)
	local lightAttributes = self.attributeCache[self.light]
	local ignoresDisabled = lightAttributes ~= nil and lightAttributes.IgnoreDisabled

	if self.isEnabled and not (self.globallyDisabled and not ignoresDisabled) then
		self:update(deltaTime)
		return
	end

	self:clearFlare()
end

function lensFlareEffect:preload(styleFolder: Instance)
	local camera = self.camera
	local light = self.light
	local flareStyle = self.flareStyle
	local connections = self.connections
	local attributeCache = self.attributeCache
	local propertyCache = self.propertyCache

	local lightAttributes = {}

	for attributeName, defaultValue in lightAttributeDefaults do
		lightAttributes[attributeName] = light:GetAttribute(attributeName) or defaultValue

		table.insert(
			connections,
			light:GetAttributeChangedSignal(attributeName):Connect(function()
				lightAttributes[attributeName] = light:GetAttribute(attributeName) or defaultValue
				self.forceRecompute = true
			end)
		)
	end

	attributeCache[light] = lightAttributes

	for _, flareAsset in ipairs(styleFolder:GetChildren()) do
		if not flareAsset:IsA("ParticleEmitter") then
			continue
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = `LensFlare_{flareStyle}_{flareAsset.Name}`

		local flareEmitter = Instance.fromExisting(flareAsset)
		flareEmitter.Enabled = false
		flareEmitter.ZOffset = 0
		flareEmitter.Parent = attachment
		attachment.Parent = camera

		table.insert(self.attachments, attachment)
		table.insert(self.flareEmitters, flareEmitter)

		local emitterAttributes = {}

		for attributeName, defaultValue in emitterAttributeDefaults do
			emitterAttributes[attributeName] = flareEmitter:GetAttribute(attributeName) or defaultValue

			table.insert(
				connections,
				flareEmitter:GetAttributeChangedSignal(attributeName):Connect(function()
					emitterAttributes[attributeName] = flareEmitter:GetAttribute(attributeName) or defaultValue
					refreshFadeKeypoints(emitterAttributes)
					self.forceRecompute = true
				end)
			)
		end

		refreshFadeKeypoints(emitterAttributes)
		attributeCache[flareEmitter] = emitterAttributes
		propertyCache[flareEmitter] = { baseColorSequence = flareEmitter.Color }
	end

	local ignoredInstances: { Instance } = {}
	local sourceInstance = light.Parent

	if sourceInstance ~= nil then
		table.insert(ignoredInstances, sourceInstance)
	end

	for _, taggedInstance in ipairs(collectionService:GetTagged(ignoreTagName)) do
		table.insert(ignoredInstances, taggedInstance)
	end

	local raycastParameters = RaycastParams.new()
	raycastParameters.FilterType = Enum.RaycastFilterType.Exclude
	raycastParameters.FilterDescendantsInstances = ignoredInstances
	raycastParameters.IgnoreWater = true

	self.raycastParams = raycastParameters
end

function lensFlareEffect:init()
	table.insert(
		self.connections,
		collectionService:GetInstanceAddedSignal(ignoreTagName):Connect(function(taggedInstance)
			self.raycastParams:AddToFilter(taggedInstance)
		end)
	)

	runService:BindToRenderStep(self.renderStepName, Enum.RenderPriority.Camera.Value + 10, function(deltaTime)
		self:onRenderStep(deltaTime)
	end)
end

function lensFlareEffect.new(camera: Camera, flareStyle: string, light: Light)
	assert(light:IsA("Light"), `{errorHeader} flare source must be a Light`)
	assert(getSourcePosition(light) ~= nil, `{errorHeader} light must be parented to a BasePart or Attachment`)

	local styleFolder = lensFlareStyles:FindFirstChild(flareStyle)
	assert(styleFolder ~= nil, `{errorHeader} no lens flare style named {flareStyle}`)

	local self = setmetatable({}, lensFlareEffect)

	self.id = httpService:GenerateGUID(false)
	self.renderStepName = `LensFlare_{self.id}`
	self.flareStyle = flareStyle
	self.isEnabled = true
	self.globallyDisabled = false
	self.alpha = 0
	self.forceRecompute = false
	self.camera = camera
	self.light = light
	self.attachments = {}
	self.flareEmitters = {}
	self.attributeCache = {}
	self.propertyCache = {}
	self.connections = {}

	self:preload(styleFolder)
	self:init()

	return self
end

function lensFlareEffect:destroy()
	runService:UnbindFromRenderStep(self.renderStepName)

	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	for _, flareEmitter in ipairs(self.flareEmitters) do
		flareEmitter:Destroy()
	end

	for _, attachment in ipairs(self.attachments) do
		attachment:Destroy()
	end

	table.clear(self)
	setmetatable(self, nil)
end

return lensFlareEffect
