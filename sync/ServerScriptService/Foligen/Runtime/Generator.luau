--||------------------------------------------------------------------||
--||                Foligen Module | Runtime Generator                ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Generates foliage sets into the configured output folder.       ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local configModule = require(script.Parent.Parent.Core.Config)
local generationTypeModule = require(script.Parent.Parent.Core.GenerationType)
local placementModule = require(script.Parent.Parent.Core.Placement)
local spatialHashModule = require(script.Parent.Parent.Core.SpatialHash)
local typesModule = require(script.Parent.Parent.Core.Types)

local generator = {}

export type generationReport = typesModule.generationReport
export type generationSetReport = typesModule.generationSetReport

local function markGeneratedInstance(instance: Instance, generationSettings: typesModule.generationSettings)
	instance:SetAttribute(generationSettings.runtime.output.generatedAttributeName, true)
end

local function ensureOutputFolder(
	outputRootFolder: Folder,
	folderName: string,
	generationSettings: typesModule.generationSettings
): Folder
	local existingFolder = outputRootFolder:FindFirstChild(folderName)
	if existingFolder and existingFolder:IsA("Folder") then
		markGeneratedInstance(existingFolder, generationSettings)
		return existingFolder
	end

	local outputFolder = Instance.new("Folder")
	outputFolder.Name = folderName
	outputFolder.Parent = outputRootFolder
	markGeneratedInstance(outputFolder, generationSettings)

	return outputFolder
end

local function getSetGenerationSettings(
	generationSettings: typesModule.generationSettings,
	generationSetDefinition: typesModule.generationSetDefinition
): typesModule.generationSettings
	if generationSetDefinition.settings == nil then
		return generationSettings
	end

	return configModule.deepMerge(generationSettings :: any, generationSetDefinition.settings) :: any
end

local function generateSet(
	generationSettings: typesModule.generationSettings,
	outputRootFolder: Folder,
	generationSetDefinition: typesModule.generationSetDefinition
): typesModule.generationSetReport
	local setGenerationSettings = getSetGenerationSettings(generationSettings, generationSetDefinition)
	local outputFolder = ensureOutputFolder(outputRootFolder, generationSetDefinition.name, setGenerationSettings)
	local positionSpatialHash = spatialHashModule.fromFolder(outputFolder, setGenerationSettings.placement.minSpacing)
	local queryContext = placementModule.createQueryContext(outputRootFolder)
	local placementAmount = generationSetDefinition.amount
	local templateCount = #generationSetDefinition.templates
	local typeState = generationTypeModule.initializeState(
		setGenerationSettings.placement.generationType,
		placementAmount,
		setGenerationSettings
	)
	local placementsSinceYield = 0
	local placementsPerYield = setGenerationSettings.runtime.generation.batchSize
		* math.max(1, setGenerationSettings.runtime.generation.yieldAfterBatches)
	local attemptedCount = 0
	local placedCount = 0

	for placementIndex = 1, placementAmount do
		attemptedCount += 1

		local placementPosition = placementModule.findPlacementPosition(
			placementIndex,
			typeState,
			queryContext,
			positionSpatialHash,
			setGenerationSettings
		)

		if placementPosition ~= nil then
			local templateIndex = setGenerationSettings.runtime.random:NextInteger(1, templateCount)
			local placedModel = placementModule.placeTemplate(
				generationSetDefinition.templates[templateIndex],
				placementPosition,
				outputFolder,
				setGenerationSettings
			)
			markGeneratedInstance(placedModel, setGenerationSettings)

			positionSpatialHash:insert(placementPosition)
			placedCount += 1
		end

		placementsSinceYield += 1
		if placementsSinceYield >= placementsPerYield then
			placementsSinceYield = 0
			task.wait()
		end
	end

	return {
		placedCount = placedCount,
		attemptedCount = attemptedCount,
	}
end

function generator.generate(
	generationSettings: typesModule.generationSettings,
	generationSetDefinitions: { typesModule.generationSetDefinition },
	outputRootFolder: Folder
): generationReport
	markGeneratedInstance(outputRootFolder, generationSettings)
	local generationStartTime = os.clock()
	local generationReport: generationReport = {
		placedCount = 0,
		attemptedCount = 0,
		setReports = {},
		durationSeconds = 0,
	}

	for _, generationSetDefinition in ipairs(generationSetDefinitions) do
		local setReport = generateSet(generationSettings, outputRootFolder, generationSetDefinition)
		generationReport.placedCount += setReport.placedCount
		generationReport.attemptedCount += setReport.attemptedCount
		generationReport.setReports[generationSetDefinition.name] = setReport
	end

	generationReport.durationSeconds = os.clock() - generationStartTime

	return generationReport
end

return generator
