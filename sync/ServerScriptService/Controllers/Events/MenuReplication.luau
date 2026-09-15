local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)

local networking = require(replicatedStorage.Communication.Networking)

local menuReplicationController = {}

function menuReplicationController.onEvent(player: Player, state: boolean)
	if typeof(state) ~= "boolean" or not remoteGuard.allow(player, "menu", 8, 1) then
		return
	end
	if not state then
		player.ReplicationFocus = nil
	end
	player:SetAttribute("InMenu", state)
end

function menuReplicationController.init()
	networking.events.replicateMenu.OnServerEvent:Connect(function(player: Player, state: boolean)
		menuReplicationController.onEvent(player, state)
	end)
end

return menuReplicationController
