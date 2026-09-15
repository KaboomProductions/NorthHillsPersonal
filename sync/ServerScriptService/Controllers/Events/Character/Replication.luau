local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local characterReplication = require(replicatedStorage.SharedUtilities.CharacterReplication)
local networking = require(replicatedStorage.Communication.Networking)

local replicationController = {}
local statesByPlayerCache: { [Player]: { [string]: { lastSequence: number, lastTimestamp: number } } } = {}

local revelenceDistance = 120
local absoluteMinimumInterval = 0.03
local maxEventsPerSecondPerPlayer = 40

local eventBucketsByPlayer: { [Player]: { count: number, windowStart: number } } = {}
local minimumIntervalByPacketKind: { [string]: number } = {
	[characterReplication.packetKinds.body] = 0.09,
	[characterReplication.packetKinds.shoulders] = 0.09,
}

local function isPlayerFlooding(player: Player): boolean
	local currentTime = time()
	local bucket = eventBucketsByPlayer[player]

	if bucket == nil or currentTime - bucket.windowStart >= 1 then
		bucket = { count = 0, windowStart = currentTime }
		eventBucketsByPlayer[player] = bucket
	end

	bucket.count = bucket.count + 1
	return bucket.count > maxEventsPerSecondPerPlayer
end

function replicationController.getKindState(
	player: Player,
	packetKind: string
): { lastSequence: number, lastTimestamp: number }
	local playerStates = statesByPlayerCache[player]

	if playerStates == nil then
		playerStates = {}
		statesByPlayerCache[player] = playerStates
	end

	local existingState = playerStates[packetKind]

	if existingState ~= nil then
		return existingState
	end

	local newState = { lastSequence = 0, lastTimestamp = 0 }
	playerStates[packetKind] = newState

	return newState
end

function replicationController.shouldRelayPacket(player: Player, replicationPacket: { [string]: any }): boolean
	local packetKind = replicationPacket.k
	local sequenceNumber = replicationPacket.s
	local currentTime = time()
	local kindState = replicationController.getKindState(player, packetKind)

	if sequenceNumber <= kindState.lastSequence then
		return false
	end

	local elapsedSinceLast = currentTime - kindState.lastTimestamp
	if elapsedSinceLast < absoluteMinimumInterval then
		return false
	end

	if replicationPacket.f == true then
		kindState.lastSequence = sequenceNumber
		kindState.lastTimestamp = currentTime
		return true
	end

	local minimumInterval = minimumIntervalByPacketKind[packetKind]
	if minimumInterval ~= nil and elapsedSinceLast < minimumInterval then
		return false
	end

	kindState.lastSequence = sequenceNumber
	kindState.lastTimestamp = currentTime
	return true
end

function replicationController.relayPacket(player: Player, rawPacket: any)
	if isPlayerFlooding(player) then
		return
	end

	local sanitizedPacket = characterReplication.sanitizePacket(rawPacket)

	if sanitizedPacket == nil then
		return
	end

	if not replicationController.shouldRelayPacket(player, sanitizedPacket) then
		return
	end

	local senderRoot = player.Character and player.Character.PrimaryPart

	if senderRoot == nil then
		return
	end

	for _, otherPlayer in ipairs(players:GetPlayers()) do
		if otherPlayer == player or otherPlayer:GetAttribute("InMenu") then
			continue
		end

		local otherRoot = otherPlayer.Character and otherPlayer.Character.PrimaryPart
		if otherRoot == nil then
			continue
		end

		if vector.magnitude(otherRoot.Position - senderRoot.Position) > revelenceDistance then
			continue
		end

		networking.events.characterUpdate:FireClient(otherPlayer, player, sanitizedPacket.buffer)
	end
end

function replicationController.init()
	networking.events.characterUpdate.OnServerEvent:Connect(function(player: Player, rawPacket: any)
		replicationController.relayPacket(player, rawPacket)
	end)

	players.PlayerRemoving:Connect(function(player: Player)
		statesByPlayerCache[player] = nil
	end)
end

return replicationController
