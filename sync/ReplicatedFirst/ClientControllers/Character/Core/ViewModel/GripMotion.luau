local replicatedFirst = game:GetService("ReplicatedFirst")
local players = game:GetService("Players")

local rayCastingUtilities = require(replicatedFirst.ClientUtilities.RayCasting)

local helpers = require(script.Parent.Helpers)

local player = players.LocalPlayer

local gripMotion = {}

type GripJoint = Weld | Motor6D

local function getGripJoint(controller): GripJoint?
	local config = controller.config
	local character = controller.character
	local gripState = controller.gripState
	local heldItem = controller.heldItem
	local gripJoint = gripState.weld

	local hasMismatchedHandle = heldItem ~= nil
		and gripJoint ~= nil
		and gripJoint.Part0 ~= nil
		and gripJoint.Part1 ~= nil
		and not gripJoint.Part0:IsDescendantOf(heldItem)
		and not gripJoint.Part1:IsDescendantOf(heldItem)

	if
		gripJoint == nil
		or gripJoint.Parent == nil
		or gripJoint.Part0 == nil
		or gripJoint.Part1 == nil
		or hasMismatchedHandle
	then
		gripJoint = helpers.findGripJoint(character, config.handFollow.rightGripName, heldItem)
		gripState.weld = gripJoint
	end

	return gripJoint
end

local function cacheGripBaseState(controller, gripJoint: GripJoint)
	local gripState = controller.gripState

	if gripState.baseC0 ~= nil and gripState.cachedWeld == gripJoint then
		return
	end

	local baseC0 = gripJoint.C0

	gripState.cachedWeld = gripJoint
	gripState.baseC0 = baseC0
	gripState.basePosition = baseC0.Position
	gripState.baseRotation = baseC0 - baseC0.Position
	gripState.currentRotation = gripState.baseRotation
end

local function clampRotationToLimits(rotationCFrame: CFrame, config): CFrame
	local xRotation, yRotation, zRotation = rotationCFrame:ToEulerAnglesXYZ()
	local rotationLimitsRadians = config.handFollow.rotationLimitsRadians

	xRotation = math.clamp(xRotation, rotationLimitsRadians.xMinimum, rotationLimitsRadians.xMaximum)
	yRotation = math.clamp(yRotation, rotationLimitsRadians.yMinimum, rotationLimitsRadians.yMaximum)
	zRotation = math.clamp(zRotation, rotationLimitsRadians.zMinimum, rotationLimitsRadians.zMaximum)

	return CFrame.Angles(xRotation, yRotation, zRotation)
end

local function calculateTargetGripRotation(controller, camera: Camera, gripJoint: GripJoint): CFrame?
	local gripState = controller.gripState
	local itemHandle = controller.itemHandle

	if itemHandle == nil or itemHandle.Parent == nil or gripState.baseRotation == nil then
		return nil
	end

	local aimPosition = rayCastingUtilities.getAimPosition(camera, player)
	if aimPosition == nil then
		return nil
	end

	local desiredWorldCFrame = CFrame.lookAt(itemHandle.Position, aimPosition)
	if gripJoint.Part0 == nil or gripJoint.Part1 == nil then
		return nil
	end

	local targetGripC0 = gripJoint.Part0.CFrame:ToObjectSpace(desiredWorldCFrame * gripJoint.C1)

	return targetGripC0 - targetGripC0.Position
end

function gripMotion.resetGripState(controller)
	local stateValues = controller.__vars
	local gripState = controller.gripState

	stateValues.shouldReturnGrip = true
	stateValues.handFollowBlend = 0

	gripState.weld = nil
	gripState.cachedWeld = nil
	gripState.baseC0 = nil
	gripState.basePosition = nil
	gripState.baseRotation = nil
	gripState.currentRotation = nil
end

function gripMotion.beginHandFollow(controller)
	local stateValues = controller.__vars

	stateValues.handFollowEnableTime = time()
	gripMotion.resetGripState(controller)
end

function gripMotion.updateHandFollow(controller, camera: Camera, deltaTime: number)
	local config = controller.config
	local stateValues = controller.__vars
	local gripState = controller.gripState
	local elapsedSeconds = time() - stateValues.handFollowEnableTime

	if elapsedSeconds < config.handFollow.delaySeconds then
		stateValues.handFollowBlend = 0
		return
	end

	local blendDurationSeconds = config.handFollow.blendDurationSeconds
	local blendAlpha = blendDurationSeconds > 0 and (deltaTime / blendDurationSeconds) or 1
	local followAlpha = helpers.calculateFrameAlpha(config.handFollow.lerpAlpha, deltaTime, config.frameRate)
	local gripJoint = getGripJoint(controller)

	stateValues.handFollowBlend = math.clamp(stateValues.handFollowBlend + blendAlpha, 0, 1)

	if gripJoint == nil or gripJoint.Part0 == nil or gripJoint.Part1 == nil then
		return
	end

	cacheGripBaseState(controller, gripJoint)

	local targetRotation = calculateTargetGripRotation(controller, camera, gripJoint)
	local basePosition = gripState.basePosition
	local currentRotation = gripState.currentRotation
	local baseRotation = gripState.baseRotation

	if targetRotation == nil or basePosition == nil or currentRotation == nil or baseRotation == nil then
		return
	end

	local blendedFollowAlpha = math.clamp(followAlpha * stateValues.handFollowBlend, 0, 1)
	local nextRotation = currentRotation:Lerp(targetRotation, blendedFollowAlpha)

	gripState.currentRotation = nextRotation

	local relativeRotation = baseRotation:ToObjectSpace(nextRotation)
	local clampedRotation = clampRotationToLimits(relativeRotation, config)

	gripJoint.C0 = CFrame.new(basePosition) * (baseRotation * clampedRotation)
	stateValues.shouldReturnGrip = true
end

function gripMotion.returnGrip(controller, deltaTime: number)
	local config = controller.config
	local stateValues = controller.__vars
	local gripState = controller.gripState
	local gripJoint = getGripJoint(controller)
	local basePosition = gripState.basePosition
	local baseRotation = gripState.baseRotation
	local currentRotation = gripState.currentRotation

	if gripJoint == nil or basePosition == nil or baseRotation == nil or currentRotation == nil then
		stateValues.shouldReturnGrip = false
		return
	end

	local returnAlpha = helpers.calculateFrameAlpha(config.handFollow.lerpAlpha, deltaTime, config.frameRate)
	local nextRotation = currentRotation:Lerp(baseRotation, returnAlpha)

	gripState.currentRotation = nextRotation
	gripJoint.C0 = CFrame.new(basePosition) * nextRotation

	local rotationDifference = helpers.getRotationDifference(baseRotation, nextRotation)
	if rotationDifference <= config.angleEpsilonRadians then
		stateValues.shouldReturnGrip = false
	end
end

return gripMotion
