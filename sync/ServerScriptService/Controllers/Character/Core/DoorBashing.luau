local doorBashingController = {}
doorBashingController.__index = doorBashingController
doorBashingController.__vars = {
	updateRate = 0.03,
	speedThreshold = 18,
	distanceThreshold = 4,
	velocityHistoryWindow = 0.15, -- how far back to look for a valid approach speed
	minApproachDot = 0.5, -- how "toward the door" the velocity needs to be (0-1)
}

local serverScriptService = game:GetService("ServerScriptService")

local interactablesController = serverScriptService.Systems.Interactables
local doorsController = require(interactablesController.Doors)

function doorBashingController:preload()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid")
	self.humanoidRootPart = self.humanoid and self.humanoid.RootPart
		or self.character:FindFirstChild("HumanoidRootPart")

	self.cachedDoors = doorsController.activeDoors
end

-- Rolling buffer of recent (speed, direction) samples so a collision-induced
-- stop doesn't erase the fact that they *were* charging the door a frame ago.
function doorBashingController:recordVelocitySample()
	local rootPart = self.humanoidRootPart
	if not rootPart then
		return
	end

	local velocity = rootPart.AssemblyLinearVelocity
	local flatVelocity = vector.create(velocity.X, 0, velocity.Z) -- ignore fall speed

	table.insert(self.velocityHistory, {
		time = os.clock(),
		velocity = flatVelocity,
		speed = vector.magnitude(flatVelocity),
	})

	local cutoff = os.clock() - self.__vars.velocityHistoryWindow
	while self.velocityHistory[1] and self.velocityHistory[1].time < cutoff do
		table.remove(self.velocityHistory, 1)
	end
end

-- Returns the fastest recent sample, and whether it was aimed at the door.
function doorBashingController:getBestApproach(doorPosition: vector)
	local rootPart = self.humanoidRootPart
	local toDoor = vector.create(doorPosition.x, 0, doorPosition.z)
		- vector.create(rootPart.Position.X, 0, rootPart.Position.Z)

	if vector.magnitude(toDoor) < 1e-3 then
		return 0, 1
	end

	local toDoorNormalized = vector.normalize(toDoor)

	local bestSpeed = 0
	local bestDot = 0

	for _, sample in self.velocityHistory do
		if sample.speed < 1e-3 then
			continue
		end

		local dot = vector.dot(vector.normalize(sample.velocity), toDoorNormalized)

		if sample.speed > bestSpeed and dot > 0 then
			bestSpeed = sample.speed
			bestDot = dot
		end
	end

	return bestSpeed, bestDot
end

function doorBashingController:bashDoor(door: any)
	door:setState(self.humanoidRootPart, true, 10, "DoorBash")
end

function doorBashingController:isBashValid(door: any)
	local instance = door.instance
	local mainPivot = instance:GetPivot()

	if door.attributes.Open then
		return false
	end

	local canBash = door:canPlayerActuate(self.player, true)
	if not canBash then
		return false
	end

	local rootPart = self.humanoidRootPart
	local distance = vector.magnitude(rootPart.Position - mainPivot.Position)

	if distance > self.__vars.distanceThreshold then
		return false
	end

	local state = self.humanoid:GetState()
	local isValidState = state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Landed
		and state ~= Enum.HumanoidStateType.Climbing

	if not isValidState then
		return false
	end

	local bestSpeed, approachDot = self:getBestApproach(mainPivot.Position)
	return bestSpeed > self.__vars.speedThreshold and approachDot >= self.__vars.minApproachDot
end

function doorBashingController:checkForDoors()
	for _, door in self.cachedDoors do
		if not self:isBashValid(door) then
			continue
		end

		self:bashDoor(door)

		table.clear(self.velocityHistory)
	end
end

function doorBashingController:init()
	self:preload()

	task.spawn(function()
		while getmetatable(self) do
			self:recordVelocitySample()
			self:checkForDoors()

			task.wait(self.__vars.updateRate)
		end
	end)
end

function doorBashingController.new(player: Player, character: Model)
	local self = setmetatable({}, doorBashingController)

	self.player = player
	self.character = character
	self.humanoid = nil
	self.humanoidRootPart = nil
	self.velocityHistory = {}
	self.connections = {}
	self.__vars = table.clone(doorBashingController.__vars)

	task.defer(self.init, self)

	return self
end

function doorBashingController:destroy()
	local connections = self.connections

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return doorBashingController
