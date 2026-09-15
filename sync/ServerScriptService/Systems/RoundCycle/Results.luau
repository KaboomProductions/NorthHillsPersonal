local serverStorage = game:GetService("ServerStorage")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

local serverAssets = serverStorage.ServerAssets
local scoreTrackerController = require(serverAssets.ScoreTracker)
local groupMembership = require(serverStorage.ServerUtilities.GroupMembership)
local playerData = require(serverScriptService.GameHandler.PlayerData)

local resultsController = {}

local resultsTimeoutSeconds = 10

local lastProcessedRoundIdByPlayer: { [Player]: number } = {}

local function readWholeCounter(storedCounter: unknown): number
	if typeof(storedCounter) ~= "number" or storedCounter ~= storedCounter or math.abs(storedCounter) == math.huge then
		return 0
	end
	return math.max(math.floor(storedCounter), 0)
end

local function isEligibleForResults(player: Player): boolean
	return player.Parent == players
		and scoreTrackerController.sessions[player.UserId] ~= nil
		and player:GetAttribute("Money") ~= nil
		and player:GetAttribute("Survivals") ~= nil
end

local function persistCounters(player: Player, money: number, survivals: number)
	player:SetAttribute("Money", money)
	player:SetAttribute("Survivals", survivals)

	local profileData = playerData.get(player)
	if profileData then
		profileData.Money = money
		profileData.Survivals = survivals
	end
end

function resultsController.sendResultsForPlayer(player: Player)
	local currentMoney = readWholeCounter(player:GetAttribute("Money"))
	local currentSurvivals = readWholeCounter(player:GetAttribute("Survivals"))

	local resultsForPlayer = scoreTrackerController.getResults(player)
	if resultsForPlayer == nil then
		return
	end
	resultsForPlayer.survived = player:GetAttribute("Survived") == true

	player:SetAttribute("Survived", true)

	if resultsForPlayer.survived then
		currentSurvivals += 1
	elseif resultsForPlayer.totalScore > 0 then
		resultsForPlayer.totalScore = resultsForPlayer.totalScore / 2
	end

	persistCounters(player, currentMoney + math.round(resultsForPlayer.totalScore), currentSurvivals)

	networking.events.sendResults:FireClient(player, resultsForPlayer)

	scoreTrackerController.startSession(player)
end

local function applyRoundRewards(player: Player)
	if not player:GetAttribute("Survived") then
		scoreTrackerController.updateReward(player, "nonSurvived")
		return
	end

	scoreTrackerController.updateReward(player, "survived")
	if groupMembership.isMember(player) then
		scoreTrackerController.updateReward(player, "inGroup")
	end
end

local function processPlayerResults(player: Player, roundId: number)
	if lastProcessedRoundIdByPlayer[player] == roundId then
		return
	end
	lastProcessedRoundIdByPlayer[player] = roundId

	applyRoundRewards(player)

	if player.Parent ~= players then
		return
	end

	resultsController.sendResultsForPlayer(player)
end

local function waitForPendingResults(pendingCount: () -> number, finishedEvent: BindableEvent, settle: () -> ())
	local timeoutThread = task.delay(resultsTimeoutSeconds, function()
		warn(string.format("[RoundCycle] %d result(s) still pending after %ds", pendingCount(), resultsTimeoutSeconds))
		settle()
	end)
	finishedEvent.Event:Wait()
	if coroutine.status(timeoutThread) == "suspended" then
		task.cancel(timeoutThread)
	end
end

--// Each player's results run in isolation and the wait is bounded so one stalled lookup cannot hold the round.
function resultsController.updateForResults(roundId: number)
	local pendingPlayerCount = 0
	local hasSettled = false
	local finishedEvent = Instance.new("BindableEvent")

	local function settle()
		if hasSettled then
			return
		end
		hasSettled = true
		finishedEvent:Fire()
	end

	for _, player in players:GetPlayers() do
		if not isEligibleForResults(player) then
			continue
		end

		pendingPlayerCount += 1
		task.spawn(function()
			local didProcess, processError = pcall(processPlayerResults, player, roundId)
			if not didProcess then
				warn(string.format("[RoundCycle] Results failed for %s: %s", player.Name, tostring(processError)))
			end
			pendingPlayerCount -= 1
			if pendingPlayerCount == 0 then
				settle()
			end
		end)
	end

	if pendingPlayerCount > 0 and not hasSettled then
		waitForPendingResults(function()
			return pendingPlayerCount
		end, finishedEvent, settle)
	end
	finishedEvent:Destroy()
end

players.PlayerRemoving:Connect(function(player: Player)
	lastProcessedRoundIdByPlayer[player] = nil
end)

return resultsController
