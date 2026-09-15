local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local player = players.LocalPlayer
local playerGui = player.PlayerGui

local interfaceGui = playerGui:WaitForChild("Interface", 3)
local notificationHolder = interfaceGui.NotificationHolder

local sharedAssets = replicatedStorage.SharedAssets
local effects = sharedAssets.Effects
local sounds = effects.Sounds
local boomSounds = sounds.Booms:GetChildren()

local networking = require(replicatedStorage.Communication.Networking)
local guiUtilities = require(replicatedFirst.ClientUtilities.GuiUtils)

local notificationController = {}
notificationController.presets = {
	isDay = {
		State = "DAYTIME",
		Time = "7:00 A.M.",
		Footer = "Prepare for the night.",
	},

	isNight = {
		State = "NIGHTTIME",
		Time = "8:30 P.M.",
		Footer = "Survive the night.",
	},
}

function notificationController.onNotificationEvent(isNightTime: boolean)
	guiUtilities.changeGuiState({
		frame = notificationHolder,
		state = false,
	})

	notificationHolder.Visible = true

	local toCycleThru = isNightTime and notificationController.presets.isNight or notificationController.presets.isDay

	for labelName, toReplace in toCycleThru do
		local trueLabel = notificationHolder:FindFirstChild(labelName)

		if trueLabel and trueLabel:IsA("TextLabel") then
			trueLabel.Text = toReplace
		end
	end

	guiUtilities.changeGuiState({
		frame = notificationHolder,
		tweenInfo = TweenInfo.new(1),
		state = true,
	})

	local randomBoomSound = boomSounds[math.random(1, #boomSounds)]
	randomBoomSound:Play()

	task.delay(7.5, function()
		local fadeOutTween = guiUtilities.changeGuiState({
			frame = notificationHolder,
			tweenInfo = TweenInfo.new(5),
			state = false,
		})

		fadeOutTween.Completed:Once(function()
			notificationHolder.Visible = false
		end)
	end)
end

function notificationController.init()
	networking.events.sendNotification.OnClientEvent:Connect(function(isNightTime: boolean)
		notificationController.onNotificationEvent(isNightTime)
	end)
end

return notificationController
