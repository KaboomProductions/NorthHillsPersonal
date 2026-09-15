local collectionService = game:GetService("CollectionService")

local propSpawnerSettings = require(script.Parent.Config)

local placeholderSettings = propSpawnerSettings.placeholder
local prefabAttributeNames = propSpawnerSettings.prefab.attributeNames
local fullRotationDegrees = 360
local rotationStepTolerance = 0.0001

local prefabPlacement = {}

export type PlacementRequest = {
	placeholder: PVInstance,
	selectedPrefab: PVInstance,
	spawnedProp: PVInstance,
	randomGenerator: Random,
}

local function getPrefabAttribute(selectedPrefab: PVInstance, attributeName: string): unknown
	local directAttribute: unknown = selectedPrefab:GetAttribute(attributeName)
	if directAttribute ~= nil then
		return directAttribute
	end

	local prefabGroup = selectedPrefab.Parent
	if prefabGroup == nil then
		return nil
	end

	return prefabGroup:GetAttribute(attributeName)
end

local function shouldInheritSpawnerSize(selectedPrefab: PVInstance): boolean
	local configuredState = getPrefabAttribute(selectedPrefab, prefabAttributeNames.shouldInheritSpawnerSize)
	if configuredState == nil then
		return false
	end

	if type(configuredState) ~= "boolean" then
		error(
			("Prefab %s attribute %s must be a boolean"):format(
				selectedPrefab:GetFullName(),
				prefabAttributeNames.shouldInheritSpawnerSize
			)
		)
	end

	return configuredState
end

local function getRandomRotationIntervalsDegrees(selectedPrefab: PVInstance): Vector3?
	local configuredIntervals =
		getPrefabAttribute(selectedPrefab, prefabAttributeNames.randomRotationIntervalsDegrees)
	if configuredIntervals == nil then
		return nil
	end

	if typeof(configuredIntervals) ~= "Vector3" then
		error(
			("Prefab %s attribute %s must be a Vector3"):format(
				selectedPrefab:GetFullName(),
				prefabAttributeNames.randomRotationIntervalsDegrees
			)
		)
	end

	return configuredIntervals
end

local function isPrefabPlacementAttribute(attributeName: string): boolean
	return attributeName == prefabAttributeNames.shouldInheritSpawnerSize
		or attributeName == prefabAttributeNames.randomRotationIntervalsDegrees
end

local function copyPlaceholderAttributes(spawnedProp: PVInstance, placeholder: PVInstance)
	for attributeName, attributeState in pairs(placeholder:GetAttributes()) do
		if isPrefabPlacementAttribute(attributeName) then
			continue
		end

		spawnedProp:SetAttribute(attributeName, attributeState)
	end
end

local function copyPlaceholderTags(spawnedProp: PVInstance, placeholder: PVInstance)
	for _, tagName in ipairs(collectionService:GetTags(placeholder)) do
		if tagName == placeholderSettings.tagName then
			continue
		end

		collectionService:AddTag(spawnedProp, tagName)
	end
end

local function getBoundsSize(prop: PVInstance): Vector3
	if prop:IsA("BasePart") then
		return prop.Size
	end

	if prop:IsA("Model") then
		local _, boundsSize = prop:GetBoundingBox()
		return boundsSize
	end

	error(("Prop %s has unsupported class %s"):format(prop:GetFullName(), prop.ClassName))
end

local function resizeModelToSpawnerBounds(spawnedModel: Model, targetBoundsSize: Vector3)
	local prefabBoundsSize = getBoundsSize(spawnedModel)
	local hasEmptyBounds = prefabBoundsSize.X <= 0 or prefabBoundsSize.Y <= 0 or prefabBoundsSize.Z <= 0
	if hasEmptyBounds then
		error(("Prefab %s has empty bounds and cannot inherit a spawner size"):format(spawnedModel:GetFullName()))
	end

	local fitScaleMultiplier = math.min(
		targetBoundsSize.X / prefabBoundsSize.X,
		targetBoundsSize.Y / prefabBoundsSize.Y,
		targetBoundsSize.Z / prefabBoundsSize.Z
	)
	spawnedModel:ScaleTo(spawnedModel:GetScale() * fitScaleMultiplier)
end

local function resizePropToSpawnerBounds(spawnedProp: PVInstance, placeholder: PVInstance)
	local targetBoundsSize = getBoundsSize(placeholder)

	if spawnedProp:IsA("BasePart") then
		spawnedProp.Size = targetBoundsSize
		return
	end

	if spawnedProp:IsA("Model") then
		resizeModelToSpawnerBounds(spawnedProp, targetBoundsSize)
		return
	end

	error(("Prop %s has unsupported class %s"):format(spawnedProp:GetFullName(), spawnedProp.ClassName))
end

local function validateRotationInterval(rotationIntervalDegrees: number, axisName: string)
	local isFinite = rotationIntervalDegrees == rotationIntervalDegrees
	local isWithinRange = rotationIntervalDegrees >= 0 and rotationIntervalDegrees <= fullRotationDegrees
	if not isFinite or not isWithinRange then
		error(("%s rotation interval must be between 0 and 360 degrees"):format(axisName))
	end

	if rotationIntervalDegrees == 0 then
		return
	end

	local exactStepCount = fullRotationDegrees / rotationIntervalDegrees
	local nearestStepCount = math.round(exactStepCount)
	if math.abs(exactStepCount - nearestStepCount) > rotationStepTolerance then
		error(("%s rotation interval must divide evenly into 360 degrees"):format(axisName))
	end
end

local function getRandomAxisRotationRadians(randomGenerator: Random, rotationIntervalDegrees: number): number
	if rotationIntervalDegrees == 0 then
		return 0
	end

	local rotationStepCount = math.round(fullRotationDegrees / rotationIntervalDegrees)
	local selectedStep = randomGenerator:NextInteger(0, rotationStepCount - 1)
	return math.rad(selectedStep * rotationIntervalDegrees)
end

local function createRandomRotationOffset(
	randomGenerator: Random,
	rotationIntervalsDegrees: Vector3
): CFrame
	validateRotationInterval(rotationIntervalsDegrees.X, "X-axis")
	validateRotationInterval(rotationIntervalsDegrees.Y, "Y-axis")
	validateRotationInterval(rotationIntervalsDegrees.Z, "Z-axis")

	return CFrame.Angles(
		getRandomAxisRotationRadians(randomGenerator, rotationIntervalsDegrees.X),
		getRandomAxisRotationRadians(randomGenerator, rotationIntervalsDegrees.Y),
		getRandomAxisRotationRadians(randomGenerator, rotationIntervalsDegrees.Z)
	)
end

local function calculateSpawnPivot(
	placeholder: PVInstance,
	randomGenerator: Random,
	rotationIntervalsDegrees: Vector3?
): CFrame
	local placeholderPivot = placeholder:GetPivot()
	if rotationIntervalsDegrees == nil then
		return placeholderPivot
	end

	return placeholderPivot * createRandomRotationOffset(randomGenerator, rotationIntervalsDegrees)
end

function prefabPlacement.placeProp(placementRequest: PlacementRequest)
	local placeholder = placementRequest.placeholder
	local selectedPrefab = placementRequest.selectedPrefab
	local spawnedProp = placementRequest.spawnedProp
	local randomGenerator = placementRequest.randomGenerator
	local shouldResizeToSpawnerBounds = shouldInheritSpawnerSize(selectedPrefab)
	local randomRotationIntervalsDegrees = getRandomRotationIntervalsDegrees(selectedPrefab)

	copyPlaceholderAttributes(spawnedProp, placeholder)

	if shouldResizeToSpawnerBounds then
		resizePropToSpawnerBounds(spawnedProp, placeholder)
	end

	local spawnPivot = calculateSpawnPivot(placeholder, randomGenerator, randomRotationIntervalsDegrees)
	spawnedProp.Parent = placeholder.Parent
	spawnedProp:PivotTo(spawnPivot)
	copyPlaceholderTags(spawnedProp, placeholder)
end

return prefabPlacement
