local players = game:GetService("Players")
local lighting = game:GetService("Lighting")

local lensFlareController = require(script.LensFlare)
local volumetricsController = require(script.Volumetrics)

local player = players.LocalPlayer
local settingsConfig = player:WaitForChild("Settings", 3)
local videoSettings = settingsConfig.Video
local reducedEffectsSetting = videoSettings:WaitForChild("Reduced Effects", 1)
local castShadowsSetting = videoSettings:WaitForChild("Cast Shadows", 1)
local volumetricLightingSetting = videoSettings:WaitForChild("Volumetric Lighting", 1)

local lightingController = {}
lightingController.__index = lightingController

function lightingController:updateReducedEffects()
	local isReducedEffectsEnabled = reducedEffectsSetting.Value
	self.controllers.lensFlare:setReducedEffects(isReducedEffectsEnabled)

	for _, lightingEffect in ipairs(lighting:GetChildren()) do
		if not lightingEffect:IsA("SunRaysEffect") and not lightingEffect:IsA("BloomEffect") then
			continue
		end

		lightingEffect.Enabled = not isReducedEffectsEnabled
	end
end

function lightingController:updateVolumetricLighting()
	local controllers = self.controllers

	if controllers.volumetrics then
		controllers.volumetrics:destroy()
		controllers.volumetrics = nil
	end

	if volumetricLightingSetting.Value then
		controllers.volumetrics = volumetricsController.new()
	end
end

function lightingController:init()
	local connections = self.connections

	self.controllers.lensFlare = lensFlareController.new()

	connections.reducedEffectsChanged = reducedEffectsSetting:GetPropertyChangedSignal("Value"):Connect(function()
		self:updateReducedEffects()
	end)

	connections.volumetricLightingChanged = volumetricLightingSetting
		:GetPropertyChangedSignal("Value")
		:Connect(function()
			self:updateVolumetricLighting()
		end)

	connections.castShadowsChanged = castShadowsSetting:GetPropertyChangedSignal("Value"):Connect(function()
		lighting.GlobalShadows = castShadowsSetting.Value
	end)

	self:updateReducedEffects()
	self:updateVolumetricLighting()
	lighting.GlobalShadows = castShadowsSetting.Value
end

function lightingController.new()
	local self = setmetatable({}, lightingController)

	self.controllers = {}
	self.connections = {}

	task.defer(self.init, self)

	return self
end

function lightingController:destroy()
	local connections = self.connections
	local controllers = self.controllers

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)

	for _, controller in pairs(controllers) do
		controller:destroy()
	end

	table.clear(controllers)
end

return lightingController
