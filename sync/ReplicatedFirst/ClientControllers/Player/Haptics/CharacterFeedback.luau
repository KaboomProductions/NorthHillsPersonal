local players = game:GetService("Players")

local hapticConfig = require(script.Parent.Config)
local waveformUtilities = require(script.Parent.WaveformUtils)

local player = players.LocalPlayer

local characterFeedback = {}
characterFeedback.__index = characterFeedback
characterFeedback.__vars = {
	wasSprinting = false,
	wasCrouching = false,
	wasStaminaDepleted = false,
}

export type FeedbackCallbacks = {
	setLowHealthUrgency: (number) -> (),
	clearLowHealth: () -> (),
	setLowStaminaUrgency: (number) -> (),
	clearLowStamina: () -> (),
	playMovementTransition: ("sprint" | "crouch") -> (),
	playStaminaDepleted: () -> (),
}

function characterFeedback:updateHealth()
	local humanoid = self.humanoid
	if humanoid == nil or humanoid.Parent == nil then
		self.callbacks.clearLowHealth()
		return
	end

	local currentHealth = humanoid.Health
	if currentHealth >= hapticConfig.health.activationHealth then
		self.callbacks.clearLowHealth()
		return
	end

	self.callbacks.setLowHealthUrgency(waveformUtilities.calculateLowHealthUrgency(currentHealth))
end

function characterFeedback:getStaminaValues(): (number?, number?, number?)
	local character = self.character
	if character == nil or character.Parent == nil then
		return nil, nil, nil
	end

	local currentStamina = character:GetAttribute("Stamina")
	local maximumStamina = character:GetAttribute("StaminaMax")
	local minimumStamina = character:GetAttribute("StaminaMin")
	if type(currentStamina) ~= "number" or type(maximumStamina) ~= "number" or maximumStamina <= 0 then
		return nil, nil, nil
	end

	minimumStamina = if type(minimumStamina) == "number" then minimumStamina else 0
	return currentStamina, maximumStamina, minimumStamina
end

function characterFeedback:updateStaminaDepletion(currentStamina: number, minimumStamina: number)
	local stateValues = self.__vars
	local isStaminaDepleted = currentStamina <= minimumStamina
	if isStaminaDepleted and not stateValues.wasStaminaDepleted then
		self.callbacks.playStaminaDepleted()
	end

	stateValues.wasStaminaDepleted = isStaminaDepleted
end

function characterFeedback:updateLowStamina(currentStamina: number, maximumStamina: number)
	if currentStamina / maximumStamina >= hapticConfig.stamina.activationFraction then
		self.callbacks.clearLowStamina()
		return
	end

	self.callbacks.setLowStaminaUrgency(
		waveformUtilities.calculateLowStaminaUrgency(currentStamina, maximumStamina)
	)
end

function characterFeedback:updateStamina()
	local currentStamina, maximumStamina, minimumStamina = self:getStaminaValues()
	if currentStamina == nil or maximumStamina == nil or minimumStamina == nil then
		self.__vars.wasStaminaDepleted = false
		self.callbacks.clearLowStamina()
		return
	end

	self:updateStaminaDepletion(currentStamina, minimumStamina)
	self:updateLowStamina(currentStamina, maximumStamina)
end

function characterFeedback:onSprintingChanged()
	local character = self.character
	local stateValues = self.__vars
	local isSprinting = character ~= nil and character:GetAttribute("Sprinting") == true

	if isSprinting and not stateValues.wasSprinting then
		self.callbacks.playMovementTransition("sprint")
	end

	stateValues.wasSprinting = isSprinting
end

function characterFeedback:onCrouchingChanged()
	local character = self.character
	local stateValues = self.__vars
	local isCrouching = character ~= nil and character:GetAttribute("Crouching") == true

	if isCrouching and not stateValues.wasCrouching then
		self.callbacks.playMovementTransition("crouch")
	end

	stateValues.wasCrouching = isCrouching
end

function characterFeedback:disconnectCharacterSignals()
	local characterConnections = self.characterConnections

	for connectionName, connection in pairs(characterConnections) do
		connection:Disconnect()
		characterConnections[connectionName] = nil
	end
end

function characterFeedback:cacheCharacter(character: Model)
	local stateValues = self.__vars
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	self.character = character
	self.humanoid = humanoid
	stateValues.wasSprinting = character:GetAttribute("Sprinting") == true
	stateValues.wasCrouching = character:GetAttribute("Crouching") == true
	stateValues.wasStaminaDepleted = false
end

function characterFeedback:connectCharacterSignals()
	local character = self.character
	local humanoid = self.humanoid
	local characterConnections = self.characterConnections
	characterConnections.healthChanged = humanoid.HealthChanged:Connect(function()
		self:updateHealth()
	end)
	characterConnections.staminaChanged = character:GetAttributeChangedSignal("Stamina"):Connect(function()
		self:updateStamina()
	end)
	characterConnections.staminaMaximumChanged = character:GetAttributeChangedSignal("StaminaMax"):Connect(function()
		self:updateStamina()
	end)
	characterConnections.staminaMinimumChanged = character:GetAttributeChangedSignal("StaminaMin"):Connect(function()
		self:updateStamina()
	end)
	characterConnections.sprintingChanged = character:GetAttributeChangedSignal("Sprinting"):Connect(function()
		self:onSprintingChanged()
	end)
	characterConnections.crouchingChanged = character:GetAttributeChangedSignal("Crouching"):Connect(function()
		self:onCrouchingChanged()
	end)
end

function characterFeedback:bindCharacter(character: Model)
	self:disconnectCharacterSignals()
	self:cacheCharacter(character)
	self:connectCharacterSignals()

	self:updateHealth()
	self:updateStamina()
end

function characterFeedback:clearCharacter(character: Model)
	if self.character ~= character then
		return
	end

	local stateValues = self.__vars
	self:disconnectCharacterSignals()
	self.character = nil
	self.humanoid = nil
	stateValues.wasSprinting = false
	stateValues.wasCrouching = false
	stateValues.wasStaminaDepleted = false
	self.callbacks.clearLowHealth()
	self.callbacks.clearLowStamina()
end

function characterFeedback:init()
	local connections = self.connections
	connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:bindCharacter(character)
	end)
	connections.characterRemoving = player.CharacterRemoving:Connect(function(character: Model)
		self:clearCharacter(character)
	end)

	if player.Character then
		self:bindCharacter(player.Character)
	end
end

function characterFeedback.new(feedbackCallbacks: FeedbackCallbacks)
	local self = setmetatable({}, characterFeedback)

	self.callbacks = feedbackCallbacks
	self.connections = {}
	self.characterConnections = {}
	self.__vars = table.clone(characterFeedback.__vars)
	self.character = nil
	self.humanoid = nil

	task.defer(self.init, self)

	return self
end

function characterFeedback:destroy()
	local connections = self.connections

	self:disconnectCharacterSignals()
	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	table.clear(self.characterConnections)
	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return characterFeedback
