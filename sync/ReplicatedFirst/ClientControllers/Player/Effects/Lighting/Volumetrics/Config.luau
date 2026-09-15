local volumetricsConfig = {
	performance = {
		maximumVolumeLayers = 80,
		fieldOfViewRefreshThresholdDegrees = 0.5,
		viewportRefreshThresholdPixels = 2,
	},

	renderStep = {
		name = "Volumetrics",
		priorityOffset = 8,
	},

	defaults = {
		lightEmission = 1,
		renderMethodName = "Beams",
		spacingStuds = 1.25,
		transparency = 0.99,
		isVisible = true,
		volumeLayers = 80,
	},

	cameraAnchor = {
		defaultSizeStuds = Vector3.new(1, 1, 1),
		particleSizeStuds = Vector3.new(150, 150, 1),
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
	},

	beam = {
		color = Color3.new(0.8, 0.8, 0.8),
		widthMultiplier = 2,
		horizontalPaddingMultiplier = 1.15,
	},

	billboard = {
		framePaddingPixels = 100,
	},

	particles = {
		fadeDelaySeconds = 10,
		fadeDurationSeconds = 1,
		resetTimeScale = 1,
		skyCullLookY = 0.55,
		skyRestoreLookY = 0.5,
	},

	trail = {
		lifetimeSeconds = 0.016,
		offsetStuds = 20,
		horizontalPaddingMultiplier = 1.15,
	},
}

return volumetricsConfig
