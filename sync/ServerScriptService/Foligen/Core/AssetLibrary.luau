--||------------------------------------------------------------------||
--||                  Foligen Module | AssetLibrary                   ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Loads asset sets and prepares tagged clones for generation.     ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local collectionService = game:GetService("CollectionService")

local typesModule = require(script.Parent.Types)

local assetLibrary = {}

local function tagInstanceAndDescendants(instance: Instance, ignoreTags: { string })
	for _, tag in ipairs(ignoreTags) do
		collectionService:AddTag(instance, tag)
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		for _, tag in ipairs(ignoreTags) do
			collectionService:AddTag(descendant, tag)
		end
	end
end

local function findGenerationAmount(setConfig: typesModule.assetSetConfig?): number
	if type(setConfig) == "table" and type(setConfig.amount) == "number" then
		return math.max(0, math.floor(setConfig.amount))
	end

	return 0
end

local function findGenerationPriority(setConfig: typesModule.assetSetConfig?): number
	if type(setConfig) == "table" and type(setConfig.generationPriority) == "number" then
		return math.floor(setConfig.generationPriority)
	end

	return 0
end

local function getSetOverrides(setConfig: typesModule.assetSetConfig?): { [string]: any }?
	if type(setConfig) ~= "table" then
		return nil
	end

	local overrideSettings = {}

	for settingName, settingValue in pairs(setConfig) do
		if settingName == "amount" or settingName == "generationPriority" then
			continue
		end

		overrideSettings[settingName] = settingValue
	end

	return next(overrideSettings) ~= nil and overrideSettings or nil
end

local function collectTemplates(folder: Folder): { Model }
	local templates = {}

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end

	return templates
end

function assetLibrary.loadSets(
	assetsFolder: Instance,
	generationSettings: typesModule.generationSettings
): { typesModule.generationSetDefinition }
	local loadedSets: { typesModule.generationSetDefinition } = {}

	for folderName, setConfig in pairs(generationSettings.assets) do
		if type(folderName) ~= "string" then
			continue
		end

		local folder = assetsFolder:FindFirstChild(folderName)
		if folder == nil or not folder:IsA("Folder") then
			warn(("Foligen | Skipped missing asset folder %s"):format(folderName))
			continue
		end

		local templates = collectTemplates(folder)
		local amount = findGenerationAmount(setConfig)
		if #templates == 0 or amount <= 0 then
			continue
		end

		table.insert(loadedSets, {
			name = folderName,
			templates = templates,
			amount = amount,
			generationPriority = findGenerationPriority(setConfig),
			settings = getSetOverrides(setConfig),
		})
	end

	table.sort(loadedSets, function(leftSet, rightSet)
		if leftSet.generationPriority == rightSet.generationPriority then
			return leftSet.name < rightSet.name
		end

		return leftSet.generationPriority < rightSet.generationPriority
	end)

	return loadedSets
end

function assetLibrary.prepareClone(model: Model, ignoreTags: { string }): Model
	local clonedModel = model:Clone()
	tagInstanceAndDescendants(clonedModel, ignoreTags)
	return clonedModel
end

return assetLibrary
