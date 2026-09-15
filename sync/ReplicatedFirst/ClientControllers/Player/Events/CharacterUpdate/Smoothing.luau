local replicatedStorage = game:GetService("ReplicatedStorage")

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local smoothing = {}

local function findMotor(character: Model, motorName: string): Motor6D?
	if motorName == "RootJoint" then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			local rootJoint = rootPart:FindFirstChild("RootJoint")
			if rootJoint and rootJoint:IsA("Motor6D") then
				return rootJoint
			end
		end

		return nil
	end

	local torso = character:FindFirstChild("Torso")
	if torso then
		local motor = torso:FindFirstChild(motorName)
		if motor and motor:IsA("Motor6D") then
			return motor
		end
	end

	--// Fallback for non-standard rigs.
	local motor = character:FindFirstChild(motorName, true)
	if motor and motor:IsA("Motor6D") then
		return motor
	end

	return nil
end

local function getCachedMotor(playerState, character: Model, motorName: string): Motor6D?
	local cachedMotors = playerState.cachedMotors
	local cachedMotor = cachedMotors[motorName]

	if cachedMotor ~= nil and cachedMotor.Parent ~= nil then
		return cachedMotor
	end

	local motor = findMotor(character, motorName)
	cachedMotors[motorName] = motor

	return motor
end

function smoothing.setMotorTarget(playerState, motorName: string, motor: Motor6D?, targetC0: CFrame?)
	if motor == nil or targetC0 == nil then
		return
	end

	local motorTargetState = playerState.motorTargets[motorName]
	if motorTargetState == nil then
		motorTargetState = {
			motor = motor,
			targetC0 = targetC0,
			settled = false,
		}
		playerState.motorTargets[motorName] = motorTargetState
		return
	end

	motorTargetState.motor = motor
	motorTargetState.targetC0 = targetC0
	motorTargetState.settled = false
end

function smoothing.updateBodyTargets(
	playerState,
	character: Model,
	cframes: { neckC0: CFrame?, rootC0: CFrame?, leftHipC0: CFrame?, rightHipC0: CFrame? }
)
	smoothing.setMotorTarget(playerState, "Neck", getCachedMotor(playerState, character, "Neck"), cframes.neckC0)
	smoothing.setMotorTarget(
		playerState,
		"RootJoint",
		getCachedMotor(playerState, character, "RootJoint"),
		cframes.rootC0
	)
	smoothing.setMotorTarget(
		playerState,
		"Left Hip",
		getCachedMotor(playerState, character, "Left Hip"),
		cframes.leftHipC0
	)
	smoothing.setMotorTarget(
		playerState,
		"Right Hip",
		getCachedMotor(playerState, character, "Right Hip"),
		cframes.rightHipC0
	)
end

function smoothing.updateShoulderTargets(
	playerState,
	character: Model,
	cframes: { leftShoulderC0: CFrame?, rightShoulderC0: CFrame? }
)
	smoothing.setMotorTarget(
		playerState,
		"Left Shoulder",
		getCachedMotor(playerState, character, "Left Shoulder"),
		cframes.leftShoulderC0
	)
	smoothing.setMotorTarget(
		playerState,
		"Right Shoulder",
		getCachedMotor(playerState, character, "Right Shoulder"),
		cframes.rightShoulderC0
	)
end

local settlePositionEpsilon = 0.001
local settleAngleEpsilon = 0.001

local function hasMotorSettled(currentC0: CFrame, targetC0: CFrame): boolean
	local positionDelta = (currentC0.Position - targetC0.Position).Magnitude
	if positionDelta > settlePositionEpsilon then
		return false
	end

	local relativeRotation = currentC0:ToObjectSpace(targetC0)
	local axisAngle = select(2, relativeRotation:ToAxisAngle())
	return math.abs(axisAngle) <= settleAngleEpsilon
end

function smoothing.applyMotorTargets(_controller, playerState, deltaTime: number, smoothingSpeed: number)
	local alpha = mathUtilities.exponentialAlpha(smoothingSpeed, deltaTime)

	for motorName, motorTargetState in pairs(playerState.motorTargets) do
		local motor = motorTargetState.motor

		if motor == nil or motor.Parent == nil then
			playerState.motorTargets[motorName] = nil
			continue
		end

		--// Skip lerp when the motor has converged on its target.
		if motorTargetState.settled then
			continue
		end

		local currentC0 = motor.C0
		local targetC0 = motorTargetState.targetC0

		if hasMotorSettled(currentC0, targetC0) then
			motor.C0 = targetC0
			motorTargetState.settled = true
			continue
		end

		motor.C0 = currentC0:Lerp(targetC0, alpha)
	end
end

return smoothing
