local serverStorage = game:GetService("ServerStorage")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

local serverAssets = serverStorage.ServerAssets
local scoreTrackerController = require(serverAssets.ScoreTracker)

local resultsController = {}

function resultsController.sendResultsForPlayer(player: Player)
	local currentMoney = player:GetAttribute("Money")
	local currentSurvivals = player:GetAttribute("Survivals")

	local resultsForPlayer = scoreTrackerController.getResults(player)
	resultsForPlayer.survived = player:GetAttribute("Survived")

	player:SetAttribute("Survived", true)

	if resultsForPlayer.survived then
		player:SetAttribute("Survivals", currentSurvivals + 1)
	else
		if resultsForPlayer.totalScore > 0 then
			resultsForPlayer.totalScore = resultsForPlayer.totalScore / 2
		end
	end

	player:SetAttribute("Money", currentMoney + math.round(resultsForPlayer.totalScore))

	networking.events.sendResults:FireClient(player, resultsForPlayer)

	scoreTrackerController.startSession(player)
end

function resultsController.updateForResults()
	for _, player in players:GetPlayers() do
		if player:GetAttribute("Survived") then
			scoreTrackerController.updateReward(player, "survived")

			if player:IsInGroupAsync(867384979) then
				scoreTrackerController.updateReward(player, "inGroup")
			end
		else
			scoreTrackerController.updateReward(player, "nonSurvived")
		end

		resultsController.sendResultsForPlayer(player)
	end
end

return resultsController
