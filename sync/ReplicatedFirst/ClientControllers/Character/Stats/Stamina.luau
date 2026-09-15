local players = game:GetService("Players")
local runService = game:GetService("RunService")

local player = players.LocalPlayer
local staminaEffectsController = require(script.Effects)

local staminaController = {}
staminaController.__index = staminaController
staminaController.__vars = {
	drainRatePerSecond = 2.5,
	regenRatePerSecond = 6.5,
	crouchRegenMultiplier = 2,
	injuredDrainMultiplier = 1.5,
	movingRegenMultiplier = 0.85,
	regenDelaySeconds = 1,
	defaultStamina = 100,
	maximumStamina = 100,
	minimumStamina = 0,
	canRegenerate = true,
	isExhausted = false,
	lastDrainTimeSeconds = 0,
}

function staminaController:preload()
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid") or self.character:WaitForChild("Humanoid")
end

function staminaController:applyDefaultAttributes(character: Model)
	local stateValues = self.__vars

	character:SetAttribute("Stamina", stateValues.defaultStamina)
	character:SetAttribute("StaminaMax", stateValues.maximumStamina)
	character:SetAttribute("StaminaMin", stateValues.minimumStamina)
	character:SetAttribute("CanRegen", stateValues.canRegenerate)
	character:SetAttribute("Exhausted", stateValues.isExhausted)
	character:SetAttribute("RegenPaused", false)

	stateValues.lastDrainTimeSeconds = 0
end

function staminaController:bindCharacter(character: Model)
	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")

	self:applyDefaultAttributes(character)

	if self.effects then
		self.effects:bindCharacter(character)
	end
end

function staminaController:update(deltaTime: number)
	local stateValues = self.__vars
	local character = self.character
	local humanoid = self.humanoid
	if character == nil or humanoid == nil then
		return
	end

	if character.Parent == nil or humanoid.Parent == nil then
		return
	end

	local isSprinting = character:GetAttribute("Sprinting") == true and not player:GetAttribute("InMenu")
	local skipRegen = not isSprinting and self.isStaminaIdle

	local currentStamina = character:GetAttribute("Stamina")
	local minimumStamina = character:GetAttribute("StaminaMin")
	local maximumStamina = character:GetAttribute("StaminaMax")
	local canRegenerate = character:GetAttribute("CanRegen")
	local regenerationPaused = character:GetAttribute("RegenPaused")
	local isExhausted = character:GetAttribute("Exhausted")
	local isCrouching = character:GetAttribute("Crouching") == true
	local injuredLevel = character:GetAttribute("Injured") or 0

	if type(currentStamina) ~= "number" then
		currentStamina = stateValues.defaultStamina
	end

	if type(minimumStamina) ~= "number" then
		minimumStamina = stateValues.minimumStamina
	end

	if type(maximumStamina) ~= "number" or maximumStamina <= 0 then
		maximumStamina = stateValues.maximumStamina
	end

	if not canRegenerate then
		character:SetAttribute("CanRegen", true)
		stateValues.lastDrainTimeSeconds = os.clock()
	end

	if isSprinting then
		self.isStaminaIdle = false

		local drainRate = stateValues.drainRatePerSecond
		stateValues.lastDrainTimeSeconds = os.clock()

		if injuredLevel > 0 then
			drainRate *= stateValues.injuredDrainMultiplier
		end

		currentStamina -= drainRate * deltaTime
		if currentStamina <= minimumStamina then
			currentStamina = minimumStamina
			character:SetAttribute("Exhausted", true)
		end
	elseif
		not skipRegen
		and not regenerationPaused
		and os.clock() >= stateValues.lastDrainTimeSeconds + stateValues.regenDelaySeconds
	then
		local regenRate = stateValues.regenRatePerSecond

		if isExhausted then
			regenRate /= 2
		end

		if isCrouching then
			regenRate *= stateValues.crouchRegenMultiplier
		end

		if humanoid.MoveDirection.Magnitude > 0.05 then
			regenRate *= stateValues.movingRegenMultiplier
		end

		currentStamina += regenRate * deltaTime
		if currentStamina >= maximumStamina then
			currentStamina = maximumStamina
		end
	end

	if isExhausted and currentStamina > minimumStamina + 25 then
		character:SetAttribute("Exhausted", false)
	end

	character:SetAttribute("Stamina", math.clamp(currentStamina, minimumStamina, maximumStamina))

	--// Mark idle when stamina is at max and not exhausted, so future frames can skip.
	self.isStaminaIdle = currentStamina >= maximumStamina and not isExhausted
end

function staminaController:init()
	self:preload()

	self.effects = staminaEffectsController.new(self)
	self:bindCharacter(self.character)

	self.connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:bindCharacter(character)
	end)

	runService:UnbindFromRenderStep("StaminaClient")
	runService:BindToRenderStep("StaminaClient", Enum.RenderPriority.Character.Value, function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function staminaController.new()
	local self = setmetatable({}, staminaController)

	self.connections = {}
	self.__vars = table.clone(staminaController.__vars)
	self.character = nil
	self.humanoid = nil
	self.effects = nil
	self.isStaminaIdle = false

	task.defer(self.init, self)

	return self
end

function staminaController:destroy()
	local connections = self.connections
	local effects = self.effects

	runService:UnbindFromRenderStep("StaminaClient")

	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	if effects then
		effects:destroy()
		self.effects = nil
	end

	table.clear(connections)
	setmetatable(self, nil)
end

return staminaController
