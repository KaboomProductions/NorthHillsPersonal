local replicatedStorage = game:GetService("ReplicatedStorage")

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local offsetCalculator = {}

function offsetCalculator.calculateFirstPersonOffset(controller): Vector3
	local config = controller.config
	local camera = workspace.CurrentCamera
	local humanoidRootPart = controller.humanoidRootPart

	if camera == nil or humanoidRootPart == nil then
		return config.firstPersonOffset
	end

	local lookY = camera.CFrame.LookVector.Y
	local downBlend = math.clamp((-lookY - 0.05) / 0.95, 0, 1)
	local extraDepth = downBlend * 0.2

	--// Extract yaw via atan2 on the right/look vectors instead of
	--// ToEulerAnglesYXZ, which suffers from gimbal lock at steep pitches.
	local cameraRight = camera.CFrame.RightVector
	local cameraYaw = math.atan2(-cameraRight.Z, cameraRight.X)
	local rootForward = humanoidRootPart.CFrame.LookVector
	local rootYaw = math.atan2(-rootForward.X, -rootForward.Z)
	local lookOffset = mathUtilities.normalizeAngle(cameraYaw - rootYaw)

	return config.firstPersonOffset + Vector3.new(-lookOffset, -downBlend * 0.35, -extraDepth)
end

function offsetCalculator.calculateThirdPersonOffset(controller, deltaTime: number): Vector3
	local config = controller.config
	local stateValues = controller.__vars
	local camera = workspace.CurrentCamera
	local humanoidRootPart = controller.humanoidRootPart

	if camera == nil or humanoidRootPart == nil then
		return config.thirdPersonOffset
	end

	local cameraLook = camera.CFrame.LookVector
	local verticalCompensation = -cameraLook.Y * 0.18
	local targetOffset = config.thirdPersonOffset + Vector3.new(0, verticalCompensation, 0)
	local lerpAlpha = mathUtilities.exponentialAlpha(14, deltaTime)

	stateValues.shoulderSide = math.lerp(stateValues.shoulderSide, 1, lerpAlpha)
	return Vector3.new(targetOffset.X * stateValues.shoulderSide, targetOffset.Y, targetOffset.Z)
end

return offsetCalculator
