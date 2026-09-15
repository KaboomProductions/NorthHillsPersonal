local collectionService = game:GetService("CollectionService")
local serverStorage = game:GetService("ServerStorage")

local prefabPlacement = require(script.PrefabPlacement)
local propSpawnerSettings = require(script.Config)
local variationSelector = require(script.VariationSelector)

local placeholderSettings = propSpawnerSettings.placeholder
local prefabSettings = propSpawnerSettings.prefab
local serverAssets = serverStorage.ServerAssets
local propPrefabsFolder = serverAssets.Prefabs:FindFirstChild(prefabSettings.folderName)

local propSpawner = {}

type VariationSelector = typeof(variationSelector.new())

type SpawnContext = {
	variationSelector: VariationSelector,
	variationsByClassName: { [string]: { PVInstance } },
	randomGenerator: Random,
}

local function getPropVariationsFromGroup(prefabGroup: Instance): { PVInstance }
	local propVariations: { PVInstance } = {}

	for _, prefabChild in ipairs(prefabGroup:GetChildren()) do
		if prefabChild:IsA("PVInstance") then
			table.insert(propVariations, prefabChild)
		end
	end

	return propVariations
end

local function findPropVariations(propClassName: string): { PVInstance }
	local prefabGroup = if propPrefabsFolder ~= nil then propPrefabsFolder:FindFirstChild(propClassName) else nil
	if prefabGroup == nil then
		warn(("PropSpawner | Missing prop variation group for class %s"):format(propClassName))
		return {}
	end

	local propVariations = getPropVariationsFromGroup(prefabGroup)
	if #propVariations == 0 then
		warn(("PropSpawner | Prop variation group %s contains no usable props"):format(propClassName))
	end

	return propVariations
end

local function getPropVariations(
	propClassName: string,
	variationsByClassName: { [string]: { PVInstance } }
): { PVInstance }
	local cachedVariations = variationsByClassName[propClassName]
	if cachedVariations ~= nil then
		return cachedVariations
	end

	local propVariations = findPropVariations(propClassName)
	variationsByClassName[propClassName] = propVariations
	return propVariations
end

local function warnPlacementFailure(
	selectedPrefab: PVInstance,
	placeholder: PVInstance,
	placementError: unknown
)
	warn(
		("PropSpawner | Failed to spawn %s for %s: %s"):format(
			selectedPrefab.Name,
			placeholder:GetFullName(),
			tostring(placementError)
		)
	)
end

local function getPropClassName(placeholder: PVInstance): string?
	local propClassName: unknown = placeholder:GetAttribute(placeholderSettings.classAttributeName)
	if type(propClassName) ~= "string" or propClassName == "" then
		warn(("PropSpawner | Prop placeholder %s has no valid Class attribute"):format(placeholder:GetFullName()))
		return nil
	end

	return propClassName
end

local function clonePrefab(selectedPrefab: PVInstance): PVInstance?
	local spawnedProp = selectedPrefab:Clone()
	if spawnedProp == nil then
		warn(("PropSpawner | Failed to clone variation %s"):format(selectedPrefab:GetFullName()))
	end

	return spawnedProp
end

local function tryPlaceProp(placementRequest: prefabPlacement.PlacementRequest): boolean
	local placementWasSuccessful, placementError = pcall(prefabPlacement.placeProp, placementRequest)
	if placementWasSuccessful then
		return true
	end

	placementRequest.spawnedProp:Destroy()
	warnPlacementFailure(placementRequest.selectedPrefab, placementRequest.placeholder, placementError)
	return false
end

local function replacePlaceholder(placeholder: PVInstance, spawnContext: SpawnContext)
	local propClassName = getPropClassName(placeholder)
	if propClassName == nil then
		return
	end

	local propVariations = getPropVariations(propClassName, spawnContext.variationsByClassName)
	if #propVariations == 0 then
		return
	end

	local placeholderPosition = placeholder:GetPivot().Position
	local selectedPrefab =
		spawnContext.variationSelector:selectVariation(propClassName, placeholderPosition, propVariations)
	local spawnedProp = clonePrefab(selectedPrefab)
	if spawnedProp == nil then
		return
	end

	local placementRequest: prefabPlacement.PlacementRequest = {
		placeholder = placeholder,
		selectedPrefab = selectedPrefab,
		spawnedProp = spawnedProp,
		randomGenerator = spawnContext.randomGenerator,
	}
	if not tryPlaceProp(placementRequest) then
		return
	end

	spawnContext.variationSelector:recordPlacement(propClassName, placeholderPosition, selectedPrefab)
	placeholder:Destroy()
end

local function replaceTaggedPlaceholder(taggedInstance: Instance, spawnContext: SpawnContext)
	if not taggedInstance:IsDescendantOf(workspace) then
		return
	end

	if not taggedInstance:IsA("PVInstance") then
		warn(
			("PropSpawner | Prop placeholder %s has no transform to spawn from"):format(
				taggedInstance:GetFullName()
			)
		)
		return
	end

	replacePlaceholder(taggedInstance, spawnContext)
end

function propSpawner.spawnPlaceholderProps()
	local randomGenerator = Random.new()
	local spawnContext: SpawnContext = {
		variationSelector = variationSelector.new(randomGenerator),
		variationsByClassName = {},
		randomGenerator = randomGenerator,
	}

	for _, taggedInstance in ipairs(collectionService:GetTagged(placeholderSettings.tagName)) do
		replaceTaggedPlaceholder(taggedInstance, spawnContext)
	end
end

return propSpawner
