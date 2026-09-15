local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)

local networking = require(replicatedStorage.Communication.Networking)
local roundCycleSystem = require(serverScriptService.Systems.RoundCycle)

local roundCycleController = {}

function roundCycleController.onEvent(player: Player)
	if not remoteGuard.allow(player, "roundReady", 2, 1) then
		return
	end
	player:SetAttribute("RoundCycleEventsReady", true)

	roundCycleSystem.sendSnapshotTo(player)
end

function roundCycleController.init()
	networking.events.markRoundCycleEventsReady.OnServerEvent:Connect(function(player: Player)
		roundCycleController.onEvent(player)
	end)
end

return roundCycleController
