--||------------------------------------------------------------------||
--||                    Foligen Module | Placement                    ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Validates candidate positions and places generated models.      ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local collectionService = game:GetService("CollectionService")

local assetLibrary = require(script.Parent.AssetLibrary)
local generationTypeModule = require(script.Parent.GenerationType)
local spatialHashModule = require(script.Parent.SpatialHash)
local typesModule = require(script.Parent.Types)

local placement = {}

local function hasIgnoredTag(instance: Instance, ignoreTagSet: { [string]: boolean }): boolean
	for _, tag in ipairs(collectionService:GetTags(instance)) do
		if ignoreTagSet[tag] then
			return true
		end
	end

	return false
end

local function shouldEvaluateNearbyPart(part: Instance): boolean
	return part:IsA("BasePart") and part.CanCollide
end

local function isBlocked(
	surfaceInstance: Instance?,
	position: Vector3,
	context: typesModule.queryContext,
	generationSettings: typesModule.generationSettings
): boolean
	local paddingSize = generationSettings.placement.padding
	local overlapCheckHeight = generationSettings.placement.overlapCheckHeight
	local overlapCenter = position + Vector3.new(0, overlapCheckHeight * 0.5, 0)
	local overlappingParts = workspace:GetPartBoundsInBox(
		CFrame.new(overlapCenter),
		Vector3.new(paddingSize * 2, overlapCheckHeight, paddingSize * 2),
		context.overlapParams
	)

	for _, part in ipairs(overlappingParts) do
		if not shouldEvaluateNearbyPart(part) then
			continue
		end

		if surfaceInstance ~= nil and part == surfaceInstance then
			continue
		end

		if not hasIgnoredTag(part, generationSettings.filters.ignoreTagSet) then
			return true
		end
	end

	return false
end

local function isTooCloseToNonIgnoredPart(
	surfaceInstance: Instance?,
	position: Vector3,
	context: typesModule.queryContext,
	generationSettings: typesModule.generationSettings
): boolean
	local minimumDistance = generationSettings.placement.minDistanceFromNonIgnoredPart
	if minimumDistance <= 0 then
		return false
	end

	local nearbyParts = workspace:GetPartBoundsInRadius(position, minimumDistance, context.nearbyPartsParams)
	for _, part in ipairs(nearbyParts) do
		if not shouldEvaluateNearbyPart(part) then
			continue
		end

		if surfaceInstance ~= nil and part == surfaceInstance then
			continue
		end

		if not hasIgnoredTag(part, generationSettings.filters.ignoreTagSet) then
			return true
		end
	end

	return false
end

local function isAllowedGroundHit(
	raycastResult: RaycastResult?,
	generationSettings: typesModule.generationSettings
): boolean
	return raycastResult ~= nil and generationSettings.filters.allowedMaterials[raycastResult.Material] == true
end

local function isDisallowedGroundHit(
	raycastResult: RaycastResult?,
	generationSettings: typesModule.generationSettings
): boolean
	return raycastResult ~= nil and generationSettings.filters.allowedMaterials[raycastResult.Material] ~= true
end

local function isTooCloseToNonAllowedMaterial(
	position: Vector3,
	context: typesModule.queryContext,
	generationSettings: typesModule.generationSettings
): boolean
	local minimumDistance = generationSettings.placement.minDistanceFromNonAllowedMaterial
	if minimumDistance <= 0 then
		return false
	end

	local downwardSearchDistance =
		math.max(1, generationSettings.world.height * math.max(1, generationSettings.world.raycastDownMultiplier))
	local rayDirection = Vector3.new(0, -downwardSearchDistance, 0)
	local candidateHeight = generationSettings.world.maximumCorner.Y
	local baseSampleCount = math.max(8, math.floor(tonumber(generationSettings.placement.materialCheckSamples) or 10))
	local ringCount = math.max(2, math.ceil(minimumDistance / 4))
	local fullRotationRadians = math.pi * 2

	for ringIndex = 1, ringCount do
		local ringRadius = minimumDistance * (ringIndex / ringCount)
		local circumference = fullRotationRadians * ringRadius
		local sampleCount = math.max(baseSampleCount, math.ceil(circumference / 4))

		for sampleIndex = 1, sampleCount do
			local angleRadians = fullRotationRadians * ((sampleIndex - 1) / sampleCount)
			local offset = Vector3.new(math.cos(angleRadians) * ringRadius, 0, math.sin(angleRadians) * ringRadius)
			local rayOrigin = Vector3.new(position.X + offset.X, candidateHeight, position.Z + offset.Z)
			local sampleResult = workspace:Raycast(rayOrigin, rayDirection, context.raycastParams)
			if isDisallowedGroundHit(sampleResult, generationSettings) then
				return true
			end
		end
	end

	return false
end

local function getGroundCoverage(
	position: Vector3,
	context: typesModule.queryContext,
	generationSettings: typesModule.generationSettings
): (boolean, number)
	local placementConfig = generationSettings.placement
	local materialCheckRadius = tonumber(placementConfig.materialCheckRadius) or 0
	if materialCheckRadius <= 0 then
		return true, position.Y
	end

	local materialCheckSamples = math.max(1, math.floor(tonumber(placementConfig.materialCheckSamples) or 8))
	local downwardSearchDistance =
		math.max(1, generationSettings.world.height * math.max(1, generationSettings.world.raycastDownMultiplier))
	local rayDirection = Vector3.new(0, -downwardSearchDistance, 0)
	local candidateHeight = generationSettings.world.maximumCorner.Y
	local highestGroundY = position.Y

	local centerRayOrigin = Vector3.new(position.X, candidateHeight, position.Z)
	local centerResult = workspace:Raycast(centerRayOrigin, rayDirection, context.raycastParams)
	if not isAllowedGroundHit(centerResult, generationSettings) then
		return false, position.Y
	end

	local ringRadii = { materialCheckRadius * 0.4, materialCheckRadius }
	local fullRotationRadians = math.pi * 2

	for _, ringRadius in ipairs(ringRadii) do
		for sampleIndex = 1, materialCheckSamples do
			local angleRadians = fullRotationRadians * ((sampleIndex - 1) / materialCheckSamples)
			local offset = Vector3.new(math.cos(angleRadians) * ringRadius, 0, math.sin(angleRadians) * ringRadius)
			local rayOrigin = centerRayOrigin + offset
			local sampleResult = workspace:Raycast(rayOrigin, rayDirection, context.raycastParams)
			if not isAllowedGroundHit(sampleResult, generationSettings) then
				return false, position.Y
			end

			if sampleResult.Position.Y > highestGroundY then
				highestGroundY = sampleResult.Position.Y
			end
		end
	end

	return true, highestGroundY
end

function placement.createQueryContext(outputRoot: Instance): typesModule.queryContext
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	raycastParams.FilterDescendantsInstances = { outputRoot }

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { outputRoot }

	local nearbyPartsParams = OverlapParams.new()
	nearbyPartsParams.FilterType = Enum.RaycastFilterType.Exclude
	nearbyPartsParams.FilterDescendantsInstances = { outputRoot }

	return {
		raycastParams = raycastParams,
		overlapParams = overlapParams,
		nearbyPartsParams = nearbyPartsParams,
	}
end

function placement.findPlacementPosition(
	placementIndex: number,
	typeState: typesModule.generationTypeState,
	context: typesModule.queryContext,
	positionSpatialHash: spatialHashModule.spatialHashInstance,
	generationSettings: typesModule.generationSettings
): Vector3?
	local maxPlacementAttempts = generationSettings.placement.maxPlacementAttempts

	local noiseSettings = generationSettings.placement.noise
	local noiseEnabled = noiseSettings and noiseSettings.enabled
	local noiseScale = noiseEnabled and (noiseSettings.scale or 150) or 0
	local noiseContrast = noiseEnabled and (noiseSettings.contrast or 0.5) or 0
	local noiseSeedOffset = noiseEnabled and (noiseSettings.seedOffset or 0) or 0
	local noiseDensityBias = noiseEnabled and (noiseSettings.densityBias or 0) or 0
	local noiseMinDensity = 1 - noiseContrast
	local random = generationSettings.runtime.random

	for attemptIndex = 1, maxPlacementAttempts do
		local candidatePosition =
			generationTypeModule.generateCandidate(typeState, placementIndex, attemptIndex, generationSettings)

		if noiseEnabled then
			local noiseValue = math.noise(
				candidatePosition.X / noiseScale + noiseSeedOffset,
				candidatePosition.Z / noiseScale + noiseSeedOffset
			)

			local normalizedNoise = math.clamp(noiseValue + 0.5 + noiseDensityBias, 0, 1)
			local density = noiseMinDensity + normalizedNoise * noiseContrast

			if random:NextNumber() > density then
				continue
			end
		end

		local downwardSearchDistance =
			math.max(1, generationSettings.world.height * math.max(1, generationSettings.world.raycastDownMultiplier))
		local rayDirection = Vector3.new(0, -downwardSearchDistance, 0)
		local raycastResult = workspace:Raycast(candidatePosition, rayDirection, context.raycastParams)

		if raycastResult == nil or not generationSettings.filters.allowedMaterials[raycastResult.Material] then
			continue
		end

		local hitPosition = raycastResult.Position
		if
			hitPosition.Y < generationSettings.world.minimumCorner.Y
			or hitPosition.Y > generationSettings.world.maximumCorner.Y
		then
			continue
		end

		if positionSpatialHash:hasNearbyPosition(hitPosition, generationSettings.placement.minSpacing) then
			continue
		end

		if isBlocked(raycastResult.Instance, hitPosition, context, generationSettings) then
			continue
		end

		if isTooCloseToNonIgnoredPart(raycastResult.Instance, hitPosition, context, generationSettings) then
			continue
		end

		if isTooCloseToNonAllowedMaterial(hitPosition, context, generationSettings) then
			continue
		end

		local hasCoverage, highestGroundY = getGroundCoverage(hitPosition, context, generationSettings)
		if not hasCoverage then
			continue
		end

		return Vector3.new(hitPosition.X, math.max(hitPosition.Y, highestGroundY), hitPosition.Z)
	end

	return nil
end

function placement.placeTemplate(
	template: Model,
	position: Vector3,
	parentFolder: Instance,
	generationSettings: typesModule.generationSettings
): Model
	local clonedModel = assetLibrary.prepareClone(template, generationSettings.filters.ignoreTags)
	local random = generationSettings.runtime.random
	local scaleRange = generationSettings.scaling.max - generationSettings.scaling.min
	local scale = generationSettings.scaling.min + (random:NextNumber() * scaleRange)
	local yawRadians = math.rad(random:NextNumber(-180, 180))
	local scaledVerticalOffset = generationSettings.placement.verticalOffset * scale
	local placementCFrame = CFrame.new(position + Vector3.new(0, scaledVerticalOffset, 0))
		* CFrame.Angles(0, yawRadians, 0)

	clonedModel:ScaleTo(scale)
	clonedModel:PivotTo(placementCFrame)
	clonedModel.Parent = parentFolder

	return clonedModel
end

return placement
