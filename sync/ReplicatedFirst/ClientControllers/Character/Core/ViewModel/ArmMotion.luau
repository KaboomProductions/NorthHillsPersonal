local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")

local rayCastingUtilities = require(replicatedFirst.ClientUtilities.RayCasting)
local clientData = require(replicatedFirst.ClientData)

local helpers = require(script.Parent.Helpers)

local player = players.LocalPlayer
local aimingFollowSpeedMultiplier = 1.5

local armMotion = {}

local function configureSpring(activeSpring, springConfig)
	activeSpring.mass = springConfig.mass or 5
	activeSpring.force = springConfig.force or 50
	activeSpring.damping = springConfig.damping or 4
	activeSpring.speed = springConfig.speed or 4
end

local function randomizeVector3(baseVector: Vector3, maximumVariation: Vector3, randomGenerator: Random): Vector3
	return Vector3.new(
		baseVector.X + randomGenerator:NextNumber(-maximumVariation.X, maximumVariation.X),
		baseVector.Y + randomGenerator:NextNumber(-maximumVariation.Y, maximumVariation.Y),
		baseVector.Z + randomGenerator:NextNumber(-maximumVariation.Z, maximumVariation.Z)
	)
end

local function updateRecoil(controller, deltaTime: number, isFirstPerson: boolean): CFrame
	local stateValues = controller.__vars
	local recoilConfig = stateValues.recoilConfig
	local positionSpring = controller.recoilPositionSpring
	local rotationSpring = controller.recoilRotationSpring

	if recoilConfig == nil then
		stateValues.pendingRecoilCount = 0
		return CFrame.identity
	end

	local springConfig = recoilConfig.spring or {}
	configureSpring(positionSpring, springConfig)
	configureSpring(rotationSpring, springConfig)

	if isFirstPerson then
		local recoilMultiplier = stateValues.isAiming and (recoilConfig.aimingMultiplier or 1) or 1
		local positionVelocity = recoilConfig.positionVelocity or Vector3.zero
		local positionVelocityVariation = recoilConfig.positionVelocityVariation or Vector3.zero
		local rotationVelocityRadians = recoilConfig.rotationVelocityRadians or Vector3.zero
		local rotationVelocityVariationRadians = recoilConfig.rotationVelocityVariationRadians or Vector3.zero

		for _ = 1, stateValues.pendingRecoilCount do
			positionSpring:shove(
				randomizeVector3(positionVelocity, positionVelocityVariation, controller.recoilRandom)
					* recoilMultiplier
			)
			rotationSpring:shove(
				randomizeVector3(rotationVelocityRadians, rotationVelocityVariationRadians, controller.recoilRandom)
					* recoilMultiplier
			)
		end
	end

	stateValues.pendingRecoilCount = 0
	local position = positionSpring:update(deltaTime)
	local rotationRadians = rotationSpring:update(deltaTime)

	if not isFirstPerson then
		return CFrame.identity
	end

	return CFrame.new(position) * CFrame.Angles(rotationRadians.X, rotationRadians.Y, rotationRadians.Z)
end

local function applyCameraSpaceTransform(
	controller,
	camera: Camera,
	shoulderC0: CFrame,
	cameraSpaceTransform: CFrame
): CFrame
	local torsoCFrame = controller.torso.CFrame
	local cameraRelativeShoulder = camera.CFrame:ToObjectSpace(torsoCFrame * shoulderC0)
	return torsoCFrame:ToObjectSpace(camera.CFrame * cameraSpaceTransform * cameraRelativeShoulder)
end

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
	local followSpeedMultiplier = stateValues.isAiming and aimingFollowSpeedMultiplier or 1

	return helpers.calculateFrameAlpha(followAlpha * followSpeedMultiplier, deltaTime, config.frameRate)
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

local function getCameraRelativeShoulderTarget(controller, camera: Camera, neutralShoulderC0: CFrame): CFrame
	local lookOffset = controller.__vars.cameraRelativeLookOffset or CFrame.identity
	local torsoCFrame = controller.torso.CFrame
	local uprightRotation = controller.humanoidRootPart.CFrame.Rotation
	local uprightCameraCFrame = CFrame.new(camera.CFrame.Position) * uprightRotation
	local neutralShoulderWorld = CFrame.new(torsoCFrame.Position) * uprightRotation * neutralShoulderC0
	local cameraRelativeOffset = uprightCameraCFrame:ToObjectSpace(neutralShoulderWorld)

	return torsoCFrame:ToObjectSpace(camera.CFrame * lookOffset * cameraRelativeOffset)
end

local function resolveRightGripJoint(controller): (Weld | Motor6D)?
	local itemHandle = controller.itemHandle
	local rightShoulderMotor = controller.shoulders.rightMotor
	if itemHandle == nil or itemHandle.Parent == nil or rightShoulderMotor.Part1 == nil then
		return nil
	end

	local gripJoint = controller.gripState.weld
	if
		gripJoint == nil
		or gripJoint.Parent == nil
		or gripJoint.Part0 ~= rightShoulderMotor.Part1
		or gripJoint.Part1 ~= itemHandle
	then
		gripJoint =
			helpers.findGripJoint(controller.character, controller.config.handFollow.rightGripName, controller.heldItem)
		controller.gripState.weld = gripJoint
	end

	if gripJoint == nil or gripJoint.Part0 ~= rightShoulderMotor.Part1 or gripJoint.Part1 ~= itemHandle then
		return nil
	end

	return gripJoint
end

local function getCameraRelativeAimCorrection(controller, camera: Camera, rightShoulderC0: CFrame): CFrame?
	if controller.__vars.cameraRelativeAim ~= true then
		return nil
	end

	local gripJoint = resolveRightGripJoint(controller)
	if gripJoint == nil then
		return nil
	end

	local aimPosition = rayCastingUtilities.getAimPosition(camera, player)
	if aimPosition == nil then
		return nil
	end

	local rightShoulderMotor = controller.shoulders.rightMotor
	local predictedRightArmCFrame = rightShoulderMotor.Part0.CFrame
		* rightShoulderC0
		* rightShoulderMotor.Transform
		* rightShoulderMotor.C1:Inverse()
	local predictedHandleCFrame = predictedRightArmCFrame * gripJoint.C0 * gripJoint.C1:Inverse()
	local aimOffset = aimPosition - predictedHandleCFrame.Position
	if aimOffset.Magnitude <= 0.001 then
		return nil
	end

	local currentDirection = predictedHandleCFrame.LookVector
	local aimDirection = aimOffset.Unit
	local rotationAxis = currentDirection:Cross(aimDirection)
	local directionDot = math.clamp(currentDirection:Dot(aimDirection), -1, 1)
	local aimRotation

	if rotationAxis.Magnitude <= 0.0001 then
		if directionDot > 0 then
			return nil
		end

		aimRotation = CFrame.fromAxisAngle(predictedHandleCFrame.UpVector, math.pi)
	else
		aimRotation = CFrame.fromAxisAngle(rotationAxis.Unit, math.acos(directionDot))
	end

	local handlePosition = predictedHandleCFrame.Position
	return CFrame.new(handlePosition) * aimRotation * CFrame.new(-handlePosition)
end

local function applyCameraRelativeAimCorrection(controller, aimCorrection: CFrame, shoulderC0: CFrame): CFrame
	local torsoCFrame = controller.torso.CFrame
	return torsoCFrame:ToObjectSpace(aimCorrection * torsoCFrame * shoulderC0)
end

local function getAimDownSightsCorrection(controller, camera: Camera, hipFireRightShoulderC0: CFrame): CFrame?
	local heldItem = controller.heldItem
	local aimPart = heldItem and heldItem:FindFirstChild("AimPart", true)
	if aimPart == nil or not aimPart:IsA("BasePart") then
		return nil
	end

	local rightShoulderMotor = controller.shoulders.rightMotor
	local rightArm = rightShoulderMotor.Part1
	if rightArm == nil then
		return nil
	end

	local predictedRightArmCFrame = rightShoulderMotor.Part0.CFrame
		* hipFireRightShoulderC0
		* rightShoulderMotor.Transform
		* rightShoulderMotor.C1:Inverse()
	local currentRightArmToAimPart = rightArm.CFrame:ToObjectSpace(aimPart.CFrame)
	local predictedAimPartCFrame = predictedRightArmCFrame * currentRightArmToAimPart

	return camera.CFrame * predictedAimPartCFrame:Inverse()
end

local function updateAiming(controller, deltaTime: number, isFirstPerson: boolean): number
	local stateValues = controller.__vars
	local aimConfig = stateValues.aimConfig

	if aimConfig == nil or not isFirstPerson then
		stateValues.aimAlpha = 0
		clientData.fieldOfViewModifiers.aiming = nil
		return 0
	end

	local fieldOfViewOffset = aimConfig.fieldOfViewOffset
	clientData.fieldOfViewModifiers.aiming = stateValues.isAiming and fieldOfViewOffset or nil

	local blendDurationSeconds = aimConfig.blendDurationSeconds or 0.2
	local targetAlpha = stateValues.isAiming and 1 or 0
	local currentAlpha = stateValues.aimAlpha or 0

	if blendDurationSeconds <= 0 then
		stateValues.aimAlpha = targetAlpha
	else
		local maximumStep = deltaTime / blendDurationSeconds
		stateValues.aimAlpha = currentAlpha + math.clamp(targetAlpha - currentAlpha, -maximumStep, maximumStep)
	end

	return stateValues.aimAlpha
end

local function calculateVerticalScreenOffset(
	lookConfig: { maximumAngleRadians: number?, offsetStuds: number? }?,
	rawVerticalAngle: number,
	offsetSign: number
): CFrame
	if lookConfig == nil then
		return CFrame.identity
	end

	local maximumAngleRadians = lookConfig.maximumAngleRadians
	local offsetStuds = lookConfig.offsetStuds
	if type(maximumAngleRadians) ~= "number" or maximumAngleRadians <= 0 or type(offsetStuds) ~= "number" then
		return CFrame.identity
	end

	local lookAlpha = math.clamp(math.abs(rawVerticalAngle) / maximumAngleRadians, 0, 1)
	return CFrame.new(0, offsetSign * offsetStuds * lookAlpha, 0)
end

local function calculateCameraRelativeLookOffset(controller, rawVerticalAngle: number): CFrame
	local stateValues = controller.__vars

	if rawVerticalAngle < 0 then
		return calculateVerticalScreenOffset(stateValues.cameraRelativeLookDown, rawVerticalAngle, 1)
	end

	if rawVerticalAngle > 0 then
		return calculateVerticalScreenOffset(stateValues.cameraRelativeLookUp, rawVerticalAngle, -1)
	end

	return CFrame.identity
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
	stateValues.cameraRelativeLookOffset = calculateCameraRelativeLookOffset(controller, rawVerticalAngle)
	local aimAlpha = updateAiming(controller, deltaTime, isFirstPerson)
	local recoilTransform = updateRecoil(controller, deltaTime, isFirstPerson)
	local followAlpha = calculateFollowAlpha(controller, deltaTime)
	local armFollowBlend = updateArmFollowBlend(controller, deltaTime)
	followAlpha = math.clamp(followAlpha * armFollowBlend, 0, 1)
	if not isFirstPerson then
		resetTurnResponseState(controller, followAlpha)
	end

	local rightArmConfig = getItemRightArmConfig(controller)
	local baseOffset = rightArmConfig.baseOffset or Vector3.zero
	local neutralRightShoulderC0 = shoulders.defaultRightC0 * CFrame.new(baseOffset)
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
		local neutralLeftShoulderC0 = shoulders.defaultLeftC0 * CFrame.new(mirroredBaseOffset) * leftSupportCFrame
		local calculatedLeftShoulderC0 = CFrame.new(horizontalRotation * leftPos)
			* (shoulders.defaultLeftC0 - leftPos)
			* horizontalRotation
			* CFrame.new(mirroredBaseOffset)
			* CFrame.new(-sharedOffset.X, sharedOffset.Y, sharedOffset.Z)
			* leftVertical
			* leftSupportCFrame

		if stateValues.isCameraRelative and isFirstPerson then
			calculatedRightShoulderC0 = getCameraRelativeShoulderTarget(controller, camera, neutralRightShoulderC0)
			calculatedLeftShoulderC0 = getCameraRelativeShoulderTarget(controller, camera, neutralLeftShoulderC0)

			if aimAlpha > 0 then
				local aimCorrection = getAimDownSightsCorrection(controller, camera, calculatedRightShoulderC0)
				if aimCorrection ~= nil then
					calculatedRightShoulderC0 = calculatedRightShoulderC0:Lerp(
						applyCameraRelativeAimCorrection(controller, aimCorrection, calculatedRightShoulderC0),
						aimAlpha
					)
					calculatedLeftShoulderC0 = calculatedLeftShoulderC0:Lerp(
						applyCameraRelativeAimCorrection(controller, aimCorrection, calculatedLeftShoulderC0),
						aimAlpha
					)
				end
			end
		end

		calculatedRightShoulderC0 =
			applyCameraSpaceTransform(controller, camera, calculatedRightShoulderC0, recoilTransform)
		calculatedLeftShoulderC0 =
			applyCameraSpaceTransform(controller, camera, calculatedLeftShoulderC0, recoilTransform)

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
		if stateValues.isCameraRelative and isFirstPerson then
			calculatedRightShoulderC0 = getCameraRelativeShoulderTarget(controller, camera, neutralRightShoulderC0)
		end

		shoulders.currentRightC0 =
			applyShoulderTarget(shoulders.currentRightC0, calculatedRightShoulderC0, followAlpha, shoulders.rightMotor)

		if stateValues.isLeftArmSupportEnabled then
			local leftSupportCFrame = getLeftSupportCFrame(controller)
			local neutralLeftShoulderC0 = getLeftShoulderSupportTarget(
				controller,
				shoulders.defaultLeftC0,
				shoulders.defaultRightC0,
				neutralRightShoulderC0,
				leftSupportCFrame
			)
			local calculatedLeftShoulderC0 = getLeftShoulderSupportTarget(
				controller,
				shoulders.defaultLeftC0,
				shoulders.defaultRightC0,
				shoulders.currentRightC0,
				leftSupportCFrame
			)

			if stateValues.isCameraRelative and isFirstPerson then
				calculatedLeftShoulderC0 = getCameraRelativeShoulderTarget(controller, camera, neutralLeftShoulderC0)

				local aimCorrection = getCameraRelativeAimCorrection(controller, camera, calculatedRightShoulderC0)
				if aimCorrection ~= nil then
					calculatedRightShoulderC0 =
						applyCameraRelativeAimCorrection(controller, aimCorrection, calculatedRightShoulderC0)
					calculatedLeftShoulderC0 =
						applyCameraRelativeAimCorrection(controller, aimCorrection, calculatedLeftShoulderC0)
				end
			end

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
