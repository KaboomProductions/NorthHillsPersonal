local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")
local runService = game:GetService("RunService")

local cameraUtilities = require(replicatedFirst.ClientUtilities.CameraUtils)
local volumetricsConfig = require(script.Config)
local volumetricsRenderer = require(script.Renderer)

local volumetricsController = {}
volumetricsController.__index = volumetricsController
volumetricsController.__vars = {
	defaultLightEmission = volumetricsConfig.defaults.lightEmission,
	defaultRenderMethodName = volumetricsConfig.defaults.renderMethodName,
	defaultSpacingStuds = volumetricsConfig.defaults.spacingStuds,
	defaultTransparency = volumetricsConfig.defaults.transparency,
	defaultVisible = volumetricsConfig.defaults.isVisible,
	defaultVolumeLayers = volumetricsConfig.defaults.volumeLayers,
	isConfigurationDirty = true,
	shouldRefreshCamera = false,
}

type renderConfiguration = {
	volumeLayers: number,
	spacingStuds: number,
	isVisible: boolean,
	transparency: number,
	lightEmission: number,
	renderMethod: number,
}

local function getOptionalChild(parentInstance: Instance?, childName: string): Instance?
	if parentInstance == nil then
		return nil
	end

	return parentInstance:FindFirstChild(childName)
end

local function getNumberValue(numberValue: NumberValue?, fallbackNumber: number): number
	if numberValue == nil then
		return fallbackNumber
	end

	return numberValue.Value
end

local function getBooleanValue(booleanValue: BoolValue?, fallbackBoolean: boolean): boolean
	if booleanValue == nil then
		return fallbackBoolean
	end

	return booleanValue.Value
end

local function getStringValue(stringValue: StringValue?, fallbackString: string): string
	if stringValue == nil then
		return fallbackString
	end

	return stringValue.Value
end

function volumetricsController:preload()
	local valuesFolder = replicatedStorage:FindFirstChild("Values")
	local volumetricsValues = getOptionalChild(valuesFolder, "Volumetrics") :: Folder?

	self.camera = cameraUtilities.getCurrentCamera()
	self.volumetricsValues = volumetricsValues
	self.layersValue = getOptionalChild(volumetricsValues, "Layers") :: NumberValue?
	self.spacingValue = getOptionalChild(volumetricsValues, "Spacing") :: NumberValue?
	self.visibleValue = getOptionalChild(volumetricsValues, "Visible") :: BoolValue?
	self.transparencyValue = getOptionalChild(volumetricsValues, "Transparency") :: NumberValue?
	self.lightEmissionValue = getOptionalChild(volumetricsValues, "LightEmission") :: NumberValue?
	self.renderMethodValue = getOptionalChild(volumetricsValues, "RenderMethod") :: StringValue?
end

function volumetricsController:getConfigurationSnapshot(): renderConfiguration
	local stateValues = self.__vars
	local requestedVolumeLayers = getNumberValue(self.layersValue, stateValues.defaultVolumeLayers)

	return {
		volumeLayers = math.clamp(
			math.round(requestedVolumeLayers),
			0,
			volumetricsConfig.performance.maximumVolumeLayers
		),
		spacingStuds = getNumberValue(self.spacingValue, stateValues.defaultSpacingStuds),
		isVisible = getBooleanValue(self.visibleValue, stateValues.defaultVisible),
		transparency = getNumberValue(self.transparencyValue, stateValues.defaultTransparency),
		lightEmission = getNumberValue(self.lightEmissionValue, stateValues.defaultLightEmission),
		renderMethod = self:getRenderMethod(),
	}
end

function volumetricsController:getRenderMethod()
	local stateValues = self.__vars
	local renderMethodValue = self.renderMethodValue
	local renderMethodName = getStringValue(renderMethodValue, stateValues.defaultRenderMethodName)

	return volumetricsRenderer.renderMethods[renderMethodName]
		or volumetricsRenderer.renderMethods[stateValues.defaultRenderMethodName]
end

function volumetricsController:createRenderer()
	local configurationSnapshot = self:getConfigurationSnapshot()

	self.renderer = volumetricsRenderer.new({
		camera = self.camera,
		depth = configurationSnapshot.volumeLayers,
		layerSpacingStuds = configurationSnapshot.spacingStuds,
		renderMethod = configurationSnapshot.renderMethod,
		transparency = configurationSnapshot.transparency,
		lightEmission = configurationSnapshot.lightEmission,
		isVisible = configurationSnapshot.isVisible,
	})

	self.__vars.isConfigurationDirty = false
end

function volumetricsController:applyRendererConfiguration()
	local renderer = self.renderer
	local stateValues = self.__vars
	local configurationSnapshot = self:getConfigurationSnapshot()

	if renderer == nil then
		return
	end

	renderer.__vars.depth = configurationSnapshot.volumeLayers
	renderer.__vars.layerSpacingStuds = configurationSnapshot.spacingStuds
	renderer.__vars.isVisible = configurationSnapshot.isVisible
	renderer.__vars.transparency = configurationSnapshot.transparency
	renderer.__vars.lightEmission = configurationSnapshot.lightEmission
	renderer.__vars.renderMethod = configurationSnapshot.renderMethod
	renderer:renderVolumetrics()

	stateValues.isConfigurationDirty = false
end

function volumetricsController:markConfigurationDirty()
	self.__vars.isConfigurationDirty = true
end

function volumetricsController:refreshCamera()
	local renderer = self.renderer
	local stateValues = self.__vars
	local currentCamera = cameraUtilities.getCurrentCamera()

	self.camera = currentCamera
	stateValues.shouldRefreshCamera = false

	if renderer == nil then
		return
	end

	renderer:setCamera(currentCamera)
	self:markConfigurationDirty()
end

function volumetricsController:connectValueChangedSignal(
	connections: { [string]: RBXScriptConnection },
	connectionName: string,
	valueObject: Instance?
)
	if valueObject == nil or not valueObject:IsA("ValueBase") then
		return
	end

	connections[connectionName] = valueObject.Changed:Connect(function()
		self:markConfigurationDirty()
	end)
end

function volumetricsController:init()
	local connections = self.connections

	self:preload()
	self:createRenderer()

	connections.currentCameraChanged = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self.__vars.shouldRefreshCamera = true
	end)

	self:connectValueChangedSignal(connections, "layersChanged", self.layersValue)
	self:connectValueChangedSignal(connections, "spacingChanged", self.spacingValue)
	self:connectValueChangedSignal(connections, "visibleChanged", self.visibleValue)
	self:connectValueChangedSignal(connections, "transparencyChanged", self.transparencyValue)
	self:connectValueChangedSignal(connections, "lightEmissionChanged", self.lightEmissionValue)
	self:connectValueChangedSignal(connections, "renderMethodChanged", self.renderMethodValue)

	--// Exception: uses RenderStepped:Connect instead of BindToRenderStep because
	--// volumetric CFrame updates must run after the camera pipeline resolves.
	connections.renderStepped = runService.RenderStepped:Connect(function()
		local stateValues = self.__vars
		local renderer = self.renderer

		if stateValues.shouldRefreshCamera then
			self:refreshCamera()
		end

		if stateValues.isConfigurationDirty then
			self:applyRendererConfiguration()
		end

		if renderer == nil then
			return
		end

		renderer:updateVolumetrics()
	end)
end

function volumetricsController.new()
	local self = setmetatable({}, volumetricsController)

	self.connections = {}
	self.__vars = table.clone(volumetricsController.__vars)

	task.defer(self.init, self)

	return self
end

function volumetricsController:destroy()
	local connections = self.connections
	local renderer = self.renderer

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)

	if renderer ~= nil then
		renderer:destroy()
		self.renderer = nil
	end
end

return volumetricsController
