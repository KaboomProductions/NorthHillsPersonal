--||------------------------------------------------------------------||
--||                      Foligen Module | Types                      ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Defines shared Luau types for generation settings and reports.  ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local types = {}

--//-- Placement noise --

export type noiseSettings = {
	enabled: boolean,
	scale: number,
	contrast: number,
	seedOffset: number,
	candidateAttempts: number,
	densityBias: number,
}

--//-- Placement --

export type placementSettings = {
	generationType: string,
	minSpacing: number,
	padding: number,
	verticalOffset: number,
	overlapCheckHeight: number,
	maxPlacementAttempts: number,
	minDistanceFromNonIgnoredPart: number,
	minDistanceFromNonAllowedMaterial: number,
	gridJitterAlpha: number,
	noise: noiseSettings,
	materialCheckRadius: number?,
	materialCheckSamples: number?,
}

--//-- Generation type state --

export type generationTypeState = {
	typeName: string,
	[string]: any,
}

--//-- Scaling --

export type scalingSettings = {
	min: number,
	max: number,
}

--//-- Filters --

export type filterSettings = {
	allowedMaterials: { [Enum.Material]: boolean },
	ignoreTags: { string },
	ignoreTagSet: { [string]: boolean },
}

--//-- Per-set asset config --

export type assetSetConfig = {
	amount: number,
	generationPriority: number,
	settings: { [string]: any }?,
}

export type assetSettings = {
	path: { string }?,
	[string]: any,
}

--//-- Generation batch controls --

export type generationBatchSettings = {
	batchSize: number,
	yieldAfterBatches: number,
}

--//-- Output --

export type outputSettings = {
	path: { string },
	clearExistingBeforeGenerate: boolean,
	generatedAttributeName: string,
}

--//-- Runtime --

export type runtimeSettings = {
	seed: number?,
	assetsFolder: Folder?,
	generation: generationBatchSettings,
	output: outputSettings,
	random: Random,
}

--//-- World --

export type worldSettings = {
	cornerA: Vector3,
	cornerB: Vector3,
	raycastDownMultiplier: number,
	minimumCorner: Vector3,
	maximumCorner: Vector3,
	size: Vector3,
	width: number,
	height: number,
	depth: number,
}

--//-- Top-level normalized settings --

export type generationSettings = {
	runtime: runtimeSettings,
	world: worldSettings,
	placement: placementSettings,
	scaling: scalingSettings,
	filters: filterSettings,
	assets: assetSettings,
}

--//-- Generation set definition --

export type generationSetDefinition = {
	name: string,
	templates: { Model },
	amount: number,
	generationPriority: number,
	settings: { [string]: any }?,
}

--//-- Reports --

export type generationSetReport = {
	placedCount: number,
	attemptedCount: number,
}

export type generationReport = {
	placedCount: number,
	attemptedCount: number,
	setReports: { [string]: generationSetReport },
	durationSeconds: number,
}

--//-- Placement query context --

export type queryContext = {
	raycastParams: RaycastParams,
	overlapParams: OverlapParams,
	nearbyPartsParams: OverlapParams,
}

return types
