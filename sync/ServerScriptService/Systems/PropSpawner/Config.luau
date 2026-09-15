local propSpawnerSettings = {
	placeholder = {
		tagName = "PropSpawn",
		classAttributeName = "Class",
	},
	prefab = {
		folderName = "Props",
		attributeNames = {
			shouldInheritSpawnerSize = "ShouldInheritSpawnerSize",
			randomRotationIntervalsDegrees = "RandomRotationIntervalsDegrees",
		},
	},
	variationSelection = {
		influenceRadiusStuds = 60,
		influenceFalloffPower = 2,
		tieToleranceThreshold = 0.0001,
	},
}

return propSpawnerSettings
