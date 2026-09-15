local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets

local gameFolder = workspace.Game
local mapFolder = gameFolder.Map
local propsFolderPreset = mapFolder.Props

local sharedAssets = replicatedStorage.SharedAssets
local cyclePhase = require(sharedAssets.CyclePhase)

local climateController = require(script.Climate)
local fakeAmbienceController = require(script.FakeAmbience)
local resultsController = require(script.Results)
local musicController = require(script.MusicController)
local cycleConfig = require(script.CycleConfig)
local networking = require(replicatedStorage.Communication.Networking)

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local timeValues = cycleValues.TimeCycle

local audio = workspace.Audio
local audioEffects = audio.Effects
local nightfallSound = audioEffects.Nightfall

local nightTimeValue = timeValues.NightTime
local climateStateValue = cycleValues.ClimateState
local remainingTimeValue = timeValues.RemainingTime
local transitionStateValue = timeValues.TransitionState
local cycleActiveValue = cycleValues.CycleActive

local currentPropsFolder = nil

local roundCycleSystem = {}
roundCycleSystem.onPhaseStarted = {}
roundCycleSystem.onTransitionStarted = {}
roundCycleSystem.failSafeTimer = 30
roundCycleSystem.loopGeneration = 0
roundCycleSystem.roundId = 0

local thunderStallLimitSeconds = 15

local function sendToReadyPlayers(nextPhase: string)
	local currentClimateName = climateStateValue.Value
	local readyCount = 0

	for _, player in ipairs(players:GetPlayers()) do
		if player:GetAttribute("RoundCycleEventsReady") then
			networking.events.roundCycleTransition:FireClient(player, {
				phaseString = nextPhase,
				climateStateName = currentClimateName,
			})
			readyCount += 1
		end
	end

	if readyCount == 0 then
		warn("[RoundCycle] No ready players to receive transition to", nextPhase)
	end
end

local function fireHooks(hookList: { (...any) -> () }, ...)
	for _, hookCallback in ipairs(hookList) do
		task.spawn(hookCallback, ...)
	end
end

function roundCycleSystem.getCurrentPhase(): string
	return nightTimeValue.Value and cyclePhase.Night or cyclePhase.Day
end

function roundCycleSystem.getNextPhase(): string
	return nightTimeValue.Value and cyclePhase.Day or cyclePhase.Night
end

function roundCycleSystem.buildSnapshot()
	return {
		isNight = nightTimeValue.Value,
		isTransitioning = transitionStateValue.Value,
		climateStateName = climateStateValue.Value,
		cycleActive = cycleActiveValue.Value,
		roundId = roundCycleSystem.roundId,
	}
end

function roundCycleSystem.sendSnapshotTo(player: Player)
	networking.events.cycleStateUpdate:FireClient(player, roundCycleSystem.buildSnapshot())

	if transitionStateValue.Value then
		networking.events.roundCycleTransition:FireClient(player, {
			phaseString = roundCycleSystem.getNextPhase(),
			climateStateName = climateStateValue.Value,
		})
	end
end

function roundCycleSystem.publishCycleState()
	local stateSnapshot = roundCycleSystem.buildSnapshot()

	for _, player in ipairs(players:GetPlayers()) do
		if player:GetAttribute("RoundCycleEventsReady") then
			networking.events.cycleStateUpdate:FireClient(player, stateSnapshot)
		end
	end
end

--// Remaining time is derived from a deadline so scheduler stalls do not stretch the phase.
function roundCycleSystem.countDown()
	local phaseDeadline = os.clock() + remainingTimeValue.Value
	local thunderStallStartedAt: number? = nil

	repeat
		task.wait(1)

		remainingTimeValue.Value = math.max(math.ceil(phaseDeadline - os.clock()), 0)

		if remainingTimeValue.Value <= 0 and climateStateValue:HasTag("ActiveThundering") then
			local stallStartedAt = thunderStallStartedAt or os.clock()
			thunderStallStartedAt = stallStartedAt

			if os.clock() - stallStartedAt >= thunderStallLimitSeconds then
				climateStateValue:RemoveTag("ActiveThundering")
			end
		end
	until (remainingTimeValue.Value <= 0 and not climateStateValue:HasTag("ActiveThundering"))
		or not cycleActiveValue.Value
end

function roundCycleSystem.startTransition()
	if not cycleActiveValue.Value then
		warn("[RoundCycle] startTransition called but cycle is not active")
		return
	end

	climateController.decide()

	remainingTimeValue.Value = cycleConfig.transitionLengthSeconds
	transitionStateValue.Value = true

	local nextPhase = roundCycleSystem.getNextPhase()

	if nextPhase == cyclePhase.Night then
		nightfallSound:Play()
	end

	sendToReadyPlayers(nextPhase)
	fireHooks(roundCycleSystem.onTransitionStarted, nextPhase)

	roundCycleSystem.countDown()

	if not cycleActiveValue.Value then
		transitionStateValue.Value = false
		return
	end

	nightTimeValue.Value = nextPhase == cyclePhase.Night
	transitionStateValue.Value = false

	if not nightTimeValue.Value then
		roundCycleSystem.roundId += 1
		local didProcessResults, resultsError = pcall(resultsController.updateForResults, roundCycleSystem.roundId)
		if not didProcessResults then
			warn("[RoundCycle] Results processing failed:", resultsError)
		end

		task.wait(cycleConfig.resultDelayTime)
	end

	networking.events.sendNotification:FireAllClients(nightTimeValue.Value)

	roundCycleSystem.publishCycleState()
end

function roundCycleSystem.handleNewState()
	if not cycleActiveValue.Value then
		return
	end

	local currentPhase = roundCycleSystem.getCurrentPhase()
	fireHooks(roundCycleSystem.onPhaseStarted, currentPhase)

	if currentPhase == cyclePhase.Day then
		musicController.playDaytimeTrack(climateStateValue.Value)

		task.spawn(function()
			if currentPropsFolder then
				currentPropsFolder:Destroy()
				currentPropsFolder = nil
			end

			currentPropsFolder = propsFolderPreset:Clone()
			currentPropsFolder.Parent = mapFolder
		end)

		remainingTimeValue.Value = musicController.getCurrentTrackLength()
	elseif currentPhase == cyclePhase.Night then
		musicController.fadeOutCurrent()

		local currentClimateConfig = climateController.getCurrentConfig()
		local nightMultiplier = currentClimateConfig.nightLengthMultiplier or 1
		remainingTimeValue.Value = cycleConfig.nightLengthSeconds * nightMultiplier
	end

	roundCycleSystem.publishCycleState()
	roundCycleSystem.countDown()

	if not cycleActiveValue.Value then
		return
	end

	roundCycleSystem.startTransition()
end

function roundCycleSystem.startCycle()
	if cycleActiveValue.Value then
		return
	end

	roundCycleSystem.loopGeneration += 1
	local loopGeneration = roundCycleSystem.loopGeneration
	cycleActiveValue.Value = true

	--// A stale loop from before stop/resume must exit instead of driving the cycle twice.
	while cycleActiveValue.Value and loopGeneration == roundCycleSystem.loopGeneration do
		roundCycleSystem.handleNewState()
	end
end

function roundCycleSystem.stop()
	cycleActiveValue.Value = false
	roundCycleSystem.loopGeneration += 1
end

function roundCycleSystem.resume()
	if cycleActiveValue.Value then
		return
	end

	task.defer(roundCycleSystem.startCycle)
end

function roundCycleSystem.new()
	if propsFolderPreset.Parent ~= serverAssets then
		propsFolderPreset.Parent = serverAssets
	end

	for _, prop in propsFolderPreset:GetDescendants() do
		if not prop:IsA("BasePart") then
			continue
		end

		if not prop:FindFirstChildOfClass("PathfindingModifier") then
			local newModifier = Instance.new("PathfindingModifier")
			newModifier.PassThrough = true
			newModifier.Parent = prop
		end

		prop.Anchored = true
	end

	musicController.preload()
	climateController.preload()
	fakeAmbienceController:init()
	task.defer(roundCycleSystem.startCycle)
end

return roundCycleSystem
