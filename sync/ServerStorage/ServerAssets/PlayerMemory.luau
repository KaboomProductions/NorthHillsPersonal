local playerRoomMemory = {}
playerRoomMemory.mapping = {}
playerRoomMemory.allBuildings = nil
playerRoomMemory.allBuildingRooms = nil
--[userIdString] = { [building] = { [roomKey] = { count, lastVisited } } }
local sessionData = {}

local function userKey(player: Player): string
	return tostring(player.UserId)
end

function playerRoomMemory:init(player: Player)
	sessionData[userKey(player)] = {}
end

function playerRoomMemory:getRoomFloorParts(building: string, roomName: string)
	local buildingData = self.mapping[building]

	if not buildingData then
		return nil
	end

	return buildingData.floor[roomName]
end

function playerRoomMemory:getAllBuildings()
	if self.allBuildings then
		return self.allBuildings
	end

	local buildings = {}

	for buildingName, buildingData in self.mapping do
		local rooms = {}

		for _, room in buildingData.rooms do
			table.insert(rooms, room)
		end

		if #rooms > 0 then
			table.insert(buildings, {
				name = buildingName,
				rooms = rooms,
			})
		end
	end

	self.allBuildings = buildings

	return buildings
end

function playerRoomMemory:getBuildingRooms(building)
	local buildingData = self.mapping[building]

	if not buildingData then
		return {}
	end

	local rooms = {}

	for _, room in buildingData.rooms do
		table.insert(rooms, room)
	end

	return rooms
end

function playerRoomMemory:getAllBuildingRooms()
	if playerRoomMemory.allBuildingRooms then
		return playerRoomMemory.allBuildingRooms
	end

	local allRooms = {}

	for _, buildingData in playerRoomMemory.mapping do
		for _, room in buildingData.rooms do
			table.insert(allRooms, room)
		end
	end

	playerRoomMemory.allBuildingRooms = allRooms

	return allRooms
end

function playerRoomMemory:recordVisit(player: Player, building: string, roomKey: string)
	local key = userKey(player)
	local playerData = sessionData[key]
	if not playerData then
		return
	end

	playerData[building] = playerData[building] or {}
	local entry = playerData[building][roomKey]

	if entry then
		entry.count = entry.count + 1
		entry.lastVisited = os.clock()
	else
		playerData[building][roomKey] = { count = 1, lastVisited = os.clock() }
	end
end

function playerRoomMemory:getRoomWeight(player: Player, building: string, roomKey: string): number
	local key = userKey(player)
	local playerData = sessionData[key]
	if not playerData or not playerData[building] then
		return 1
	end

	local entry = playerData[building][roomKey]
	if not entry then
		return 1
	end

	local minutesSince = (os.clock() - entry.lastVisited) / 60
	local decay = 0.5 ^ (minutesSince / 5)
	local frequencyBoost = math.min(entry.count, 10) * 0.15

	return 1 + frequencyBoost * decay
end

function playerRoomMemory:cleanUp(player: Player)
	sessionData[userKey(player)] = nil
end

return playerRoomMemory
