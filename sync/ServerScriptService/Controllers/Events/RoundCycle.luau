local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)

local networking = require(replicatedStorage.Communication.Networking)
local cyclePhase = require(replicatedStorage.SharedAssets.CyclePhase)

local roundCycleValues = replicatedStorage.Values.RoundCycle
local timeCycleValues = roundCycleValues.TimeCycle
local nightTimeValue = timeCycleValues.NightTime
local transitionStateValue = timeCycleValues.TransitionState
local cycleActiveValue = roundCycleValues.CycleActive
local climateStateValue = roundCycleValues.ClimateState

local roundCycleController = {}

function roundCycleController.onEvent(player: Player)
	if not remoteGuard.allow(player, "roundReady", 2, 1) then
		return
	end
	player:SetAttribute("RoundCycleEventsReady", true)

	networking.events.cycleStateUpdate:FireClient(player, {
		isNight = nightTimeValue.Value,
		isTransitioning = transitionStateValue.Value,
		climateStateName = climateStateValue.Value,
		cycleActive = cycleActiveValue.Value,
	})

	if transitionStateValue.Value then
		local nextPhase = nightTimeValue.Value and cyclePhase.Day or cyclePhase.Night
		networking.events.roundCycleTransition:FireClient(player, {
			phaseString = nextPhase,
			climateStateName = climateStateValue.Value,
		})
	end
end

function roundCycleController.init()
	networking.events.markRoundCycleEventsReady.OnServerEvent:Connect(function(player: Player)
		roundCycleController.onEvent(player)
	end)
end

return roundCycleController
