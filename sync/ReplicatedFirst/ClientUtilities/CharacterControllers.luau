local clientRuntime = require(script.Parent.Parent.ClientData.ClientRuntime)
local moduleLoader = require(script.Parent.ModuleLoader)

local characterControllers = {}

type controllerList = clientRuntime.controllerList

function characterControllers.register(controller: unknown): unknown?
	if controller == nil then
		return nil
	end

	table.insert(clientRuntime.activeCharacterControllers, controller)
	return controller
end

function characterControllers.loadController(moduleScript: ModuleScript): unknown?
	local controller = moduleLoader.startModule(moduleScript)
	return characterControllers.register(controller)
end

function characterControllers.loadControllers(source: Instance | {ModuleScript}): controllerList
	local loadedControllers: controllerList = {}

	for _, moduleScript in ipairs(moduleLoader.getModuleScripts(source)) do
		local controller = characterControllers.loadController(moduleScript)
		if controller ~= nil then
			table.insert(loadedControllers, controller)
		end
	end

	return loadedControllers
end

function characterControllers.destroyAll()
	moduleLoader.destroyModules(clientRuntime.activeCharacterControllers)
end

return characterControllers
