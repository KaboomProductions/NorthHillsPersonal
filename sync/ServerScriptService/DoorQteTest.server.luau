local players = game:GetService("Players")
local collectionService = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local serverStorage = game:GetService("ServerStorage")

--// Studio-only test fixture; it must never bind gameplay remotes in a published place.
if not runService:IsStudio() then
	return
end

local networking = require(replicatedStorage.Communication.Networking)
local remoteGuard = require(serverStorage.ServerUtilities.RemoteGuard)

local kickMinInterval = 1.4
local kickMaxInterval = 3.5
local kickDistance = 0.35

local powerKickChance = 0.2
local powerKickChargeTimeSeconds = 0.6
local powerKickDistance = 0.9

local rapidKickChance = 0.3
local rapidKickMinHits = 3
local rapidKickMaxHits = 5
local rapidKickIntervalSeconds = 0.35
local rapidKickDistance = 0.08

local pressureChance = 0.15
local pressureDurationSeconds = 3

local activeSessionsByPlayer: { [Player]: thread } = {}

local function calculateRandomInterval(): number
	return kickMinInterval + math.random() * (kickMaxInterval - kickMinInterval)
end

local function runKickLoop(player: Player)
	while activeSessionsByPlayer[player] do
		task.wait(calculateRandomInterval())

		if not activeSessionsByPlayer[player] then
			break
		end

		local roll = math.random()

		if roll < powerKickChance then
			task.wait(powerKickChargeTimeSeconds)
			if not activeSessionsByPlayer[player] then
				break
			end
			networking.events.doorQteKick:FireClient(player, powerKickDistance)
		elseif roll < powerKickChance + rapidKickChance then
			local hitCount = math.random(rapidKickMinHits, rapidKickMaxHits)
			for _ = 1, hitCount do
				if not activeSessionsByPlayer[player] then
					break
				end
				networking.events.doorQteKick:FireClient(player, rapidKickDistance)
				task.wait(rapidKickIntervalSeconds)
			end
		elseif roll < powerKickChance + rapidKickChance + pressureChance then
			local angle = math.random() * math.pi * 2
			networking.events.doorQtePressure:FireClient(player, {
				directionX = math.cos(angle),
				directionY = math.sin(angle),
				duration = pressureDurationSeconds,
			})
		else
			networking.events.doorQteKick:FireClient(player, kickDistance)
		end
	end
end

local function startSession(player: Player, door: Instance?)
	if activeSessionsByPlayer[player] then
		return
	end

	networking.events.startDoorQte:FireClient(player, door :: any)

	activeSessionsByPlayer[player] = task.spawn(runKickLoop, player)
end

local function endSession(player: Player)
	local sessionThread = activeSessionsByPlayer[player]
	if not sessionThread then
		return
	end

	activeSessionsByPlayer[player] = nil
	if coroutine.running() ~= sessionThread then
		task.cancel(sessionThread)
	end
	networking.events.endDoorQte:FireClient(player)
end

networking.events.doorQteFailed.OnServerEvent:Connect(function(player: Player)
	if not remoteGuard.allow(player, "doorQteFailed", 4, 1) then
		return
	end

	local sessionThread = activeSessionsByPlayer[player]
	if not sessionThread then
		return
	end

	activeSessionsByPlayer[player] = nil
	task.cancel(sessionThread)
	print(`{player.Name} failed the QTE`)
end)

players.PlayerRemoving:Connect(function(player: Player)
	local sessionThread = activeSessionsByPlayer[player]
	activeSessionsByPlayer[player] = nil
	if sessionThread then
		task.cancel(sessionThread)
	end
end)

local function bindPrompt(prompt: ProximityPrompt)
	prompt.Triggered:Connect(function(player: Player)
		if not remoteGuard.allow(player, "doorQtePrompt", 4, 1) then
			return
		end

		if activeSessionsByPlayer[player] then
			endSession(player)
		else
			startSession(player, prompt:FindFirstAncestorWhichIsA("Model"))
		end
	end)
end

for _, prompt in collectionService:GetTagged("QteTest") do
	if prompt:IsA("ProximityPrompt") then
		bindPrompt(prompt)
	end
end

collectionService:GetInstanceAddedSignal("QteTest"):Connect(function(instance)
	if instance:IsA("ProximityPrompt") then
		bindPrompt(instance)
	end
end)
