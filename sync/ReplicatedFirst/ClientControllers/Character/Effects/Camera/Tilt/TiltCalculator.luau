local tiltCalculator = {}

local function flattenXZ(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function tiltCalculator.calculateTargetTilt(controller): number
	local config = controller.config
	local camera = workspace.CurrentCamera
	local humanoid = controller.humanoid

	if humanoid == nil or camera == nil then
		return 0
	end

	local moveDirection = flattenXZ(humanoid.MoveDirection)
	local moveMagnitude = moveDirection.Magnitude
	if moveMagnitude <= config.speedThreshold then
		return 0
	end

	local cameraRight = flattenXZ(camera.CFrame.RightVector)
	local rightMagnitude = cameraRight.Magnitude
	if rightMagnitude <= 0.001 then
		return 0
	end

	local moveUnit = moveDirection / moveMagnitude
	local cameraRightUnit = cameraRight / rightMagnitude

	--// Positive means the player is moving to the camera's right.
	local strafeAmount = math.clamp(moveUnit:Dot(cameraRightUnit), -1, 1)
	local targetTilt = strafeAmount * config.tiltAngle

	return math.clamp(targetTilt, -config.maxTiltAngle, config.maxTiltAngle)
end

return tiltCalculator
