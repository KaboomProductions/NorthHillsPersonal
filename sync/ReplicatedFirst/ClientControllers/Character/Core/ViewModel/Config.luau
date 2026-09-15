local config = {
	renderStepName = "updateViewModel",
	renderPriority = Enum.RenderPriority.Character.Value + 1,
	frameRate = 60,
	positionEpsilon = 1e-4,
	angleEpsilonRadians = math.rad(0.25),

	movementSpeedThreshold = 6,
	recentMovementDurationSeconds = 2,
	idleReturnAlpha = 0.05,

	armFollowAlpha = {
		base = 0.3,
		recentMovement = 0.25,
	},

	armFollow = {
		blendDurationSeconds = 0.2,
	},

	lookClampRadians = {
		horizontalMinimum = 0,
		horizontalMaximum = math.rad(15),
		verticalMinimum = math.rad(-15),
		verticalMaximum = 0,
	},

	rightArm = {
		baseOffset = Vector3.zero,

		firstPersonViewmodel = {
			maximumLookUpRadians = math.rad(70),
			maximumLookDownRadians = math.rad(55),
			lookUpPitchScale = 0.55,
			lookDownPitchScale = 0.85,
			lookUpOffset = Vector3.zero,
			lookDownOffset = Vector3.zero,
		},

		firstPersonTurnResponse = {
			turnDepthAlpha = 0.35,
			turnLateralAlpha = 0.25,
			turnDepthStuds = 2,
			turnLateralStuds = 2,
			overshootSlideFactor = 1.5,
			verticalOvershootHeightScale = 0.2,
			maximumVerticalOvershootRadians = math.rad(90),
		},
	},

	leftArm = {
		supportOffset = Vector3.zero,
		supportRotationRadians = Vector3.zero,
	},

	handFollow = {
		rightGripName = "RightGrip",
		delaySeconds = 1,
		blendDurationSeconds = 0.25,
		lerpAlpha = 0.15,

		rotationLimitsRadians = {
			xMinimum = math.rad(-45),
			xMaximum = math.rad(45),
			yMinimum = math.rad(-45),
			yMaximum = math.rad(45),
			zMinimum = math.rad(-45),
			zMaximum = math.rad(45),
		},
	},
}

return config
