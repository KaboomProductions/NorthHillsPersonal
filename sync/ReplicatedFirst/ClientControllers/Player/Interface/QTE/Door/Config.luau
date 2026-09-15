local doorConfig = {
	mouseSensitivity = 1.5,

	kickDistance = 0.35,

	kickScreenShakeIntensity = 0.012,
	kickScreenShakeDecay = 8,
	kickCameraShakeIntensity = 0.03,
	kickCameraShakeTranslation = 0.15,
	kickFovBump = 7,
	kickDrain = 0.1,

	pressurePushSpeed = 0.28,
	pressureShakeIntensity = 0.003,
	pressureJitterMultiplier = 4,
	pressureDrainSpeed = 0.06,

	jitterIntensity = 0.006,
	jitterSpeed = 25,
	swayIntensity = 0.02,
	swaySpeed = 3,

	driftIntensity = 0.15,
	driftSpeed = 2.5,

	maxOffset = 0.42,
	hexagonThreshold = 0.068,

	hexagonKickScaleMin = 0.52,
	hexagonKickScaleMax = 1.68,
	hexagonScaleLerpSpeed = 8,
	hexagonScaleReturnSpeed = 3,
	hexagonRotationMaxDegrees = 25,
	hexagonRotationLerpSpeed = 10,
	hexagonRotationReturnSpeed = 5,
	showDetectionDebugVisualizer = false,

	maxFillSpeed = 0.25,
	minFillSpeed = 0.025,
	drainSpeed = 0.45,
	barSmoothSpeed = 6,
	fillSegments = 4,
}

return doorConfig
