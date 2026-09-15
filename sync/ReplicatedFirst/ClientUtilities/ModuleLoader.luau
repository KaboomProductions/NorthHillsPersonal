local moduleLoader = {}

function moduleLoader.getModuleScripts(source: Instance | { ModuleScript }): { ModuleScript }
	local moduleScripts: { ModuleScript } = {}
	local children = typeof(source) == "Instance" and source:GetChildren() or source

	for _, child in ipairs(children) do
		if child and child:IsA("ModuleScript") then
			table.insert(moduleScripts, child)
		end
	end

	table.sort(moduleScripts, function(left, right)
		return left.Name < right.Name
	end)

	return moduleScripts
end

function moduleLoader.requireModule(moduleScript: ModuleScript): unknown?
	local requireSuccess, loadedModule = pcall(require, moduleScript)
	if requireSuccess then
		return loadedModule
	end

	warn(("Failed to load module %s: %s"):format(moduleScript:GetFullName(), tostring(loadedModule)))
	return nil
end

function moduleLoader.requireModules(source: Instance | { ModuleScript }): { [string]: unknown }
	local loadedModules: { [string]: unknown } = {}

	for _, moduleScript in ipairs(moduleLoader.getModuleScripts(source)) do
		local loadedModule = moduleLoader.requireModule(moduleScript)
		if loadedModule == nil then
			continue
		end

		loadedModules[moduleScript.Name] = loadedModule
	end

	return loadedModules
end

function moduleLoader.startModule(moduleScript: ModuleScript, ...: any): unknown?
	local loadedModule = moduleLoader.requireModule(moduleScript)
	if loadedModule == nil then
		return nil
	end

	if type(loadedModule) ~= "table" or type(loadedModule.new) ~= "function" then
		return loadedModule
	end

	local startSuccess, startedController = pcall(loadedModule.new, ...)
	if startSuccess then
		return startedController
	end

	warn(("Failed to start module %s: %s"):format(moduleScript:GetFullName(), tostring(startedController)))
	return nil
end

function moduleLoader.startModules(source: Instance | { ModuleScript }, ...: any): { unknown }
	local startedModules = {}

	for _, moduleScript in ipairs(moduleLoader.getModuleScripts(source)) do
		local startedModule = moduleLoader.startModule(moduleScript, ...)
		if startedModule == nil then
			continue
		end

		table.insert(startedModules, startedModule)
	end

	return startedModules
end

function moduleLoader.destroyModules(loadedModules: { unknown })
	for index = #loadedModules, 1, -1 do
		local loadedModule = loadedModules[index]
		if type(loadedModule) == "table" and type(loadedModule.destroy) == "function" then
			local destroySuccess, destroyError = pcall(function()
				loadedModule:destroy()
			end)

			if not destroySuccess then
				warn(("Failed to destroy module %s: %s"):format(tostring(loadedModule), tostring(destroyError)))
			end
		else
			warn(("Module %s has no destroy method"):format(tostring(loadedModule)))
		end

		loadedModules[index] = nil
	end

	table.clear(loadedModules)
end

return moduleLoader
