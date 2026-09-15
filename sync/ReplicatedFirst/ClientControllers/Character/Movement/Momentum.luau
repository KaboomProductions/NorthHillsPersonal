local players = game:GetService("Players")
local runService = game:GetService("RunService")

local player = players.LocalPlayer
local momentumController = {}
momentumController.__index = momentumController
momentumController.__vars = {
	acceleration = 5,
	deceleration = 8,
	reverseAcceleration = 10,
	epsilon = 0.001,
	inputDirection = Vector3.zero,
	moveDirection = Vector3.zero,
}

local function normalizeDirection(direction: Vector3, epsilon: number): Vector3
	if direction.Magnitude > 1 then
		return direction.Unit
	end

	if direction.Magnitude <= epsilon then
		return Vector3.zero
	end

	return direction
end

local function moveTowards(
	currentDirection: Vector3,
	targetDirection: Vector3,
	maxChange: number,
	epsilon: number
): Vector3
	local directionOffset = targetDirection - currentDirection
	local offsetMagnitude = directionOffset.Magnitude

	if offsetMagnitude <= epsilon or offsetMagnitude <= maxChange then
		return targetDirection
	end

	return currentDirection + directionOffset.Unit * maxChange
end

function momentumController:preload()
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid") or self.character:WaitForChild("Humanoid")
end

function momentumController:onCharacterAdded(character: Model)
	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	self.__vars.inputDirection = Vector3.zero
	self.__vars.moveDirection = Vector3.zero
end

function momentumController:setInputDirection(inputDirection: Vector3)
	local stateValues = self.__vars

	stateValues.inputDirection = normalizeDirection(inputDirection, stateValues.epsilon)
end

function momentumController:update(deltaTime: number)
	local stateValues = self.__vars
	local humanoid = self.humanoid
	if humanoid == nil or humanoid.Parent == nil then
		return
	end

	local moveVelocity = humanoid.WalkSpeed > stateValues.epsilon and (humanoid:GetMoveVelocity() / humanoid.WalkSpeed)
		or Vector3.zero
	self:setInputDirection(moveVelocity)

	local currentMoveDirection = stateValues.moveDirection
	local desiredInputDirection = stateValues.inputDirection
	local isTryingToMove = desiredInputDirection.Magnitude > stateValues.epsilon
	local isReversingDirection = isTryingToMove
		and currentMoveDirection.Magnitude > stateValues.epsilon
		and currentMoveDirection:Dot(desiredInputDirection) < 0
	local directionOffsetMagnitude = (desiredInputDirection - currentMoveDirection).Magnitude

	if directionOffsetMagnitude > stateValues.epsilon then
		local acceleration = stateValues.acceleration

		if not isTryingToMove then
			acceleration = stateValues.deceleration
		elseif isReversingDirection then
			acceleration = stateValues.reverseAcceleration
		end

		stateValues.moveDirection =
			moveTowards(currentMoveDirection, desiredInputDirection, acceleration * deltaTime, stateValues.epsilon)
	end

	if stateValues.moveDirection.Magnitude <= stateValues.epsilon then
		stateValues.moveDirection = Vector3.zero
	end

	humanoid:Move(stateValues.moveDirection)
end

function momentumController:init()
	self:preload()

	self.connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:onCharacterAdded(character)
	end)

	runService:UnbindFromRenderStep("MomentumClient")
	runService:BindToRenderStep("MomentumClient", Enum.RenderPriority.Character.Value + 1, function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function momentumController.new()
	local self = setmetatable({}, momentumController)

	self.connections = {}
	self.__vars = table.clone(momentumController.__vars)
	self.character = nil
	self.humanoid = nil

	task.defer(self.init, self)

	return self
end

function momentumController:destroy()
	local connections = self.connections

	runService:UnbindFromRenderStep("MomentumClient")

	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	table.clear(connections)
	setmetatable(self, nil)
end

return momentumController
