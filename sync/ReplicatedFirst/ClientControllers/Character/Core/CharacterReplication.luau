local replicatedStorage = game:GetService("ReplicatedStorage")

local networking = require(replicatedStorage.Communication.Networking)
local characterReplication = require(replicatedStorage.SharedUtilities.CharacterReplication)

local characterReplicationController = {}
characterReplicationController.__index = characterReplicationController
characterReplicationController.shared = nil
characterReplicationController.__vars = {
	replicateIntervalSeconds = 0.1,
	minimumSendIntervalSeconds = 0.03,
	nextReplicationSequence = 0,

	elapsedSecondsByKind = {
		[characterReplication.packetKinds.body] = 0,
		[characterReplication.packetKinds.shoulders] = 0,
	},

	lastFieldsByKind = {
		[characterReplication.packetKinds.body] = nil,
		[characterReplication.packetKinds.shoulders] = nil,
	},

	lastSendTimeByKind = {
		[characterReplication.packetKinds.body] = 0,
		[characterReplication.packetKinds.shoulders] = 0,
	},
}

local function buildPacket(packetKind: string, sequence: number, cframes, lastEncodedFieldMap, forceSend: boolean?)
	if packetKind == characterReplication.packetKinds.body then
		return characterReplication.createBodyPacket(sequence, cframes, lastEncodedFieldMap, forceSend)
	end

	return characterReplication.createShoulderPacket(sequence, cframes, lastEncodedFieldMap, forceSend)
end

function characterReplicationController:send(packetKind: string, cframes, forceSend: boolean?): boolean
	if cframes == nil or next(cframes) == nil then
		return false
	end

	local stateValues = self.__vars
	local currentTime = time()
	local lastSendTime = stateValues.lastSendTimeByKind[packetKind]

	if (currentTime - lastSendTime) < stateValues.minimumSendIntervalSeconds then
		return false
	end

	local lastEncodedFieldMap = stateValues.lastFieldsByKind[packetKind]
	local packet, encodedFieldMap =
		buildPacket(packetKind, stateValues.nextReplicationSequence, cframes, lastEncodedFieldMap, forceSend)

	stateValues.lastFieldsByKind[packetKind] = encodedFieldMap
	if packet == nil then
		return false
	end

	stateValues.nextReplicationSequence += 1
	stateValues.lastSendTimeByKind[packetKind] = currentTime
	networking.events.characterUpdate:FireServer(packet)

	return true
end

function characterReplicationController:step(packetKind: string, deltaTime: number, cframes): boolean
	if cframes == nil or next(cframes) == nil then
		return false
	end

	local elapsedSecondsByKind = self.__vars.elapsedSecondsByKind
	elapsedSecondsByKind[packetKind] += deltaTime

	if elapsedSecondsByKind[packetKind] < self.__vars.replicateIntervalSeconds then
		return false
	end

	elapsedSecondsByKind[packetKind] = 0

	return self:send(packetKind, cframes)
end

function characterReplicationController:resetKind(packetKind: string)
	self.__vars.elapsedSecondsByKind[packetKind] = 0
	self.__vars.lastFieldsByKind[packetKind] = nil
	self.__vars.lastSendTimeByKind[packetKind] = 0
end

function characterReplicationController.new()
	local self = setmetatable({}, characterReplicationController)

	self.__vars = {
		replicateIntervalSeconds = characterReplicationController.__vars.replicateIntervalSeconds,
		minimumSendIntervalSeconds = characterReplicationController.__vars.minimumSendIntervalSeconds,
		nextReplicationSequence = characterReplicationController.__vars.nextReplicationSequence,
		elapsedSecondsByKind = table.clone(characterReplicationController.__vars.elapsedSecondsByKind),
		lastFieldsByKind = table.clone(characterReplicationController.__vars.lastFieldsByKind),
		lastSendTimeByKind = table.clone(characterReplicationController.__vars.lastSendTimeByKind),
	}
	characterReplicationController.shared = self

	return self
end

function characterReplicationController.getShared()
	local sharedController = characterReplicationController.shared
	if sharedController ~= nil then
		return sharedController
	end

	sharedController = characterReplicationController.new()
	characterReplicationController.shared = sharedController

	return sharedController
end

function characterReplicationController:destroy()
	if characterReplicationController.shared == self then
		characterReplicationController.shared = nil
	end

	table.clear(self.__vars.elapsedSecondsByKind)
	table.clear(self.__vars.lastFieldsByKind)
	table.clear(self.__vars.lastSendTimeByKind)
	table.clear(self.__vars)
	setmetatable(self, nil)
end

return characterReplicationController
