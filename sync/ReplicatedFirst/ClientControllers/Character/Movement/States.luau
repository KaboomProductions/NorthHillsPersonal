local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local clientConfig = require(replicatedFirst.ClientData.ClientConfig)
local clientData = require(replicatedFirst.ClientData)
local inputBindings = require(replicatedFirst.ClientUtilities.InputBindings)
local keybinds = require(replicatedStorage.SharedAssets.Keybinds)
local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)

local StateMachine = require(script.StateMachine)
local sprintingState = require(script.Sprinting)
local crouchingState = require(script.Crouching)
local injuredState = require(script.Injured)

local player = players.LocalPlayer

local playerGui = player.PlayerGui:WaitForChild("Interface", 3)
local mobileFrame = playerGui.Mobile

local settingsConfig = player:WaitForChild("Settings", 3)
local sprintInputMode = settingsConfig.Gameplay:WaitForChild("Sprint Input Mode", 1)
local crouchInputMode = settingsConfig.Gameplay:WaitForChild("Crouch Input Mode", 1)

local speedPresets = clientConfig.movement.speedPresets

local stateController = {}
stateController.__index = stateController
stateController.__vars = {
	--// sprinting
	movementThreshold = 0.5,
	strafeSprintMultiplier = 0.7,
	backwardSprintMultiplier = 0.3,
	sprintFieldOfViewOffset = 5,
	forwardVelocity = 0,
	rightVelocity = 0,

	--// crouching
	crouchSpeed = speedPresets.crouching - speedPresets.walking,
	crouchFieldOfViewOffset = -5,
	vignetteVisibleTransparency = 0.55,
	vignetteHiddenTransparency = 1,
	vignetteFadeSpeed = 2,
}

function stateController:preload()
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid") or self.character:WaitForChild("Humanoid")
	self.rootPart = self.humanoid.RootPart or self.character:WaitForChild("HumanoidRootPart")

	crouchingState.preload(self)
end

function stateController:bindCharacter(character: Model)
	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	self.rootPart = self.humanoid.RootPart or character:WaitForChild("HumanoidRootPart")

	character:SetAttribute("Sprinting", false)
	character:SetAttribute("HoldingSprint", false)
	character:SetAttribute("Crouching", false)

	if character:GetAttribute("Injured") == nil then
		character:SetAttribute("Injured", 0)
	end

	self.stateMachine:reset()

	connectionUtilities.disconnectConnection(self.connections.injuredChanged)
	connectionUtilities.disconnectConnection(self.connections.exhaustedChanged)
	connectionUtilities.disconnectConnection(self.connections.staminaChanged)

	self.connections.menuChanged = player:GetAttributeChangedSignal("InMenu"):Connect(function()
		self:evaluateState()
	end)
	self.connections.injuredChanged = character:GetAttributeChangedSignal("Injured"):Connect(function()
		injuredState.onInjuredChanged(self)
		self:evaluateState()
	end)
	self.connections.exhaustedChanged = character:GetAttributeChangedSignal("Exhausted"):Connect(function()
		self:evaluateState()
	end)
	self.connections.staminaChanged = character:GetAttributeChangedSignal("Stamina"):Connect(function()
		self:evaluateState()
	end)

	injuredState.onInjuredChanged(self)
	crouchingState.preload(self)

	self:syncHeldInputs()
	self:evaluateState()
end

function stateController:syncHeldInputs()
	local character = self.character
	if character == nil then
		return
	end

	if sprintInputMode.Value == "Toggle" then
		character:SetAttribute("HoldingSprint", false)
		return
	end

	local isHeld = self.sprintBind ~= nil and self.sprintBind:GetState() == true and not inputBindings.isTextFocused()
	character:SetAttribute("HoldingSprint", isHeld)
end

function stateController:getMovementDirection(): string?
	local stateValues = self.__vars
	local humanoid = self.humanoid
	local threshold = stateValues.movementThreshold
	local forwardVelocity = stateValues.forwardVelocity
	local rightVelocity = stateValues.rightVelocity

	if humanoid == nil or humanoid.MoveDirection.Magnitude <= 0 then
		return nil
	end

	if math.abs(forwardVelocity) < threshold and math.abs(rightVelocity) < threshold then
		return nil
	end

	local movementDirection = ""

	if -forwardVelocity > threshold then
		movementDirection = "forward"
	elseif forwardVelocity > threshold then
		movementDirection = "backward"
	end

	if -rightVelocity > threshold then
		movementDirection = movementDirection ~= "" and (movementDirection .. "Left") or "left"
	elseif rightVelocity > threshold then
		movementDirection = movementDirection ~= "" and (movementDirection .. "Right") or "right"
	end

	return movementDirection ~= "" and movementDirection or nil
end

function stateController:evaluateState()
	self.stateMachine:evaluate()

	local character = self.character
	if character == nil then
		return
	end

	local currentStateName = not player:GetAttribute("InMenu") and self.stateMachine:getCurrentStateName() or "None"
	character:SetAttribute("Sprinting", currentStateName == "Sprinting")
	character:SetAttribute("Crouching", currentStateName == "Crouching")
end

function stateController:onSprintInputStateChanged(active: Vector2 | Vector3 | boolean | number, pressed: boolean)
	if not self.character then
		return
	end

	if sprintInputMode.Value == "Toggle" then
		if pressed then
			local currentlySprinting = self.character:GetAttribute("HoldingSprint") == true
			self.character:SetAttribute("HoldingSprint", not currentlySprinting)

			self.wantsCrouch = false

			self:evaluateState()
		end

		return
	end

	self.character:SetAttribute("HoldingSprint", active == true)

	if active == true then
		self.wantsCrouch = false
	end

	self:evaluateState()
end

function stateController:onCrouchInputStateChanged(active: Vector2 | Vector3 | boolean | number, pressed: boolean)
	if not self.character then
		return
	end

	if self.stateMachine:getCurrentStateName() == "Sprinting" then
		return
	end

	if crouchInputMode.Value == "Toggle" then
		if not pressed then
			return
		end

		self.wantsCrouch = not self.wantsCrouch
	else
		self.wantsCrouch = active == true
	end

	self:evaluateState()
end

function stateController:update(deltaTime: number)
	local character = self.character
	local rootPart = self.rootPart
	local stateValues = self.__vars

	if not self.character or not self.rootPart or not self.rootPart.Parent then
		return
	end

	if character:GetAttribute("HoldingSprint") == true then
		local velocity = rootPart.AssemblyLinearVelocity
		local relativeVelocity = rootPart.CFrame:VectorToObjectSpace(velocity)

		stateValues.forwardVelocity = relativeVelocity.Z
		stateValues.rightVelocity = relativeVelocity.X

		self:evaluateState()
	end

	crouchingState.updateEffects(self, deltaTime)

	self.stateMachine:update(deltaTime)
end

function stateController:init()
	self:preload()

	local stateMachine = StateMachine.new()
	stateMachine:setController(self)
	stateMachine:addState(sprintingState.createState(self))
	stateMachine:addState(crouchingState.createState(self))
	stateMachine:addState(injuredState.createState(self))

	stateMachine:addState({
		name = "Idle",
		priority = 0,
		canEnter = function()
			return true
		end,
		enter = function()
			clientData.speedModifiers.sprinting = 0
			clientData.fieldOfViewModifiers.sprinting = 0

			clientData.speedModifiers.crouching = 0
			clientData.fieldOfViewModifiers.crouching = 0

			crouchingState.applyCrouchEffects(self, false)
		end,
	})

	self.stateMachine = stateMachine

	self.sprintBind = inputBindings.create(keybinds.sprint, {
		button = mobileFrame.Sprint,
		mobileName = "Sprint",
	})
	self.crouchBind = inputBindings.create(keybinds.crouch, {
		button = mobileFrame.Crouch,
		mobileName = "Crouch",
	})

	self:bindCharacter(self.character)

	self.connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:bindCharacter(character)
	end)

	runService:UnbindFromRenderStep("MovementStates")
	runService:UnbindFromRenderStep("SprintClient")

	runService:BindToRenderStep("MovementStates", Enum.RenderPriority.Character.Value, function(deltaTime: number)
		self:update(deltaTime)
	end)

	self.connections.onSprintBind = inputBindings.connect(
		self.sprintBind,
		function(active: Vector2 | Vector3 | boolean | number, pressed: boolean?)
			self:onSprintInputStateChanged(active, pressed)
		end
	)

	self.connections.onCrouchBind = inputBindings.connect(
		self.crouchBind,
		function(active: Vector2 | Vector3 | boolean | number, pressed: boolean?)
			self:onCrouchInputStateChanged(active, pressed)
		end
	)
end

function stateController.new()
	local self = setmetatable({}, stateController)

	self.connections = {}
	self.__vars = table.clone(stateController.__vars)
	self.character = nil
	self.humanoid = nil
	self.rootPart = nil
	self.stateMachine = nil
	self.wantsCrouch = false

	self.vignette = nil
	self.currentVignetteTransparency = self.__vars.vignetteHiddenTransparency
	self.targetVignetteTransparency = self.__vars.vignetteHiddenTransparency

	task.defer(self.init, self)

	return self
end

function stateController:destroy()
	runService:UnbindFromRenderStep("MovementStates")
	if self.sprintBind then
		self.sprintBind:Destroy()
		self.sprintBind = nil
	end

	if self.crouchBind then
		self.crouchBind:Destroy()
		self.crouchBind = nil
	end

	if self.stateMachine then
		self.stateMachine:destroy()
	end

	clientData.speedModifiers.sprinting = nil
	clientData.fieldOfViewModifiers.sprinting = nil
	clientData.speedModifiers.crouching = nil
	clientData.fieldOfViewModifiers.crouching = nil
	clientData.speedModifiers.injured = nil
	clientData.fieldOfViewModifiers.injured = nil

	crouchingState.destroyEffects(self)

	connectionUtilities.disconnectConnections(self.connections)
	table.clear(self.connections)
	setmetatable(self, nil)
end

return stateController
