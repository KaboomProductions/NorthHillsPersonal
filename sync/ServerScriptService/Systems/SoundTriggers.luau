local ignoreFolder = workspace.Ignore
local soundTriggerInstances = ignoreFolder.SoundTriggers:GetChildren()

local components = workspace.Components
local agentFolders = { components.Entities, components.Characters }

local agentOverlapParams = OverlapParams.new()
agentOverlapParams.FilterType = Enum.RaycastFilterType.Include
agentOverlapParams.FilterDescendantsInstances = agentFolders

local soundTriggerController = {}
soundTriggerController.__index = soundTriggerController
soundTriggerController.controllersBySource = {}
soundTriggerController.connections = {}

function soundTriggerController.checkForAgents(origin: BasePart, triggerConfig: { [string]: any }): boolean
	local triggerDistance = triggerConfig.triggerDistance or 50
	local nearbyParts = workspace:GetPartBoundsInRadius(origin.Position, triggerDistance, agentOverlapParams)
	return #nearbyParts > 0
end

function soundTriggerController.release(triggerInstance: Instance)
	local triggerController = soundTriggerController.controllersBySource[triggerInstance]
	soundTriggerController.controllersBySource[triggerInstance] = nil

	if triggerController == nil or type(triggerController.destroy) ~= "function" then
		return
	end

	local didDestroy, destroyError = pcall(triggerController.destroy, triggerController)
	if not didDestroy then
		warn(
			("[SoundTriggers] Destroy failed for %s: %s"):format(triggerInstance:GetFullName(), tostring(destroyError))
		)
	end
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
				if not triggerInstance:IsA("Folder") or soundTriggerController.controllersBySource[triggerInstance] then
					continue
				end

				soundTriggerController.controllersBySource[triggerInstance] =
					logicModule.new(triggerInstance, soundTriggerController)
				table.insert(
					soundTriggerController.connections,
					triggerInstance.Destroying:Once(function()
						soundTriggerController.release(triggerInstance)
					end)
				)
			end
		end
	end
end

function soundTriggerController.new()
	soundTriggerController.preload()
	return soundTriggerController
end

function soundTriggerController.destroy()
	for _, connection in ipairs(soundTriggerController.connections) do
		connection:Disconnect()
	end
	table.clear(soundTriggerController.connections)

	for triggerInstance in pairs(soundTriggerController.controllersBySource) do
		soundTriggerController.release(triggerInstance)
	end
end

return soundTriggerController
