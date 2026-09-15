local ignoreFolder = workspace.Ignore
local soundTriggerInstances = ignoreFolder.SoundTriggers:GetChildren()

local components = workspace.Components
local agentFolders = { components.Entities, components.Characters }

local agentOverlapParams = OverlapParams.new()
agentOverlapParams.FilterType = Enum.RaycastFilterType.Include
agentOverlapParams.FilterDescendantsInstances = agentFolders

local soundTriggerController = {}
soundTriggerController.__index = soundTriggerController

function soundTriggerController.checkForAgents(origin: BasePart, triggerConfig: { [string]: any }): boolean
	local triggerDistance = triggerConfig.triggerDistance or 50
	local nearbyParts = workspace:GetPartBoundsInRadius(origin.Position, triggerDistance, agentOverlapParams)
	return #nearbyParts > 0
end

function soundTriggerController.preload()
	local logicModulesByName = {}

	for _, moduleScript in ipairs(script:GetChildren()) do
		if not moduleScript:IsA("ModuleScript") then
			continue
		end

		logicModulesByName[moduleScript.Name] = require(moduleScript)
	end

	for _, triggerFolder in pairs(soundTriggerInstances) do
		local triggerName = triggerFolder.Name
		local logicModule = logicModulesByName[triggerName]

		if logicModule ~= nil then
			for _, triggerInstance in pairs(triggerFolder:GetChildren()) do
				if not triggerInstance:IsA("Folder") then
					continue
				end

				logicModule.new(triggerInstance, soundTriggerController)
			end
		end
	end
end

function soundTriggerController.new()
	soundTriggerController.preload()
end

return soundTriggerController
