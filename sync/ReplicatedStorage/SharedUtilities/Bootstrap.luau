local bootstrapUtilities = {}

local function addModule(modules: { ModuleScript }, instance: Instance)
	if not instance:IsA("ModuleScript") then
		return
	end

	table.insert(modules, instance)
end

local function getModules(source: Instance | { ModuleScript }): { ModuleScript }
	local modules: { ModuleScript } = {}
	if typeof(source) == "Instance" then
		for _, child in ipairs(source:GetChildren()) do
			addModule(modules, child)
		end
	else
		for _, module in ipairs(source) do
			addModule(modules, module)
		end
	end

	table.sort(modules, function(left, right)
		return left.Name < right.Name
	end)

	return modules
end

local function requireModule(module: ModuleScript, contextLabel: string): any?
	local requireSuccess, loadedModule = pcall(require, module)
	if requireSuccess then
		return loadedModule
	end

	warn(("Failed to require %s module %s: %s"):format(contextLabel, module:GetFullName(), tostring(loadedModule)))
	return nil
end

local function startModule(module: ModuleScript, loadedModule: any, ...: any): any?
	if type(loadedModule) ~= "table" then
		return loadedModule
	end

	local constructor = (loadedModule :: { [any]: any }).new
	if type(constructor) ~= "function" then
		return loadedModule
	end

	local startSuccess, startedModule = pcall(constructor :: (...any) -> any, ...)
	if startSuccess then
		return startedModule
	end

	warn(("Failed to start bootstrap module %s: %s"):format(module:GetFullName(), tostring(startedModule)))
	return nil
end

local function mergeLoadedModuleTable(mergedModules: { [string]: any }, loadedModule: any)
	if type(loadedModule) ~= "table" then
		return
	end

	for key, value in pairs(loadedModule :: { [any]: any }) do
		if type(key) ~= "string" then
			continue
		end

		mergedModules[key] = value
	end
end

function bootstrapUtilities.startModules(source: Instance | { ModuleScript }, ...: any): { any }
	local startedModules: { any } = {}
	local modules = getModules(source)

	for _, module in ipairs(modules) do
		local loadedModule = requireModule(module, "bootstrap")
		if loadedModule == nil then
			continue
		end

		local startedModule = startModule(module, loadedModule, ...)
		if startedModule == nil then
			continue
		end

		table.insert(startedModules, startedModule)
	end

	return startedModules
end

function bootstrapUtilities.destroyModules(startedModules: { any })
	for _, startedModule in pairs(startedModules) do
		if type(startedModule) == "table" and type(startedModule.destroy) == "function" then
			pcall(startedModule.destroy, startedModule)
		end
	end

	table.clear(startedModules)
end

function bootstrapUtilities.mergeModuleTables(source: Instance | { ModuleScript }): { [string]: any }
	local mergedModules: { [string]: any } = {}
	local modules = getModules(source)

	for _, module in ipairs(modules) do
		local loadedModule = requireModule(module, "merged")
		if loadedModule == nil then
			continue
		end

		mergeLoadedModuleTable(mergedModules, loadedModule)
	end

	return mergedModules
end

return bootstrapUtilities
