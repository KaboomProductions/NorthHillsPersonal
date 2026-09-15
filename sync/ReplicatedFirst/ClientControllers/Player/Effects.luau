local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local player = players.LocalPlayer
local settingsConfig = player:WaitForChild("Settings", 3)
local dayThemesSetting = settingsConfig.Audio:WaitForChild("Day Themes", 1)

local weatherClasses = replicatedStorage.SharedClasses.Weather
local soundGroups = replicatedStorage.SharedAssets.SoundGroups

local windShakeController = require(weatherClasses.WindShake)
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local bootstrapUtilities = require(replicatedStorage.SharedUtilities.Bootstrap)

local effectsController = {}
effectsController.__index = effectsController

function effectsController.onDayThemesChanged()
	local newValue = dayThemesSetting.Value
	local trueProperty = newValue and 0 or -100

	audioUtilities.applyEqualizerToSoundGroups({
		equalizerId = "mute",
		tweenInfo = TweenInfo.new(0.5),

		groups = {
			soundGroups.MusicDay,
		},

		properties = {
			HighGain = trueProperty,
			LowGain = trueProperty,
			MidGain = trueProperty,
		},
	})
end

function effectsController.new()
	local self = setmetatable({}, effectsController)

	self.connections = {}
	self.snowController = require(weatherClasses.Snow).new()
	self.rainController = require(weatherClasses.Rain).new()
	self.winterValue = replicatedStorage.Values.Winter

	windShakeController:Init({ MatchWorkspaceWind = false })
	self:updateWeatherEffects()

	self.controllers = bootstrapUtilities.startModules(script)

	self.connections.onDayThemesChanged =
		dayThemesSetting:GetPropertyChangedSignal("Value"):Connect(effectsController.onDayThemesChanged)
	effectsController.onDayThemesChanged()

	self.connections.winterChanged = self.winterValue:GetPropertyChangedSignal("Value"):Connect(function()
		self:updateWeatherEffects()
	end)

	return self
end

function effectsController:updateWeatherEffects()
	local isWinterEnabled = self.winterValue.Value == true

	self.snowController:toggle(isWinterEnabled)
	self.rainController:toggle(not isWinterEnabled)
end

function effectsController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	for _, controller in pairs(self.controllers) do
		if type(controller) == "table" and type(controller.destroy) == "function" then
			controller:destroy()
		end
	end

	table.clear(self.connections)
	self.snowController:destroy()
	self.rainController:destroy()
end

return effectsController
