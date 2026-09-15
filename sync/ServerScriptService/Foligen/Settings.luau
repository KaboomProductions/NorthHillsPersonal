local generationTypes = require(script.Parent.Core.GenerationType).generationTypes

local settings = {
	runtime = {
		seed = -1732437937,
		generation = {
			batchSize = 128,
			yieldAfterBatches = 1,
		},
		output = {
			path = {
				"workspace",
				"Foligen",
			},
			clearExistingBeforeGenerate = true,
			generatedAttributeName = "GeneratedFoliage",
		},
	},
	world = {
		cornerA = Vector3.new(-1280.4, 19.9, -1331.6),
		cornerB = Vector3.new(1280.4, 257.8, 1331.6),
		raycastDownMultiplier = 10,
	},
	placement = {
		generationType = generationTypes.grid,
		minSpacing = 8.3,
		padding = 8.5,
		verticalOffset = -1.3,
		overlapCheckHeight = 12,
		maxPlacementAttempts = 16,
		minDistanceFromNonIgnoredPart = 5,
		minDistanceFromNonAllowedMaterial = 6,
		gridJitterAlpha = 0.75,
		noise = {
			enabled = true,
			scale = 150,
			contrast = 0.5,
			seedOffset = 0,
			candidateAttempts = 32,
			densityBias = 0,
		},
	},
	scaling = {
		min = 0.8,
		max = 1.25,
	},
	filters = {
		allowedMaterials = {
			Enum.Material.Grass,
			Enum.Material.Snow,
			Enum.Material.Glacier,
			Enum.Material.Ice,
			Enum.Material.LeafyGrass,
		},
		ignoreTags = {
			"ForestGenIgnore",
			"Foliage",
		},
	},
	assets = {
		tag = "FoligenAssets",
		Bushes = {
			amount = 5000,
			generationPriority = 2,
		},
		Flowers = {
			amount = 5000,
			generationPriority = 102,
		},
		Stumps = {
			amount = 100,
			generationPriority = 3,
		},
		Trees = {
			amount = 12500,
			generationPriority = 1,
		},
	},
}

return settings
