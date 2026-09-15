local doorAttackerController = {}
doorAttackerController.__index = doorAttackerController

local serverScriptService = game:GetService("ServerScriptService")

local systems = serverScriptService.Systems
local interactablesController = systems.Interactables
local doorsController = require(interactablesController.Doors)

function doorAttackerController.new(ancestorInfo)
	local self = setmetatable({}, doorAttackerController)

	self.ancestor = ancestorInfo
	self.connections = self.ancestor.connections
	self.sharedConfig = self.ancestor.sharedConfig
	self.combatConfig = self.ancestor.combatConfig

	self.backhandTracks = self.ancestor.backhandTracks

	self.controller = self.ancestor.controller
	self.agent = self.ancestor.agent
	self.rootPart = self.ancestor.rootPart

	self.availableDoors = doorsController.activeDoors

	return self
end

function doorAttackerController:openDoor(controller)
	local newBackhandTrack = self.backhandTracks[math.random(1, #self.backhandTracks)]
	newBackhandTrack:Play(0, 1, 2)

	controller:setState(self.rootPart, true, nil, nil, false)
end

function doorAttackerController:performDoorCheck()
	for _, controller in self.availableDoors do
		local instance = controller.instance
		local isOpen = controller.attributes.Open

		local mainPivot = instance:GetPivot()
		local distanceToPivot = vector.magnitude(self.rootPart.Position - mainPivot.Position)

		if distanceToPivot <= self.sharedConfig.ranges.attack and not isOpen then
			self:openDoor(controller)
		end
	end
end

function doorAttackerController:update(_deltaTime: number)
	if self.controller:canSideAttack() then
		self:performDoorCheck()
	end
end

function doorAttackerController:destroy()
	setmetatable(self, nil)
end

return doorAttackerController
