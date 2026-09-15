local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local legController = require(replicatedStorage.SharedClasses.LegController)

local player = players.LocalPlayer
local kinematicController = {}
kinematicController.__index = kinematicController
kinematicController.__vars = {
	maximumIkVelocity = 1.5,
	activationVelocity = 1.5,
	maximumRootAngle = 20,
	maximumAngle = 18,
	interpolationHighVelocityPoint = 2.5,
	interpolationSpeed = 0.3,
}

function kinematicController:preload()
	self.character = player.Character or player.CharacterAdded:Wait()
end

function kinematicController:createLegController(character: Model)
	local stateValues = self.__vars

	if self.controller ~= nil then
		self.controller:destroy()
		self.controller = nil
	end

	self.character = character
	self.controller = legController.new(character, {
		ikEnabled = true,
		ikExclude = {},
		onStates = {
			Enum.HumanoidStateType.Running,
		},
		maxIkVelocity = stateValues.maximumIkVelocity,
		activationVelocity = stateValues.activationVelocity,
		maxRootAngle = stateValues.maximumRootAngle,
		maxAngle = stateValues.maximumAngle,
		interpolationSpeed = {
			highVelocityPoint = stateValues.interpolationHighVelocityPoint,
			Speed = stateValues.interpolationSpeed,
		},
	})
end

function kinematicController:init()
	self:preload()
	self:createLegController(self.character)
	self.connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:createLegController(character)
	end)
end

function kinematicController.new()
	local self = setmetatable({}, kinematicController)

	self.connections = {}
	self.__vars = table.clone(kinematicController.__vars)
	self.character = nil
	self.controller = nil

	task.defer(self.init, self)

	return self
end

function kinematicController:destroy()
	if self.controller ~= nil then
		self.controller:destroy()
		self.controller = nil
	end

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	table.clear(self.connections)
	setmetatable(self, nil)
end

return kinematicController
