local lensFlareConfig = {
	raycast = {
		--// More rays smooth the occlusion fade at a higher per-frame cost.
		rayCount = 7,
		radiusPixels = 7,
		transparencyThreshold = 0.666,
	},

	sun = {
		distanceStuds = 5000,
		flareStrength = 0.1,
		partTransparency = 0.5,
		angleThresholdDegrees = 30,
		brightnessThreshold = 1,
		exposureAdjustment = -5,
		exposureMultiplier = 1.5,
		exposureSmoothTimeSeconds = 1.25,
	},
}

return lensFlareConfig
