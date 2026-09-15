local collectionService = game:GetService("CollectionService")
local lighting = game:GetService("Lighting")
local replicatedFirst = game:GetService("ReplicatedFirst")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local cameraUtilities = require(replicatedFirst.ClientUtilities.CameraUtils)
local lensFlareConfig = require(script.Config)
local lensFlareEffect = require(script.Effect)

local sunConfig = lensFlareConfig.sun

local sunPartRenderStepName = "LensFlareSunPart"
local exposureRenderStepName = "LensFlareExposure"

local lensFlareController = {}
lensFlareController.__index = lensFlareController
lensFlareController.__vars = {
	exposureAlpha = 0,
	exposureVelocity = 0,
	appliedExposureOffset = 0,
}

local function getFlareStyle(light: Light)
	return light:GetAttribute("LensFlareStyle") or "Default"
end

function lensFlareController:setReducedEffects(isReducedEffectsEnabled: boolean)
	self.isReducedEffectsEnabled = isReducedEffectsEnabled

	if self.sunFlare then
		self.sunFlare:setGloballyDisabled(isReducedEffectsEnabled)
	end

	for _, flare in pairs(self.flaresByLight) do
		flare:setGloballyDisabled(isReducedEffectsEnabled)
	end
end

function lensFlareController:createSunFlare()
	local sunPart = Instance.new("Part")
	sunPart.Name = "SunFlarePart"
	sunPart.Anchored = true
	sunPart.CanCollide = false
	sunPart.CanQuery = false
	sunPart.CanTouch = false
	sunPart.CastShadow = false
	sunPart.Transparency = sunConfig.partTransparency
	sunPart.Size = Vector3.one
	sunPart.Color = lighting.ColorShift_Top
	sunPart.Parent = workspace

	local sunLight = Instance.new("PointLight")
	sunLight.Name = "SunFlareLight"
	sunLight.Enabled = true
	sunLight:SetAttribute("LensFlareStrength", sunConfig.flareStrength)
	sunLight:SetAttribute("LensFlareStyle", "Default")
	sunLight.Parent = sunPart

	self.sunPart = sunPart
	self.sunLight = sunLight
	self.sunFlare = lensFlareEffect.new(self.camera, "Default", sunLight)
	self.sunFlare:setGloballyDisabled(self.isReducedEffectsEnabled)
end

function lensFlareController:createTaggedFlare(taggedLight: Instance)
	local flaresByLight = self.flaresByLight

	if not taggedLight:IsA("Light") or flaresByLight[taggedLight] ~= nil then
		return
	end

	local flare = lensFlareEffect.new(self.camera, getFlareStyle(taggedLight), taggedLight)
	flare:setGloballyDisabled(self.isReducedEffectsEnabled)
	flaresByLight[taggedLight] = flare
end

function lensFlareController:createFlares()
	self:createSunFlare()
	self:updateSunStrength()

	for _, taggedLight in ipairs(collectionService:GetTagged("LensFlare")) do
		self:createTaggedFlare(taggedLight)
	end
end

function lensFlareController:destroyFlares()
	local flaresByLight = self.flaresByLight

	if self.sunFlare then
		self.sunFlare:destroy()
		self.sunFlare = nil
	end

	if self.sunPart then
		self.sunPart:Destroy()
		self.sunPart = nil
		self.sunLight = nil
	end

	for taggedLight, flare in pairs(flaresByLight) do
		flare:destroy()
		flaresByLight[taggedLight] = nil
	end
end

function lensFlareController:updateSunStrength()
	local sunHeightAlpha = math.clamp(lighting:GetSunDirection().Y * 90 / sunConfig.angleThresholdDegrees, 0, 1)
	local brightnessAlpha = math.clamp(lighting.Brightness / sunConfig.brightnessThreshold, 0, 1)
	local sunStrengthAlpha = sunHeightAlpha * brightnessAlpha

	self.sunFlare.isEnabled = sunStrengthAlpha > 0
	self.sunLight:SetAttribute("LensFlareStrength", sunStrengthAlpha * sunConfig.flareStrength)
end

function lensFlareController:updateSunPartPosition()
	local sunPart = self.sunPart

	if sunPart == nil then
		return
	end

	sunPart.Position = self.camera.CFrame.Position + lighting:GetSunDirection() * sunConfig.distanceStuds
end

function lensFlareController:updateExposure(deltaTime: number)
	local stateValues = self.__vars

	local exposureAlpha, exposureVelocity = tweenService:SmoothDamp(
		stateValues.exposureAlpha,
		self.sunFlare.alpha,
		stateValues.exposureVelocity,
		sunConfig.exposureSmoothTimeSeconds,
		nil,
		deltaTime
	)

	stateValues.exposureAlpha = exposureAlpha
	stateValues.exposureVelocity = exposureVelocity

	local targetExposureOffset = exposureAlpha * sunConfig.exposureAdjustment * sunConfig.exposureMultiplier
	local appliedExposureOffset = stateValues.appliedExposureOffset

	if targetExposureOffset == appliedExposureOffset then
		return
	end

	lighting.ExposureCompensation += targetExposureOffset - appliedExposureOffset
	stateValues.appliedExposureOffset = targetExposureOffset
end

function lensFlareController:onCameraChanged()
	local currentCamera = workspace.CurrentCamera

	if currentCamera == nil or currentCamera == self.camera then
		return
	end

	--// Flare emitters live under the camera, so they must be rebuilt on the new one.
	self.camera = currentCamera
	self:destroyFlares()
	self:createFlares()
end

function lensFlareController:preload()
	self.camera = cameraUtilities.getCurrentCamera()
	self:createFlares()
end

function lensFlareController:init()
	if self.isDestroyed then
		return
	end

	local connections = self.connections

	self:preload()

	connections.colorShiftChanged = lighting:GetPropertyChangedSignal("ColorShift_Top"):Connect(function()
		local sunPart = self.sunPart

		if sunPart then
			sunPart.Color = lighting.ColorShift_Top
		end
	end)

	connections.brightnessChanged = lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
		self:updateSunStrength()
	end)

	connections.clockTimeChanged = lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
		self:updateSunStrength()
	end)

	connections.flareAdded = collectionService:GetInstanceAddedSignal("LensFlare"):Connect(function(taggedLight)
		self:createTaggedFlare(taggedLight)
	end)

	connections.flareRemoved = collectionService:GetInstanceRemovedSignal("LensFlare"):Connect(function(taggedLight)
		local flare = self.flaresByLight[taggedLight]

		if flare then
			flare:destroy()
			self.flaresByLight[taggedLight] = nil
		end
	end)

	connections.currentCameraChanged = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:onCameraChanged()
	end)

	runService:BindToRenderStep(sunPartRenderStepName, Enum.RenderPriority.Camera.Value + 9, function()
		self:updateSunPartPosition()
	end)

	runService:BindToRenderStep(exposureRenderStepName, Enum.RenderPriority.Camera.Value + 11, function(deltaTime)
		self:updateExposure(deltaTime)
	end)

	self.hasBoundRenderSteps = true
end

function lensFlareController.new()
	local self = setmetatable({}, lensFlareController)

	self.connections = {}
	self.flaresByLight = {}
	self.__vars = table.clone(lensFlareController.__vars)
	self.isReducedEffectsEnabled = false
	self.hasBoundRenderSteps = false
	self.isDestroyed = false

	task.defer(self.init, self)

	return self
end

function lensFlareController:destroy()
	local connections = self.connections
	local stateValues = self.__vars

	self.isDestroyed = true

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)

	if self.hasBoundRenderSteps then
		runService:UnbindFromRenderStep(sunPartRenderStepName)
		runService:UnbindFromRenderStep(exposureRenderStepName)
		self.hasBoundRenderSteps = false
	end

	lighting.ExposureCompensation -= stateValues.appliedExposureOffset
	stateValues.appliedExposureOffset = 0

	self:destroyFlares()
end

return lensFlareController
