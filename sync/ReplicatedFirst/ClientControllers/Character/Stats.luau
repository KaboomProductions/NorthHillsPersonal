local statsController = {}
statsController.__index = statsController
statsController.__vars = {
	combatTimeout = 10,
}

local replicatedFirst = game:GetService("ReplicatedFirst")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local player = players.LocalPlayer

local moduleLoader = require(replicatedFirst.ClientUtilities.ModuleLoader)

function statsController:preload()
	self.character = player.Character or player.CharacterAdded:Wait()
	self.controllers = moduleLoader.startModules(script)

	self.lastCombatTime = -math.huge
end

function statsController:init()
	self:preload()

	self.connections.update = runService.RenderStepped:Connect(function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function statsController.new()
	local self = setmetatable({}, statsController)

	self.__vars = table.clone(statsController.__vars)
	self.connections = {}
	self.controllers = {}

	task.defer(self.init, self)

	return self
end

function statsController:update(_deltaTime: number)
	local combatState = self.character:GetAttribute("Combat")
	local lastCombatTime = self.character:GetAttribute("LastCombatTime") or -math.huge

	if combatState then
		local timeSinceCombat = os.clock() - lastCombatTime

		if timeSinceCombat >= self.__vars.combatTimeout then
			self.character:SetAttribute("Combat", false)
		end
	end

	self.inCombat = self.character:GetAttribute("Combat") or false
end

function statsController:destroy()
	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	table.clear(self.connections)
	moduleLoader.destroyModules(self.controllers)

	setmetatable(self, nil)
end

return statsController
