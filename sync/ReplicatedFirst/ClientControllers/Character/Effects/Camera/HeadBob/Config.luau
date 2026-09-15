local config = {
	stepsPerCycle = 2,

	verticalAmplitude = 0.6,
	lateralAmplitude = 0.35,
	rollAmplitude = 0.9,
	pitchAmplitude = 0.6,
	yawAmplitude = 1,

	--// Idle breathing sway — slow, subtle drift when standing still.
	idleVerticalAmplitude = 0.36,
	idleVerticalFrequency = 0.45,
	idleLateralAmplitude = 0.192,
	idleLateralFrequency = 0.3,
	idlePitchAmplitude = 0.72,
	idlePitchFrequency = 0.45,
	idleYawAmplitude = 0.42,
	idleYawFrequency = 0.2,

	referenceWalkSpeed = 16,

	amplitudeSmoothSpeed = 2,
	thirdPersonAmplitudeScale = 0.28,
	thirdPersonRotationScale = 0.35,

	offsetSmoothSpeed = 4,

	moveThreshold = 0.1,
}

return config
