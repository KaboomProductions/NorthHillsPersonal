--||------------------------------------------------------------------||
--||                      Foligen Module | Init                       ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Exposes generate, clear, settings, and module version APIs.     ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local runtimeFolder = script.Runtime
local coreFolder = script.Core
local defaultSettings = require(script.Settings)
local assetLibrary = require(coreFolder.AssetLibrary)
local configModule = require(coreFolder.Config)
local outputPathModule = require(coreFolder.OutputPath)
local typesModule = require(coreFolder.Types)
local generator = require(runtimeFolder.Generator)

local generationTypeModule = require(coreFolder.GenerationType)

local foligen = {}
foligen.__version = 3.1

foligen.generationTypes = generationTypeModule.generationTypes

export type generationReport = typesModule.generationReport

local function getEmptyGenerationReport(): generationReport
	return {
		placedCount = 0,
		attemptedCount = 0,
		setReports = {},
		durationSeconds = 0,
	}
end

local function resolveSettings(customSettings: { [string]: any }?): typesModule.generationSettings
	return configModule.normalize(defaultSettings, customSettings)
end

local function formatGenerationReport(generationReport: generationReport): string
	local reportLines = {
		("Foligen | Generation complete in %.2fs"):format(generationReport.durationSeconds),
		("  Total placed: %d / %d attempted"):format(generationReport.placedCount, generationReport.attemptedCount),
	}

	for setName, setReport in pairs(generationReport.setReports) do
		table.insert(
			reportLines,
			("  [%s] placed: %d / %d attempted"):format(setName, setReport.placedCount, setReport.attemptedCount)
		)
	end

	return table.concat(reportLines, "\n")
end

local function setGenerationAttribute(generationSettings: typesModule.generationSettings, wasGenerated: boolean)
	workspace:SetAttribute(generationSettings.runtime.output.generatedAttributeName, wasGenerated)
end

function foligen.generate(customSettings: { [string]: any }?): generationReport
	local generationSettings = resolveSettings(customSettings)
	setGenerationAttribute(generationSettings, false)

	local assetsFolder = generationSettings.runtime.assetsFolder
	if assetsFolder == nil then
		warn("Foligen | Generation aborted because no assets folder was provided")
		return getEmptyGenerationReport()
	end

	local generationSetDefinitions = assetLibrary.loadSets(assetsFolder, generationSettings)
	if #generationSetDefinitions == 0 then
		warn(("Foligen | No valid foliage sets were found to generate under %s"):format(assetsFolder:GetFullName()))
		return getEmptyGenerationReport()
	end

	if generationSettings.runtime.output.clearExistingBeforeGenerate then
		outputPathModule.destroyIfExists(generationSettings.runtime.output.path)
	end

	local outputRootFolder = outputPathModule.getRootFolder(generationSettings.runtime.output.path)
	if outputRootFolder == nil then
		warn(
			("Foligen | No output folder could be resolved for generation at %s"):format(
				outputPathModule.getLabel(generationSettings.runtime.output.path)
			)
		)
		return getEmptyGenerationReport()
	end

	local generationReport = generator.generate(generationSettings, generationSetDefinitions, outputRootFolder)
	print(formatGenerationReport(generationReport))
	setGenerationAttribute(generationSettings, generationReport.placedCount > 0)

	return generationReport
end

function foligen.clear(customSettings: { [string]: any }?)
	local generationSettings = resolveSettings(customSettings)
	outputPathModule.destroyIfExists(generationSettings.runtime.output.path)
	setGenerationAttribute(generationSettings, false)
end

function foligen.getSettings(): { [string]: any }
	return configModule.deepCopy(defaultSettings)
end

return foligen
