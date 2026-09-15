local replicatedFirst = game:GetService("ReplicatedFirst")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local clientData = require(replicatedFirst.ClientData)
local rayCastingUtilities = require(replicatedFirst.ClientUtilities.RayCasting)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local offsetCalculator = require(script.Parent.OffsetCalculator)

local player = players.LocalPlayer
local obstructionRaycastParams = RaycastParams.new()
obstructionRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
obstructionRaycastParams.IgnoreWater = true

local viewUpdater = {}

local function getClampedCameraOffset(controller, targetOffset: Vector3): Vector3
	local humanoidRootPart = controller.humanoidRootPart
	local head = controller.head
	local character = controller.character
	if humanoidRootPart == nil or head == nil or character == nil then
		return targetOffset
	end

	local offsetMagnitude = targetOffset.Magnitude
	if offsetMagnitude <= 1e-4 then
		return targetOffset
	end

	obstructionRaycastParams.FilterDescendantsInstances = { character }

	local origin = head.Position
	local desiredCameraPosition = humanoidRootPart.CFrame:PointToWorldSpace(targetOffset)
	local castDirection = desiredCameraPosition - origin
	local obstructionResult =
		rayCastingUtilities.raycastUntilBlockingHit(origin, castDirection, obstructionRaycastParams)
	if obstructionResult == nil then
		return targetOffset
	end

	local safeDistance = math.max(0, obstructionResult.Distance - controller.config.obstructionPadding)
	if safeDistance <= 1e-4 then
		return Vector3.zero
	end

	return targetOffset.Unit * math.min(offsetMagnitude, safeDistance)
end

local function getLockedDefaultOffset(controller): Vector3
	local config = controller.config
	local stateValues = controller.__vars

	if stateValues.isFirstPerson then
		return getClampedCameraOffset(controller, config.firstPersonOffset)
	end

	return getClampedCameraOffset(controller, config.thirdPersonOffset)
end

local function calculateTargetView(controller, deltaTime: number): (Vector3, number)
	local stateValues = controller.__vars
	local config = controller.config
	local targetOffset: Vector3
	local targetZoomDistance: number

	if stateValues.isFirstPerson then
		targetOffset = offsetCalculator.calculateFirstPersonOffset(controller)
		targetZoomDistance = 0
	else
		targetOffset = offsetCalculator.calculateThirdPersonOffset(controller, deltaTime)
		targetZoomDistance = config.thirdPersonDistance
	end

	targetOffset = getClampedCameraOffset(controller, targetOffset)

	return targetOffset, targetZoomDistance
end

function viewUpdater.updateView(controller, deltaTime: number)
	local config = controller.config
	local stateValues = controller.__vars
	local humanoid = controller.humanoid

	if humanoid == nil then
		return
	end

	local currentZoomDistance = player.CameraMaxZoomDistance
	if clientData.isCameraLocked() then
		local defaultOffset = getLockedDefaultOffset(controller)
		local offsetAlpha = mathUtilities.exponentialAlpha(config.offsetSmoothSpeed / 2, deltaTime)
		stateValues.targetOffset = stateValues.targetOffset:Lerp(defaultOffset, offsetAlpha)

		stateValues.isLockTargetReached = (stateValues.targetOffset - defaultOffset).Magnitude
			<= config.lockOffsetTolerance
		humanoid.CameraOffset = stateValues.targetOffset
		player.CameraMaxZoomDistance = currentZoomDistance
		player.CameraMinZoomDistance = currentZoomDistance
		return
	end

	local targetOffset, targetZoomDistance = calculateTargetView(controller, deltaTime)

	local offsetAlpha = mathUtilities.exponentialAlpha(config.offsetSmoothSpeed, deltaTime)
	stateValues.targetOffset = stateValues.targetOffset:Lerp(targetOffset, offsetAlpha)
	humanoid.CameraOffset = stateValues.targetOffset

	local zoomAlpha = mathUtilities.exponentialAlpha(config.zoomSmoothSpeed, deltaTime)
	local nextZoomDistance = math.lerp(currentZoomDistance, targetZoomDistance, zoomAlpha)
	local remainingOffsetMagnitude = (stateValues.targetOffset - targetOffset).Magnitude
	local remainingZoomDistance = math.abs(nextZoomDistance - targetZoomDistance)

	stateValues.isLockTargetReached = remainingOffsetMagnitude <= config.lockOffsetTolerance
		and remainingZoomDistance <= config.lockZoomTolerance

	player.CameraMaxZoomDistance = nextZoomDistance
	player.CameraMinZoomDistance = nextZoomDistance
end

function viewUpdater.snapToTarget(controller)
	local humanoid = controller.humanoid
	if humanoid == nil then
		return
	end

	local stateValues = controller.__vars
	local targetOffset, targetZoomDistance = calculateTargetView(controller, 0)

	stateValues.targetOffset = targetOffset
	stateValues.shoulderSide = 1
	stateValues.isLockTargetReached = true
	humanoid.CameraOffset = targetOffset
	player.CameraMaxZoomDistance = targetZoomDistance
	player.CameraMinZoomDistance = targetZoomDistance
end

return viewUpdater
