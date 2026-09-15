local helpers = require(script.Parent.Helpers)

local armMotion = {}

local function getMovementSpeedMagnitude(controller): number
	local torso = controller.torso

	if torso == nil then
		return 0
	end

	return torso.AssemblyLinearVelocity.Magnitude
end

local function updateRecentMovementTime(controller)
	local config = controller.config
	local stateValues = controller.__vars

	if getMovementSpeedMagnitude(controller) >= config.movementSpeedThreshold then
		stateValues.lastMoveTime = time()
	end
end

local function calculateFollowAlpha(controller, deltaTime: number): number
	local config = controller.config
	local stateValues = controller.__vars
	local isRecentMovement = helpers.isRecentMovement(stateValues.lastMoveTime, config.recentMovementDurationSeconds)
	local followAlpha = isRecentMovement and config.armFollowAlpha.recentMovement or config.armFollowAlpha.base

	return helpers.calculateFrameAlpha(followAlpha, deltaTime, config.frameRate)
end

local function updateArmFollowBlend(controller, deltaTime: number): number
	local config = controller.config
	local stateValues = controller.__vars
	local blendDurationSeconds = config.armFollow.blendDurationSeconds or 0

	if blendDurationSeconds <= 0 then
		stateValues.armFollowBlend = 1
		return 1
	end

	local blendAlpha = deltaTime / blendDurationSeconds
	stateValues.armFollowBlend = math.clamp(stateValues.armFollowBlend + blendAlpha, 0, 1)

	return stateValues.armFollowBlend
end

local function calculateLookAngles(controller, camera: Camera): (number, number, number, number)
	local config = controller.config
	local humanoidRootPart = controller.humanoidRootPart
	local torsoLookVector = humanoidRootPart.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
	local rawHorizontalAngle = math.atan2(torsoLookVector.X, -torsoLookVector.Z)
	local rawVerticalAngle = math.asin(math.clamp(torsoLookVector.Y, -1, 1))
	local lookClampRadians = config.lookClampRadians
	local clampedHorizontalAngle =
		math.clamp(rawHorizontalAngle, -lookClampRadians.horizontalMinimum, lookClampRadians.horizontalMaximum)
	local clampedVerticalAngle =
		math.clamp(rawVerticalAngle, lookClampRadians.verticalMinimum, lookClampRadians.verticalMaximum)

	return rawHorizontalAngle, rawVerticalAngle, clampedHorizontalAngle, clampedVerticalAngle
end

local function getItemRightArmConfig(controller)
	return controller.__vars.itemRightArmConfig or controller.config.rightArm
end

local function calculateTurnResponseOffset(
	controller,
	rawHorizontalAngle: number,
	rawVerticalAngle: number,
	clampedHorizontalAngle: number,
	clampedVerticalAngle: number,
	followAlpha: number
): Vector3
	local config = controller.config
	local stateValues = controller.__vars
	local rightArmConfig = getItemRightArmConfig(controller)
	local turnConfig = rightArmConfig.firstPersonTurnResponse
	local maximumHorizontalAngle = config.lookClampRadians.horizontalMaximum
	local turnRightAlpha = maximumHorizontalAngle > 0 and math.clamp(rawHorizontalAngle / maximumHorizontalAngle, 0, 1)
		or 0

	stateValues.turnDepthOffset += ((turnRightAlpha * turnConfig.turnDepthAlpha) - stateValues.turnDepthOffset) * followAlpha
	stateValues.turnLateralOffset += ((turnRightAlpha * turnConfig.turnLateralAlpha) - stateValues.turnLateralOffset) * followAlpha

	local offsetX = -(stateValues.turnLateralOffset * turnConfig.turnLateralStuds)
	local offsetY = 0
	local offsetZ = stateValues.turnDepthOffset * turnConfig.turnDepthStuds

	local horizontalOvershoot = math.abs(rawHorizontalAngle - clampedHorizontalAngle)
	local verticalOvershoot =
		math.clamp(rawVerticalAngle - clampedVerticalAngle, 0, turnConfig.maximumVerticalOvershootRadians)

	stateValues.horizontalOvershoot += (horizontalOvershoot - stateValues.horizontalOvershoot) * followAlpha
	stateValues.verticalOvershoot += (verticalOvershoot - stateValues.verticalOvershoot) * followAlpha

	offsetX += stateValues.horizontalOvershoot + stateValues.verticalOvershoot * turnConfig.overshootSlideFactor
	offsetY += stateValues.verticalOvershoot * turnConfig.overshootSlideFactor * turnConfig.verticalOvershootHeightScale

	return Vector3.new(offsetX, offsetY, offsetZ)
end

local function calculateRightArmOffset(
	controller,
	rawHorizontalAngle: number,
	rawVerticalAngle: number,
	clampedHorizontalAngle: number,
	clampedVerticalAngle: number,
	followAlpha: number,
	isFirstPerson: boolean
): Vector3
	local rightArmConfig = getItemRightArmConfig(controller)
	local baseOffset = rightArmConfig.baseOffset or Vector3.zero

	if not isFirstPerson then
		return baseOffset
	end

	return baseOffset
		+ calculateTurnResponseOffset(
			controller,
			rawHorizontalAngle,
			rawVerticalAngle,
			clampedHorizontalAngle,
			clampedVerticalAngle,
			followAlpha
		)
end

local function calculateFirstPersonViewmodelOffset(
	controller,
	rawVerticalAngle: number,
	isFirstPerson: boolean
): Vector3
	if not isFirstPerson then
		return Vector3.zero
	end

	local rightArmConfig = getItemRightArmConfig(controller)
	local firstPersonViewmodelConfig = rightArmConfig.firstPersonViewmodel

	if rawVerticalAngle > 0 then
		local lookUpAlpha = math.clamp(rawVerticalAngle / firstPersonViewmodelConfig.maximumLookUpRadians, 0, 1)

		return firstPersonViewmodelConfig.lookUpOffset * lookUpAlpha
	end

	if rawVerticalAngle < 0 then
		local lookDownAlpha =
			math.clamp(math.abs(rawVerticalAngle) / firstPersonViewmodelConfig.maximumLookDownRadians, 0, 1)

		return firstPersonViewmodelConfig.lookDownOffset * lookDownAlpha
	end

	return Vector3.zero
end

local function resetTurnResponseState(controller, followAlpha: number)
	local stateValues = controller.__vars
	stateValues.turnDepthOffset += (0 - stateValues.turnDepthOffset) * followAlpha
	stateValues.turnLateralOffset += (0 - stateValues.turnLateralOffset) * followAlpha
	stateValues.horizontalOvershoot += (0 - stateValues.horizontalOvershoot) * followAlpha
	stateValues.verticalOvershoot += (0 - stateValues.verticalOvershoot) * followAlpha
end

local function calculateLocalShoulderAngles(
	controller,
	rawHorizontalAngle: number,
	rawVerticalAngle: number,
	isFirstPerson: boolean
): (number, number)
	if not isFirstPerson then
		return rawHorizontalAngle, rawVerticalAngle
	end

	local rightArmConfig = getItemRightArmConfig(controller)
	local firstPersonViewmodelConfig = rightArmConfig.firstPersonViewmodel

	if rawVerticalAngle > 0 then
		return rawHorizontalAngle, rawVerticalAngle * firstPersonViewmodelConfig.lookUpPitchScale
	end

	if rawVerticalAngle < 0 then
		return rawHorizontalAngle, rawVerticalAngle * firstPersonViewmodelConfig.lookDownPitchScale
	end

	return rawHorizontalAngle, rawVerticalAngle
end

local function applyShoulderTarget(
	currentShoulderC0: CFrame,
	targetShoulderC0: CFrame,
	followAlpha: number,
	shoulderMotor: Motor6D
): CFrame
	local nextShoulderC0 = currentShoulderC0:Lerp(targetShoulderC0, followAlpha)
	shoulderMotor.C0 = nextShoulderC0

	return nextShoulderC0
end

local function getLeftSupportCFrame(controller): CFrame
	local leftArmConfig = controller.config.leftArm
	local stateValues = controller.__vars
	local supportOffset = stateValues.leftArmSupportOffset or leftArmConfig.supportOffset
	local supportRotationRadians = stateValues.leftArmSupportRotationRadians or leftArmConfig.supportRotationRadians

	return CFrame.new(supportOffset)
		* CFrame.Angles(supportRotationRadians.X, supportRotationRadians.Y, supportRotationRadians.Z)
end

local function getShoulderDelta(defaultShoulderC0: CFrame, shoulderC0: CFrame): CFrame
	return defaultShoulderC0:ToObjectSpace(shoulderC0)
end

local function mirrorShoulderDelta(shoulderDelta: CFrame): CFrame
	local position = shoulderDelta.Position
	local xRotation, yRotation, zRotation = (shoulderDelta - position):ToEulerAnglesXYZ()

	return CFrame.new(-position.X, position.Y, position.Z) * CFrame.Angles(xRotation, yRotation, -zRotation)
end

local function getLeftShoulderSupportTarget(
	controller,
	defaultLeftShoulderC0: CFrame,
	defaultRightShoulderC0: CFrame,
	rightShoulderC0: CFrame,
	leftSupportCFrame: CFrame
): CFrame
	local followsRightArm = controller.__vars.leftArmSupportFollowsRightArm

	if followsRightArm == false then
		return defaultLeftShoulderC0 * leftSupportCFrame
	end

	local rightShoulderDelta = getShoulderDelta(defaultRightShoulderC0, rightShoulderC0)
	local mirroredShoulderDelta = mirrorShoulderDelta(rightShoulderDelta)

	return defaultLeftShoulderC0 * mirroredShoulderDelta * leftSupportCFrame
end

function armMotion.returnArms(controller, deltaTime: number)
	local config = controller.config
	local stateValues = controller.__vars
	local shoulders = controller.shoulders
	local returnAlpha = helpers.calculateFrameAlpha(config.idleReturnAlpha, deltaTime, config.frameRate)

	shoulders.currentRightC0 =
		applyShoulderTarget(shoulders.currentRightC0, shoulders.defaultRightC0, returnAlpha, shoulders.rightMotor)
	shoulders.currentLeftC0 =
		applyShoulderTarget(shoulders.currentLeftC0, shoulders.defaultLeftC0, returnAlpha, shoulders.leftMotor)

	local hasReturnedRightArm = helpers.isCFrameNear(
		shoulders.currentRightC0,
		shoulders.defaultRightC0,
		config.positionEpsilon,
		config.angleEpsilonRadians
	)
	local hasReturnedLeftArm = helpers.isCFrameNear(
		shoulders.currentLeftC0,
		shoulders.defaultLeftC0,
		config.positionEpsilon,
		config.angleEpsilonRadians
	)

	if hasReturnedRightArm and hasReturnedLeftArm then
		stateValues.shouldReturnArms = false
	end
end

function armMotion.updateArmFollow(
	controller,
	camera: Camera,
	isFirstPerson: boolean,
	deltaTime: number
): { leftShoulderC0: CFrame?, rightShoulderC0: CFrame? }
	local stateValues = controller.__vars
	local shoulders = controller.shoulders

	updateRecentMovementTime(controller)

	local rawHorizontalAngle, rawVerticalAngle, clampedHorizontalAngle, clampedVerticalAngle =
		calculateLookAngles(controller, camera)
	local followAlpha = calculateFollowAlpha(controller, deltaTime)
	local armFollowBlend = updateArmFollowBlend(controller, deltaTime)
	followAlpha = math.clamp(followAlpha * armFollowBlend, 0, 1)
	if not isFirstPerson then
		resetTurnResponseState(controller, followAlpha)
	end

	local rightArmConfig = getItemRightArmConfig(controller)
	local baseOffset = rightArmConfig.baseOffset or Vector3.zero
	local rightArmOffset = calculateRightArmOffset(
		controller,
		rawHorizontalAngle,
		rawVerticalAngle,
		clampedHorizontalAngle,
		clampedVerticalAngle,
		followAlpha,
		isFirstPerson
	)
	local localHorizontalAngle, localVerticalAngle =
		calculateLocalShoulderAngles(controller, rawHorizontalAngle, rawVerticalAngle, isFirstPerson)
	local localRightArmOffset = rightArmOffset
		+ calculateFirstPersonViewmodelOffset(controller, rawVerticalAngle, isFirstPerson)
	local calculatedRightShoulderC0 = shoulders.defaultRightC0
		* CFrame.new(localRightArmOffset)
		* CFrame.Angles(0, -localHorizontalAngle, localVerticalAngle)
	local replicatedRightShoulderC0 = shoulders.defaultRightC0
		* CFrame.new(baseOffset)
		* CFrame.Angles(0, -rawHorizontalAngle, rawVerticalAngle)

	local replicatedLeftShoulderC0 = nil
	if stateValues.isCoupledArms then
		local horizontalRotation = CFrame.Angles(0, -localHorizontalAngle, 0)
		local replicatedHorizontalRotation = CFrame.Angles(0, -rawHorizontalAngle, 0)
		local rightVertical = CFrame.Angles(0, 0, localVerticalAngle)
		local replicatedRightVertical = CFrame.Angles(0, 0, rawVerticalAngle)

		local rightPos = shoulders.defaultRightC0.Position
		local leftPos = shoulders.defaultLeftC0.Position

		local sharedOffset = calculateFirstPersonViewmodelOffset(controller, rawVerticalAngle, isFirstPerson)
		local mirroredBaseOffset = Vector3.new(-baseOffset.X, baseOffset.Y, baseOffset.Z)

		calculatedRightShoulderC0 = CFrame.new(horizontalRotation * rightPos)
			* (shoulders.defaultRightC0 - rightPos)
			* horizontalRotation
			* CFrame.new(baseOffset)
			* CFrame.new(sharedOffset)
			* rightVertical
		replicatedRightShoulderC0 = CFrame.new(replicatedHorizontalRotation * rightPos)
			* (shoulders.defaultRightC0 - rightPos)
			* replicatedHorizontalRotation
			* CFrame.new(baseOffset)
			* replicatedRightVertical

		local leftVertical = CFrame.Angles(0, 0, -localVerticalAngle)
		local replicatedLeftVertical = CFrame.Angles(0, 0, -rawVerticalAngle)

		local leftSupportCFrame = getLeftSupportCFrame(controller)
		local calculatedLeftShoulderC0 = CFrame.new(horizontalRotation * leftPos)
			* (shoulders.defaultLeftC0 - leftPos)
			* horizontalRotation
			* CFrame.new(mirroredBaseOffset)
			* CFrame.new(-sharedOffset.X, sharedOffset.Y, sharedOffset.Z)
			* leftVertical
			* leftSupportCFrame

		shoulders.currentRightC0 =
			applyShoulderTarget(shoulders.currentRightC0, calculatedRightShoulderC0, followAlpha, shoulders.rightMotor)

		replicatedLeftShoulderC0 = CFrame.new(replicatedHorizontalRotation * leftPos)
			* (shoulders.defaultLeftC0 - leftPos)
			* replicatedHorizontalRotation
			* CFrame.new(mirroredBaseOffset)
			* replicatedLeftVertical
			* leftSupportCFrame

		shoulders.currentLeftC0 =
			applyShoulderTarget(shoulders.currentLeftC0, calculatedLeftShoulderC0, followAlpha, shoulders.leftMotor)
	else
		shoulders.currentRightC0 =
			applyShoulderTarget(shoulders.currentRightC0, calculatedRightShoulderC0, followAlpha, shoulders.rightMotor)

		if stateValues.isLeftArmSupportEnabled then
			local leftSupportCFrame = getLeftSupportCFrame(controller)
			local calculatedLeftShoulderC0 = getLeftShoulderSupportTarget(
				controller,
				shoulders.defaultLeftC0,
				shoulders.defaultRightC0,
				shoulders.currentRightC0,
				leftSupportCFrame
			)

			replicatedLeftShoulderC0 = getLeftShoulderSupportTarget(
				controller,
				shoulders.defaultLeftC0,
				shoulders.defaultRightC0,
				replicatedRightShoulderC0,
				leftSupportCFrame
			)
			shoulders.currentLeftC0 =
				applyShoulderTarget(shoulders.currentLeftC0, calculatedLeftShoulderC0, followAlpha, shoulders.leftMotor)
		else
			local leftReturnAlpha =
				helpers.calculateFrameAlpha(controller.config.idleReturnAlpha, deltaTime, controller.config.frameRate)

			shoulders.currentLeftC0 = applyShoulderTarget(
				shoulders.currentLeftC0,
				shoulders.defaultLeftC0,
				leftReturnAlpha,
				shoulders.leftMotor
			)
		end
	end

	return {
		rightShoulderC0 = replicatedRightShoulderC0,
		leftShoulderC0 = replicatedLeftShoulderC0,
	}
end

return armMotion
