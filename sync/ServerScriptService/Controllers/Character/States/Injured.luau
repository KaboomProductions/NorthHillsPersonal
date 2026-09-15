local injuredController = {}
injuredController.__index = injuredController
injuredController.__vars = {
	currentLevel = 0,
	healthyThresholdPercent = 40,
	lightInjuryThresholdPercent = 20,
	heavyInjuryThresholdPercent = 10,
}

local function getHealthPercent(humanoid: Humanoid): number
	local maximumHealth = humanoid.MaxHealth
	if maximumHealth <= 0 then
		return 0
	end

	local currentHealth = math.clamp(humanoid.Health, 0, maximumHealth)
	return (currentHealth / maximumHealth) * 100
end

function injuredController:calculateLevel(healthPercent: number): number
	local stateValues = self.__vars

	if healthPercent >= stateValues.healthyThresholdPercent then
		return 0
	elseif healthPercent >= stateValues.lightInjuryThresholdPercent then
		return 1
	elseif healthPercent >= stateValues.heavyInjuryThresholdPercent then
		return 2
	else
		return 3
	end
end

function injuredController:setLevel(level: number)
	local stateValues = self.__vars

	if stateValues.currentLevel == level then
		return
	end

	stateValues.currentLevel = level
	self.character:SetAttribute("Injured", level)
end

function injuredController:update()
	local humanoid = self.humanoid
	if not humanoid or humanoid.Parent == nil then
		return
	end

	local healthPercent = getHealthPercent(humanoid)
	local level = self:calculateLevel(healthPercent)
	self:setLevel(level)
end

function injuredController:bindHumanoid(humanoid: Humanoid)
	local connections = self.connections

	self.humanoid = humanoid

	connections.healthChanged = humanoid.HealthChanged:Connect(function()
		self:update()
	end)

	connections.humanoidAncestryChanged = humanoid.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			self.humanoid = nil
		end
	end)

	self:update()
end

function injuredController:init()
	local character = self.character
	local stateValues = self.__vars
	local connections = self.connections

	if character:GetAttribute("Injured") == nil then
		character:SetAttribute("Injured", 0)
	end

	stateValues.currentLevel = tonumber(character:GetAttribute("Injured")) or 0

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self:bindHumanoid(humanoid)
	else
		connections.humanoidAdded = character.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				connections.humanoidAdded:Disconnect()
				connections.humanoidAdded = nil
				self:bindHumanoid(child)
			end
		end)
	end
end

function injuredController.new(player: Player, character: Model)
	local self = setmetatable({}, injuredController)

	self.player = player
	self.character = character
	self.humanoid = nil
	self.connections = {}
	self.__vars = table.clone(injuredController.__vars)

	task.defer(self.init, self)

	return self
end

function injuredController:destroy()
	local connections = self.connections

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return injuredController
