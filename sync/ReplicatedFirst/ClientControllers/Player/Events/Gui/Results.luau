local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

local player = players.LocalPlayer
local playerGui = player.PlayerGui

local interfaceGui = playerGui:WaitForChild("Interface", 3)
local resultsHolder = interfaceGui.ResultsHolder

local infoFrame = resultsHolder.InfoFrame
local totalLabel = infoFrame.Total
local stateLabel = infoFrame.State
local textGlowImage = infoFrame.TextGlow
local tasksFrame = infoFrame.Tasks
local container = tasksFrame.Container

local sharedAssets = replicatedStorage.SharedAssets
local dictionaries = sharedAssets.Dictionaries
local effects = sharedAssets.Effects
local soundGroups = sharedAssets.SoundGroups
local sounds = effects.Sounds
local interface = effects.Interface

local resultSounds = sounds.Results
local survivedSounds = resultSounds.Survived:GetChildren()
local failedSounds = resultSounds.Failed:GetChildren()

local resultDefinitions = require(dictionaries.ResultDefinitions)
local resultLabelPreset = interface.Result

local networking = require(replicatedStorage.Communication.Networking)
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)
local guiUtilities = require(replicatedFirst.ClientUtilities.GuiUtils)

local resultsController = {}
resultsController.activeResultLabels = {}
resultsController.lastIndex = 1
resultsController.closeConnection = nil
resultsController.__vars = {
	statePresets = {
		survived = {
			text = "YOU SURVIVED THE NIGHT",
			color = Color3.fromRGB(191, 255, 207),
		},

		nonSurvived = {
			text = "YOU FAILED TO SURVIVED THE NIGHT",
			color = Color3.fromRGB(215, 142, 142),
		},
	},

	equalizerPresets = {
		inactive = {
			HighGain = 0,
			LowGain = 0,
			MidGain = 0,
		},

		active = {
			HighGain = -80,
			LowGain = -15,
			MidGain = -25,
		},
	},
}

function resultsController.onResultsEvent(resultInfo)
	resultsController.lastIndex = 1

	if resultsController.closeConnection then
		resultsController.closeConnection:Disconnect()
		resultsController.closeConnection = nil
	end

	resultsController.latestSounds = resultInfo.survived and survivedSounds or failedSounds
	resultsController.latestPreset = resultInfo.survived and resultsController.__vars.statePresets.survived
		or resultsController.__vars.statePresets.nonSurvived

	guiUtilities.changeGuiState({
		frame = resultsHolder,
		state = false,
	})

	local randomSound = resultsController.latestSounds[math.random(1, #resultsController.latestSounds)]
	randomSound:Play()

	audioUtilities.applyEqualizerToSoundGroups({
		tweenInfo = TweenInfo.new(0.5),
		equalizerId = "results",
		groups = {
			soundGroups.Music,
			soundGroups.MusicDay,
		},
		properties = resultsController.__vars.equalizerPresets.active,
	})

	for index, label in resultsController.activeResultLabels do
		label:Destroy()
		resultsController.activeResultLabels[index] = nil
	end

	for _, group in resultInfo.breakdown do
		local rewardId = group.id
		local definition = resultDefinitions[rewardId]

		if definition then
			local stringForFormat = definition.label
			if definition.mode == "scaled" and group.amountSum then
				stringForFormat = string.format(stringForFormat, math.round(group.amountSum))
			end

			local newLabel = resultLabelPreset:Clone()
			local textSizeConstraint = newLabel:FindFirstChildOfClass("UITextSizeConstraint")
			newLabel.Name = definition.order or tostring(resultsController.lastIndex)

			if definition.noGain then
				newLabel.Text = stringForFormat
			else
				newLabel.Text = string.format(
					resultDefinitions.mainFormat,
					mathUtilities.convertToUSD(group.totalPoints),
					stringForFormat
				)
			end

			if definition.resultColor then
				newLabel.TextColor3 = definition.resultColor
			end

			if definition.resultSize then
				if textSizeConstraint then
					textSizeConstraint:Destroy()
				end

				newLabel.Size = definition.resultSize
			end

			newLabel.Parent = container
			table.insert(resultsController.activeResultLabels, newLabel)
			resultsController.lastIndex = resultsController.lastIndex + 1
		end
	end

	stateLabel.TextColor3 = resultsController.latestPreset.color
	textGlowImage.ImageColor3 = stateLabel.TextColor3

	stateLabel.Text = resultsController.latestPreset.text
	totalLabel.Text = string.format(resultDefinitions.moneyFormat, mathUtilities.convertToUSD(resultInfo.totalScore))

	resultsHolder.Visible = true

	guiUtilities.changeGuiState({
		frame = resultsHolder,
		tweenInfo = TweenInfo.new(1),
		state = true,
	})

	resultsController.closeConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			or gameProcessed
		then
			return
		end

		if resultsController.closeConnection then
			resultsController.closeConnection:Disconnect()
			resultsController.closeConnection = nil
		end

		local fadeOutTween = guiUtilities.changeGuiState({
			frame = resultsHolder,
			tweenInfo = TweenInfo.new(5),
			state = false,
		})

		audioUtilities.applyEqualizerToSoundGroups({
			tweenInfo = fadeOutTween.TweenInfo,
			equalizerId = "results",
			groups = {
				soundGroups.Music,
				soundGroups.MusicDay,
			},
			properties = resultsController.__vars.equalizerPresets.inactive,
		})

		fadeOutTween.Completed:Once(function()
			resultsHolder.Visible = false
		end)
	end)
end

function resultsController.init()
	networking.events.sendResults.OnClientEvent:Connect(function(resultInfo)
		resultsController.onResultsEvent(resultInfo)
	end)
end

return resultsController
