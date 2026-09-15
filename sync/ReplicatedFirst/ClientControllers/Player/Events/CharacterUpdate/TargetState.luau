local targetState = {}

function targetState.create(): { [string]: any }
	return {
		packetSequenceByKind = {},
		motorTargets = {},
		cachedMotors = {},
	}
end

function targetState.getPlayerState(controller, otherPlayer: Player): { [string]: any }
	local playerState = controller.playerStates[otherPlayer]
	if playerState ~= nil then
		return playerState
	end

	playerState = targetState.create()
	controller.playerStates[otherPlayer] = playerState

	return playerState
end

function targetState.getCharacter(otherPlayer: Player): Model?
	return otherPlayer.Character
end

function targetState.getReplicationTestingCharacter(): Model?
	local replicationTesting = workspace:FindFirstChild("ReplicationTesting")
	if replicationTesting and replicationTesting:IsA("Model") then
		return replicationTesting
	end

	return nil
end

return targetState
