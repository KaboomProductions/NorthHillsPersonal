local optionRegistry = {}
optionRegistry.__index = optionRegistry

local function normalizeId(name: string): string
	return string.lower((string.gsub(name, "%s+", "")))
end

function optionRegistry.new(optionsFolder: Instance, optionButtons: { ImageButton })
	local self = setmetatable({}, optionRegistry)
	self.optionsFolder = optionsFolder
	self.optionButtons = optionButtons
	self.modulesById = {}
	self.buttonOptionIds = {}

	self:loadModules()
	self:mapButtons()

	return self
end

function optionRegistry:loadModules()
	for _, optionModule in ipairs(self.optionsFolder:GetChildren()) do
		if not optionModule:IsA("ModuleScript") then
			continue
		end

		self.modulesById[optionModule.Name] = require(optionModule)
	end
end

function optionRegistry:resolveOptionId(buttonName: string): string?
	local normalizedButtonName = normalizeId(buttonName)

	for optionId in pairs(self.modulesById) do
		local normalizedOptionId = normalizeId(optionId)
		if string.find(normalizedButtonName, normalizedOptionId, 1, true) then
			return optionId
		end
	end

	return nil
end

function optionRegistry:mapButtons()
	for _, button in ipairs(self.optionButtons) do
		local optionId = self:resolveOptionId(button.Name)
		if optionId ~= nil then
			self.buttonOptionIds[button] = optionId
		end
	end
end

function optionRegistry:getButtonOptionId(button: ImageButton): string?
	return self.buttonOptionIds[button]
end

function optionRegistry:getOptionIds(): { string }
	local mappedOptionIds = {}

	for _, optionId in pairs(self.buttonOptionIds) do
		mappedOptionIds[optionId] = true
	end

	local optionIds = {}

	for optionId in pairs(mappedOptionIds) do
		table.insert(optionIds, optionId)
	end

	table.sort(optionIds)

	return optionIds
end

function optionRegistry:createOption(optionId: string, context)
	local optionModule = self.modulesById[optionId]
	if optionModule == nil then
		return nil
	end

	if type(optionModule) == "table" and type(optionModule.new) == "function" then
		return optionModule.new(context)
	end

	return optionModule
end

return optionRegistry
