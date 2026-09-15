local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local inputBindings = require(replicatedFirst.ClientUtilities.InputBindings)
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
local dismissalAction = {
	name = "dismissResults",
	keyCodes = { Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonA },
}
resultsController.activeResultLabels = {}
resultsController.lastIndex = 1
resultsController.closeConnection = nil
resultsController.dismissBind = nil
resultsController.dismissButton = nil
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

function resultsController.disconnectDismissal()
	local binding = resultsController.dismissBind
	resultsController.dismissBind = nil
	if binding then
		binding:Destroy()
	end
	resultsController.closeConnection = nil
	if resultsController.dismissButton then
		resultsController.dismissButton:Destroy()
		resultsController.dismissButton = nil
	end
end

function resultsController.createDismissButton(): TextButton
	local button = Instance.new("TextButton")
	button.Name = "DismissResults"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutoButtonColor = false
	button.Selectable = false
	button.ZIndex = 0
	button.Parent = interfaceGui
	return button
end

function resultsController.onResultsEvent(resultInfo)
	resultsController.lastIndex = 1

	resultsController.disconnectDismissal()

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

	local dismissButton = resultsController.createDismissButton()
	resultsController.dismissButton = dismissButton
	local dismissBind = inputBindings.create(dismissalAction, {
		button = dismissButton,
		priority = Enum.ContextActionPriority.High.Value,
		sink = true,
	})
	resultsController.dismissBind = dismissBind
	resultsController.closeConnection = inputBindings.connect(dismissBind, function(_active: boolean, pressed: boolean)
		if not pressed then
			return
		end
		resultsController.disconnectDismissal()

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
