local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local dictionaries = sharedAssets.Dictionaries
local resultDefinitions = require(dictionaries.ResultDefinitions)

local scoreTrackerController = {}
scoreTrackerController.sessions = {}

function scoreTrackerController.startSession(player: Player)
	scoreTrackerController.sessions[player.UserId] = {
		entries = {},
		grouped = {},
		total = 0,
	}
end

function scoreTrackerController.updateReward(player: Player, rewardId: string, amount: number?)
	local session = scoreTrackerController.sessions[player.UserId]
	local definition = resultDefinitions[rewardId]

	if not session or not definition then
		return
	end

	local group = session.grouped[rewardId]
	if not group then
		group = {
			id = rewardId,
			count = 0,
			amountSum = 0,
			totalPoints = 0,
		}
		session.grouped[rewardId] = group
	end

	group.count = group.count + 1
	if amount then
		group.amountSum = group.amountSum + amount
	end

	local totalEarned = 0

	if not definition.noGain then
		if not definition.mode then
			definition.mode = "flat"
		end

		if definition.mode == "flat" then
			totalEarned = definition.reward
		elseif definition.mode == "scaled" then
			amount = amount or 0
			totalEarned = amount * definition.pointsPerUnit

			if definition.cap then
				local remainingRoom = definition.cap - group.totalPoints
				totalEarned = math.clamp(totalEarned, 0, math.max(remainingRoom, 0))
			end
		end

		group.totalPoints = group.totalPoints + totalEarned
		session.total = session.total + totalEarned
	end

	table.insert(session.entries, {
		id = rewardId,
		amount = amount,
		points = totalEarned,
		timestamp = os.clock(),
	})
end

function scoreTrackerController.getResults(player: Player)
	local session = scoreTrackerController.sessions[player.UserId]
	local breakdown = {}

	if not session then
		return nil
	end

	for _, group in session.grouped do
		table.insert(breakdown, group)
	end

	return {
		totalScore = session.total,
		breakdown = breakdown,
	}
end

function scoreTrackerController.clearSessions()
	table.clear(scoreTrackerController.sessions)
end

return scoreTrackerController
