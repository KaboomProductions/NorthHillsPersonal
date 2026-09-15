local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local clientData = require(replicatedFirst.ClientData)
local movementAnimationController = require(replicatedFirst.ClientControllers.Character.Core.Animation)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local config = require(script.Config)

local player = players.LocalPlayer
local tau = 2 * math.pi
local identityCFrame = CFrame.identity
local aimingMotionScale = 0.25

local headBobController = {}
headBobController.__index = headBobController
headBobController.__vars = {
	currentAmplitude = 0,
	smoothedVertical = 0,
	smoothedLateral = 0,
	smoothedPitch = 0,
	smoothedYaw = 0,
	smoothedRoll = 0,
	startTime = 0,
}

local function getMovementPhase(animator: Animator): number?
	local animationController = movementAnimationController.getActiveController()
	if animationController == nil or animationController.animator ~= animator then
		return nil
	end

	return animationController:getMovementCyclePhase()
end

function headBobController:cacheCharacter()
	local character = player.Character
	if character == nil then
		self.character = nil
		self.humanoid = nil
		self.animator = nil
		return
	end

	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid")

	if self.humanoid then
		self.animator = self.humanoid:FindFirstChildOfClass("Animator")
	end
end

function headBobController:computeOffset(deltaTime: number): CFrame
	local stateValues = self.__vars

	local character = self.character
	local humanoid = self.humanoid
	local animator = self.animator

	if character == nil or humanoid == nil or animator == nil then
		return identityCFrame
	end

	local isFirstPerson = character:GetAttribute("FirstPerson") == true
	local isThirdPerson = not isFirstPerson
	local isMoving = humanoid.MoveDirection.Magnitude > config.moveThreshold
	local isCameraLocked = clientData.isCameraLocked()
	local targetAmplitude = 0

	if isMoving and not isCameraLocked then
		targetAmplitude = isFirstPerson and 1 or config.thirdPersonAmplitudeScale
	end

	stateValues.currentAmplitude = mathUtilities.exponentialLerp(
		stateValues.currentAmplitude,
		targetAmplitude,
		config.amplitudeSmoothSpeed,
		deltaTime
	)

	local phase = getMovementPhase(animator)
	local elapsed = os.clock() - stateValues.startTime
	local movementWeight = stateValues.currentAmplitude
	local idleWeight = (isFirstPerson and not isCameraLocked) and (1 - movementWeight) or 0

	--// Idle breathing — fades out as movement fades in
	local targetVertical = math.sin(elapsed * config.idleVerticalFrequency * tau)
		* config.idleVerticalAmplitude
		* idleWeight
	local targetLateral = math.sin(elapsed * config.idleLateralFrequency * tau)
		* config.idleLateralAmplitude
		* idleWeight
	local targetRoll = 0
	local targetPitch =
		math.rad(math.sin(elapsed * config.idlePitchFrequency * tau) * config.idlePitchAmplitude * idleWeight)
	local targetYaw = math.rad(math.sin(elapsed * config.idleYawFrequency * tau) * config.idleYawAmplitude * idleWeight)

	--// Movement bob — additively blended on top of idle
	if phase ~= nil and movementWeight > 0.0001 then
		local speedScale = humanoid.WalkSpeed / config.referenceWalkSpeed
		local amplitude = movementWeight * speedScale
		local rotationScale = isThirdPerson and config.thirdPersonRotationScale or 1

		local stepPhase = phase * tau * config.stepsPerCycle
		local cyclePhase = phase * tau

		targetVertical += -math.cos(stepPhase) * config.verticalAmplitude * amplitude
		targetLateral += math.sin(cyclePhase) * config.lateralAmplitude * amplitude
		targetRoll += math.rad(math.sin(cyclePhase) * config.rollAmplitude * amplitude * rotationScale)
		targetPitch += math.rad(-math.cos(stepPhase) * config.pitchAmplitude * amplitude * rotationScale)
		targetYaw += math.rad(math.sin(cyclePhase) * config.yawAmplitude * amplitude * rotationScale)
	end

	local motionScale = clientData.isAiming and aimingMotionScale or 1
	targetVertical *= motionScale
	targetLateral *= motionScale
	targetRoll *= motionScale
	targetPitch *= motionScale
	targetYaw *= motionScale

	--// Always smooth toward the target — when stopping this gracefully
	--// decays to zero instead of snapping to identity.
	local smoothAlpha = mathUtilities.exponentialAlpha(config.offsetSmoothSpeed, deltaTime)

	stateValues.smoothedVertical += (targetVertical - stateValues.smoothedVertical) * smoothAlpha
	stateValues.smoothedLateral += (targetLateral - stateValues.smoothedLateral) * smoothAlpha
	stateValues.smoothedRoll += (targetRoll - stateValues.smoothedRoll) * smoothAlpha
	stateValues.smoothedPitch += (targetPitch - stateValues.smoothedPitch) * smoothAlpha
	stateValues.smoothedYaw += (targetYaw - stateValues.smoothedYaw) * smoothAlpha

	--// Skip building a CFrame when all values are near zero
	local totalMagnitude = math.abs(stateValues.smoothedVertical)
		+ math.abs(stateValues.smoothedLateral)
		+ math.abs(stateValues.smoothedRoll)
		+ math.abs(stateValues.smoothedPitch)
		+ math.abs(stateValues.smoothedYaw)

	if totalMagnitude < 0.0001 then
		return identityCFrame
	end

	return CFrame.new(stateValues.smoothedLateral, stateValues.smoothedVertical, 0)
		* CFrame.Angles(stateValues.smoothedPitch, stateValues.smoothedYaw, stateValues.smoothedRoll)
end

function headBobController:onCharacterAdded()
	self:cacheCharacter()
end

function headBobController:init()
	self:cacheCharacter()
	self.__vars.startTime = os.clock()

	self.connections.characterAdded = player.CharacterAdded:Connect(function()
		self:onCharacterAdded()
	end)
end

function headBobController.new()
	local self = setmetatable({}, headBobController)

	self.config = config
	self.connections = {}
	self.__vars = table.clone(headBobController.__vars)
	self.character = nil
	self.humanoid = nil
	self.animator = nil

	task.defer(self.init, self)

	return self
end

function headBobController:destroy()
	local connections = self.connections
	for connectionName, connection in pairs(connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end

		connections[connectionName] = nil
	end

	self.__vars = nil
	self.config = nil
	setmetatable(self, nil)
end

return headBobController
