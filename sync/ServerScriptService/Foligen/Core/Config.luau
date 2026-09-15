--||------------------------------------------------------------------||
--||                     Foligen Module | Config                      ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Normalizes, validates, and resolves generation configuration.   ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local typesModule = require(script.Parent.Types)

local collectionService = game:GetService("CollectionService")

local configModule = {}

local function deepCopy(sourceValue: any): any
	if type(sourceValue) ~= "table" then
		return sourceValue
	end

	local copy = {}
	for sourceKey, nestedValue in pairs(sourceValue) do
		copy[sourceKey] = deepCopy(nestedValue)
	end

	return copy
end

local function deepMerge(baseTable: { [string]: any }, overrideTable: { [string]: any }): { [string]: any }
	local mergedTable = deepCopy(baseTable)

	for overrideKey, overrideValue in pairs(overrideTable) do
		if type(overrideValue) == "table" and type(mergedTable[overrideKey]) == "table" then
			mergedTable[overrideKey] = deepMerge(mergedTable[overrideKey], overrideValue)
		else
			mergedTable[overrideKey] = deepCopy(overrideValue)
		end
	end

	return mergedTable
end

configModule.deepCopy = deepCopy
configModule.deepMerge = deepMerge

local function resolveTaggedFolder(tagName: string): Folder?
	for _, taggedInstance in collectionService:GetTagged(tagName) do
		if taggedInstance:IsA("Folder") then
			return taggedInstance
		end
	end

	return nil
end

local function normalizeMaterialSet(allowedMaterials: any): { [Enum.Material]: boolean }
	local materialSet = {}

	if type(allowedMaterials) ~= "table" then
		return materialSet
	end

	local hasArrayEntries = #allowedMaterials > 0
	if hasArrayEntries then
		for _, material in ipairs(allowedMaterials) do
			if typeof(material) == "EnumItem" then
				materialSet[material :: Enum.Material] = true
			end
		end
		return materialSet
	end

	for material, isEnabled in pairs(allowedMaterials) do
		if typeof(material) == "EnumItem" and isEnabled == true then
			materialSet[material :: Enum.Material] = true
		end
	end

	return materialSet
end

local function normalizeStringArray(inputStrings: any): { string }
	local normalizedStrings = {}

	if type(inputStrings) ~= "table" then
		return normalizedStrings
	end

	for _, entry in ipairs(inputStrings) do
		if type(entry) == "string" then
			table.insert(normalizedStrings, entry)
		end
	end

	return normalizedStrings
end

local function normalizeStringSet(inputStrings: any): { [string]: boolean }
	local normalizedStringSet = {}

	if type(inputStrings) ~= "table" then
		return normalizedStringSet
	end

	for _, entry in ipairs(inputStrings) do
		if type(entry) == "string" and entry ~= "" then
			normalizedStringSet[entry] = true
		end
	end

	return normalizedStringSet
end

local function normalizeAssetSets(assetSettings: any): { [string]: { [string]: any } }
	local normalizedAssetSets = {}

	if type(assetSettings) ~= "table" then
		return normalizedAssetSets
	end

	for setName, setConfig in pairs(assetSettings) do
		if setName == "path" or setName == "tag" then
			continue
		end

		if type(setName) ~= "string" or type(setConfig) ~= "table" then
			continue
		end

		local normalizedSetConfig = deepCopy(setConfig)

		if type(normalizedSetConfig.amount) == "number" then
			normalizedSetConfig.amount = math.max(0, math.floor(normalizedSetConfig.amount))
		else
			normalizedSetConfig.amount = 0
		end

		if type(normalizedSetConfig.generationPriority) == "number" then
			normalizedSetConfig.generationPriority = math.floor(normalizedSetConfig.generationPriority)
		else
			normalizedSetConfig.generationPriority = 0
		end

		normalizedAssetSets[setName] = normalizedSetConfig
	end

	return normalizedAssetSets
end

local function normalizePathArray(pathSegments: any, fallbackPathSegments: { string }): { string }
	local normalizedPathSegments = {}

	if type(pathSegments) ~= "table" then
		return deepCopy(fallbackPathSegments)
	end

	for _, pathSegment in ipairs(pathSegments) do
		if type(pathSegment) == "string" and pathSegment ~= "" then
			table.insert(normalizedPathSegments, pathSegment)
		end
	end

	if #normalizedPathSegments == 0 then
		return deepCopy(fallbackPathSegments)
	end

	return normalizedPathSegments
end

local function normalizeGenerationCorner(inputCorner: any, fallbackCorner: Vector3): Vector3
	if typeof(inputCorner) == "Vector3" then
		return inputCorner
	end

	return fallbackCorner
end

local function clampPositiveNumber(inputNumber: any, fallbackNumber: number): number
	if type(inputNumber) ~= "number" or inputNumber <= 0 then
		return fallbackNumber
	end

	return inputNumber
end

local function clampNonNegativeNumber(inputNumber: any, fallbackNumber: number): number
	if type(inputNumber) ~= "number" or inputNumber < 0 then
		return fallbackNumber
	end

	return inputNumber
end

function configModule.normalize(
	defaultSettings: { [string]: any },
	customSettings: { [string]: any }?
): typesModule.generationSettings
	local normalizedSettings = deepCopy(defaultSettings)

	if type(customSettings) == "table" then
		normalizedSettings = deepMerge(normalizedSettings, customSettings)
	end

	if typeof(normalizedSettings.runtime.assetsFolder) == "Instance" then
		if not normalizedSettings.runtime.assetsFolder:IsA("Folder") then
			warn("Foligen | runtime.assetsFolder is not a Folder; generation may fail")
		end
	elseif type(normalizedSettings.assets) == "table" and type(normalizedSettings.assets.tag) == "string" then
		normalizedSettings.runtime.assetsFolder = resolveTaggedFolder(normalizedSettings.assets.tag)
	end

	normalizedSettings.runtime.generation = type(normalizedSettings.runtime.generation) == "table"
			and normalizedSettings.runtime.generation
		or {}
	normalizedSettings.runtime.generation.batchSize =
		math.max(1, math.floor(clampPositiveNumber(normalizedSettings.runtime.generation.batchSize, 128)))
	normalizedSettings.runtime.generation.yieldAfterBatches =
		math.max(1, math.floor(clampPositiveNumber(normalizedSettings.runtime.generation.yieldAfterBatches, 1)))

	normalizedSettings.runtime.output = type(normalizedSettings.runtime.output) == "table"
			and normalizedSettings.runtime.output
		or {}
	normalizedSettings.runtime.output.path = normalizePathArray(normalizedSettings.runtime.output.path, {
		"workspace",
		"Foligen",
	})

	if #normalizedSettings.runtime.output.path < 2 then
		warn(
			"Foligen | runtime.output.path should have at least two segments to avoid targeting a root service directly"
		)
	end

	normalizedSettings.runtime.output.generatedAttributeName = type(
		normalizedSettings.runtime.output.generatedAttributeName
	) == "string" and normalizedSettings.runtime.output.generatedAttributeName or "GeneratedFoliage"
	normalizedSettings.runtime.seed = type(normalizedSettings.runtime.seed) == "number"
			and math.floor(normalizedSettings.runtime.seed)
		or nil

	normalizedSettings.world.cornerA =
		normalizeGenerationCorner(normalizedSettings.world.cornerA, Vector3.new(-1022, -500, -1022))
	normalizedSettings.world.cornerB =
		normalizeGenerationCorner(normalizedSettings.world.cornerB, Vector3.new(1022, 500, 1022))
	normalizedSettings.world.raycastDownMultiplier =
		clampPositiveNumber(normalizedSettings.world.raycastDownMultiplier, 2)

	local validGenerationTypes = { grid = true, noise = true, pureRandom = true }
	if
		type(normalizedSettings.placement.generationType) ~= "string"
		or not validGenerationTypes[normalizedSettings.placement.generationType]
	then
		normalizedSettings.placement.generationType = "grid"
	end

	normalizedSettings.placement.minSpacing = clampPositiveNumber(normalizedSettings.placement.minSpacing, 1)
	normalizedSettings.placement.padding = clampPositiveNumber(normalizedSettings.placement.padding, 3)
	normalizedSettings.placement.verticalOffset = tonumber(normalizedSettings.placement.verticalOffset) or 0
	normalizedSettings.placement.overlapCheckHeight =
		clampPositiveNumber(normalizedSettings.placement.overlapCheckHeight, 12)
	normalizedSettings.placement.maxPlacementAttempts =
		math.max(1, math.floor(clampPositiveNumber(normalizedSettings.placement.maxPlacementAttempts, 5)))
	normalizedSettings.placement.minDistanceFromNonIgnoredPart =
		clampNonNegativeNumber(normalizedSettings.placement.minDistanceFromNonIgnoredPart, 0)
	normalizedSettings.placement.minDistanceFromNonAllowedMaterial =
		clampNonNegativeNumber(normalizedSettings.placement.minDistanceFromNonAllowedMaterial, 0)
	normalizedSettings.placement.gridJitterAlpha =
		math.clamp(tonumber(normalizedSettings.placement.gridJitterAlpha) or 0.5, 0, 1)

	if type(normalizedSettings.placement.noise) ~= "table" then
		normalizedSettings.placement.noise = {
			enabled = false,
			scale = 150,
			contrast = 0.5,
			seedOffset = 0,
			candidateAttempts = 32,
			densityBias = 0,
		}
	else
		local noiseTable = normalizedSettings.placement.noise
		noiseTable.enabled = noiseTable.enabled == true
		noiseTable.scale = clampPositiveNumber(noiseTable.scale, 150)
		noiseTable.contrast = math.clamp(tonumber(noiseTable.contrast) or 0.5, 0, 1)
		noiseTable.seedOffset = tonumber(noiseTable.seedOffset) or 0
		noiseTable.candidateAttempts = math.max(1, math.floor(clampPositiveNumber(noiseTable.candidateAttempts, 32)))
		noiseTable.densityBias = math.clamp(tonumber(noiseTable.densityBias) or 0, -0.5, 0.5)
	end

	normalizedSettings.scaling.min = clampPositiveNumber(normalizedSettings.scaling.min, 0.8)
	normalizedSettings.scaling.max = clampPositiveNumber(normalizedSettings.scaling.max, 1.4)
	if normalizedSettings.scaling.max < normalizedSettings.scaling.min then
		normalizedSettings.scaling.max = normalizedSettings.scaling.min
	end

	normalizedSettings.filters.allowedMaterials = normalizeMaterialSet(normalizedSettings.filters.allowedMaterials)
	normalizedSettings.filters.ignoreTags = normalizeStringArray(normalizedSettings.filters.ignoreTags)
	normalizedSettings.filters.ignoreTagSet = normalizeStringSet(normalizedSettings.filters.ignoreTags)

	normalizedSettings.assets = normalizeAssetSets(normalizedSettings.assets)

	normalizedSettings.world.minimumCorner = Vector3.new(
		math.min(normalizedSettings.world.cornerA.X, normalizedSettings.world.cornerB.X),
		math.min(normalizedSettings.world.cornerA.Y, normalizedSettings.world.cornerB.Y),
		math.min(normalizedSettings.world.cornerA.Z, normalizedSettings.world.cornerB.Z)
	)
	normalizedSettings.world.maximumCorner = Vector3.new(
		math.max(normalizedSettings.world.cornerA.X, normalizedSettings.world.cornerB.X),
		math.max(normalizedSettings.world.cornerA.Y, normalizedSettings.world.cornerB.Y),
		math.max(normalizedSettings.world.cornerA.Z, normalizedSettings.world.cornerB.Z)
	)
	normalizedSettings.world.size = normalizedSettings.world.maximumCorner - normalizedSettings.world.minimumCorner
	normalizedSettings.world.width = normalizedSettings.world.size.X
	normalizedSettings.world.height = normalizedSettings.world.size.Y
	normalizedSettings.world.depth = normalizedSettings.world.size.Z

	if normalizedSettings.world.width <= 0 or normalizedSettings.world.depth <= 0 then
		warn("Foligen | World bounds define a zero-size region; cornerA and cornerB may overlap")
	end

	local materialCount = 0
	for _ in pairs(normalizedSettings.filters.allowedMaterials) do
		materialCount += 1
	end
	if materialCount == 0 then
		warn("Foligen | No allowed materials; all placement raycasts will be rejected")
	end

	if normalizedSettings.placement.minSpacing > normalizedSettings.placement.padding then
		warn("Foligen | minSpacing exceeds padding; placement may fail more often than expected")
	end

	normalizedSettings.runtime.output.clearExistingBeforeGenerate = normalizedSettings.runtime.output.clearExistingBeforeGenerate
		== true

	if normalizedSettings.runtime.seed == nil then
		normalizedSettings.runtime.random = Random.new()
	else
		normalizedSettings.runtime.random = Random.new(normalizedSettings.runtime.seed)
	end

	return normalizedSettings :: any
end

return configModule
