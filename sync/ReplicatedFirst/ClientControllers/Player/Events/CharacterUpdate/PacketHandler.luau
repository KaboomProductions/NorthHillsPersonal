local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local characterReplication = require(replicatedStorage.SharedUtilities.CharacterReplication)

local smoothing = require(script.Parent.Smoothing)
local targetState = require(script.Parent.TargetState)

local packetHandler = {}
packetHandler.packetKinds = characterReplication.packetKinds

function packetHandler.handlePacketForState(targetStateEntry, character: Model, packet)
	local packetKind, sequence, cframes = characterReplication.decodePacket(packet)
	if packetKind == nil or sequence == nil or cframes == nil then
		return
	end

	local lastSequence = targetStateEntry.packetSequenceByKind[packetKind]
	if lastSequence ~= nil and sequence <= lastSequence then
		return
	end

	targetStateEntry.packetSequenceByKind[packetKind] = sequence

	if packetKind == packetHandler.packetKinds.body then
		smoothing.updateBodyTargets(targetStateEntry, character, cframes)
		return
	end

	smoothing.updateShoulderTargets(targetStateEntry, character, cframes)
end

function packetHandler.handlePacket(controller, otherPlayer: Player, packet)
	if otherPlayer == players.LocalPlayer then
		local previewCharacter = targetState.getReplicationTestingCharacter()
		if previewCharacter == nil then
			controller.previewState = nil
			return
		end

		local previewState = controller.previewState
		if previewState == nil then
			previewState = targetState.create()
			controller.previewState = previewState
		end

		packetHandler.handlePacketForState(previewState, previewCharacter, packet)
		return
	end

	local character = targetState.getCharacter(otherPlayer)
	if character == nil then
		return
	end

	packetHandler.handlePacketForState(targetState.getPlayerState(controller, otherPlayer), character, packet)
end

return packetHandler
