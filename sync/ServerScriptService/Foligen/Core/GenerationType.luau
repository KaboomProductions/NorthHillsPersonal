--||------------------------------------------------------------------||
--||                 Foligen Module | GenerationType                  ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Produces candidate positions for each generation mode.          ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local typesModule = require(script.Parent.Types)

local generationType = {}

--//-- Enum of available generation types --

generationType.generationTypes = table.freeze({
	grid = "grid",
	noise = "noise",
	pureRandom = "pureRandom",
})

--//-- grid --
--// Grid cells with optional jitter (controlled by gridJitterAlpha)

local function initializeGrid(
	placementAmount: number,
	generationSettings: typesModule.generationSettings
): typesModule.generationTypeState
	local worldWidth = math.max(1, generationSettings.world.width)
	local worldDepth = math.max(1, generationSettings.world.depth)
	local aspectRatio = math.max(0.01, worldWidth / worldDepth)
	local gridCellsX = math.max(1, math.ceil(math.sqrt(placementAmount * aspectRatio)))
	local gridCellsZ = math.max(1, math.ceil(placementAmount / gridCellsX))

	return {
		typeName = "grid",
		gridCellsX = gridCellsX,
		gridCellsZ = gridCellsZ,
		cellSizeX = worldWidth / gridCellsX,
		cellSizeZ = worldDepth / gridCellsZ,
		totalCellCount = gridCellsX * gridCellsZ,
	}
end

local function generateGrid(
	placementIndex: number,
	attemptIndex: number,
	typeState: typesModule.generationTypeState,
	generationSettings: typesModule.generationSettings
): Vector3
	local gridCellsX = typeState.gridCellsX
	local cellSizeX = typeState.cellSizeX
	local cellSizeZ = typeState.cellSizeZ
	local totalCellCount = typeState.totalCellCount
	local wrappedCellIndex = ((placementIndex - 1) + (attemptIndex - 1) * totalCellCount) % totalCellCount
	local cellX = wrappedCellIndex % gridCellsX
	local cellZ = math.floor(wrappedCellIndex / gridCellsX)
	local minimumCorner = generationSettings.world.minimumCorner
	local maximumCorner = generationSettings.world.maximumCorner
	local jitterAlpha = generationSettings.placement.gridJitterAlpha

	local centerX = minimumCorner.X + (cellX + 0.5) * cellSizeX
	local centerZ = minimumCorner.Z + (cellZ + 0.5) * cellSizeZ

	if jitterAlpha > 0 then
		local random = generationSettings.runtime.random
		local jitterDistanceX = cellSizeX * jitterAlpha
		local jitterDistanceZ = cellSizeZ * jitterAlpha
		centerX =
			math.clamp(centerX + random:NextNumber(-jitterDistanceX, jitterDistanceX), minimumCorner.X, maximumCorner.X)
		centerZ =
			math.clamp(centerZ + random:NextNumber(-jitterDistanceZ, jitterDistanceZ), minimumCorner.Z, maximumCorner.Z)
	end

	return Vector3.new(centerX, maximumCorner.Y, centerZ)
end

--//-- noise --
--// Positions biased toward high Perlin-noise areas using rejection sampling

local function initializeNoise(
	_placementAmount: number,
	generationSettings: typesModule.generationSettings
): typesModule.generationTypeState
	local noiseConfig = generationSettings.placement.noise
	return {
		typeName = "noise",
		noiseScale = noiseConfig and noiseConfig.scale or 150,
		noiseSeedOffset = noiseConfig and noiseConfig.seedOffset or 0,
		noiseContrast = noiseConfig and noiseConfig.contrast or 0.5,
		noiseCandidateAttempts = noiseConfig and noiseConfig.candidateAttempts or 32,
		noiseDensityBias = noiseConfig and noiseConfig.densityBias or 0,
	}
end

local function generateNoise(
	_placementIndex: number,
	_attemptIndex: number,
	typeState: typesModule.generationTypeState,
	generationSettings: typesModule.generationSettings
): Vector3
	local random = generationSettings.runtime.random
	local minimumCorner = generationSettings.world.minimumCorner
	local maximumCorner = generationSettings.world.maximumCorner
	local noiseScale = typeState.noiseScale
	local noiseSeedOffset = typeState.noiseSeedOffset
	local noiseContrast = typeState.noiseContrast
	local noiseCandidateAttempts = typeState.noiseCandidateAttempts
	local noiseDensityBias = typeState.noiseDensityBias
	local noiseMinDensity = 1 - noiseContrast

	for _ = 1, noiseCandidateAttempts do
		local candidateX = random:NextNumber(minimumCorner.X, maximumCorner.X)
		local candidateZ = random:NextNumber(minimumCorner.Z, maximumCorner.Z)

		local noiseValue =
			math.noise(candidateX / noiseScale + noiseSeedOffset, candidateZ / noiseScale + noiseSeedOffset)
		local normalizedNoise = math.clamp(noiseValue + 0.5 + noiseDensityBias, 0, 1)
		local density = noiseMinDensity + normalizedNoise * noiseContrast

		if random:NextNumber() < density then
			return Vector3.new(candidateX, maximumCorner.Y, candidateZ)
		end
	end

	return Vector3.new(
		random:NextNumber(minimumCorner.X, maximumCorner.X),
		maximumCorner.Y,
		random:NextNumber(minimumCorner.Z, maximumCorner.Z)
	)
end

--//-- pureRandom --
--// Pure random positions across the world bounds

local function initializePureRandom(
	_placementAmount: number,
	_generationSettings: typesModule.generationSettings
): typesModule.generationTypeState
	return { typeName = "pureRandom" }
end

local function generatePureRandom(
	_placementIndex: number,
	_attemptIndex: number,
	_typeState: typesModule.generationTypeState,
	generationSettings: typesModule.generationSettings
): Vector3
	local random = generationSettings.runtime.random
	local minimumCorner = generationSettings.world.minimumCorner
	local maximumCorner = generationSettings.world.maximumCorner
	return Vector3.new(
		random:NextNumber(minimumCorner.X, maximumCorner.X),
		maximumCorner.Y,
		random:NextNumber(minimumCorner.Z, maximumCorner.Z)
	)
end

--//-- Type registry --

local typeRegistry = {
	grid = { initialize = initializeGrid, generate = generateGrid },
	noise = { initialize = initializeNoise, generate = generateNoise },
	pureRandom = { initialize = initializePureRandom, generate = generatePureRandom },
}

function generationType.isValidType(typeName: string): boolean
	return typeRegistry[typeName] ~= nil
end

function generationType.initializeState(
	typeName: string,
	placementAmount: number,
	generationSettings: typesModule.generationSettings
): typesModule.generationTypeState
	local typeEntry = typeRegistry[typeName]
	if typeEntry == nil then
		warn(("Foligen | Unknown generation type '%s'; falling back to grid"):format(tostring(typeName)))
		typeEntry = typeRegistry.grid
	end

	return typeEntry.initialize(placementAmount, generationSettings)
end

function generationType.generateCandidate(
	typeState: typesModule.generationTypeState,
	placementIndex: number,
	attemptIndex: number,
	generationSettings: typesModule.generationSettings
): Vector3
	local typeEntry = typeRegistry[typeState.typeName]
	if typeEntry == nil then
		typeEntry = typeRegistry.grid
	end

	return typeEntry.generate(placementIndex, attemptIndex, typeState, generationSettings)
end

return generationType
