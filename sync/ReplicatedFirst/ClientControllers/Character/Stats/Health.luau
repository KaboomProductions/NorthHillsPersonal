local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")

local healthEffectsController = require(script.Effects)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)

local player = players.LocalPlayer

local healthController = {}
healthController.__index = healthController
healthController.__vars = {
	previousHealth = 0,
}

function healthController:preload()
	self.character = player.Character or player.CharacterAdded:Wait()
end

function healthController:onHealthChanged(currentHealth: number)
	local stateValues = self.__vars
	local damageAmount = stateValues.previousHealth - currentHealth
	stateValues.previousHealth = currentHealth

	if damageAmount <= 0 then
		return
	end

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playDamage(damageAmount, self.humanoid.MaxHealth)
	end
end

function healthController:bindCharacter(character: Model)
	local connections = self.connections
	local healthChangedConnection = connections.healthChanged

	if healthChangedConnection then
		healthChangedConnection:Disconnect()
	end

	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	self.__vars.previousHealth = self.humanoid.Health
	connections.healthChanged = self.humanoid.HealthChanged:Connect(function(currentHealth: number)
		self:onHealthChanged(currentHealth)
	end)
end

function healthController:init()
	self:preload()
	self:bindCharacter(self.character)
	self.effects = healthEffectsController.new(self)
	self.connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:bindCharacter(character)
	end)
end

function healthController.new()
	local self = setmetatable({}, healthController)

	self.connections = {}
	self.__vars = table.clone(healthController.__vars)
	self.character = nil
	self.humanoid = nil
	self.effects = nil

	task.defer(self.init, self)

	return self
end

function healthController:destroy()
	local connections = self.connections

	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	if self.effects then
		self.effects:destroy()
		self.effects = nil
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return healthController
