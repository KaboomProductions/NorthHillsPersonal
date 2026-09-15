--!strict

local settingValues = {}

function settingValues.isValid(definition, value: unknown): boolean
	if typeof(value) ~= typeof(definition.default) then
		return false
	end
	if typeof(value) == "number" then
		local number = value :: number
		return number == number and math.abs(number) < math.huge
			and number >= (definition.minimum or 0) and number <= (definition.maximum or 100)
	end
	if typeof(value) == "string" then
		if #(value :: string) > 128 then
			return false
		end
		for _, option in definition.options or {} do
			if option.value == value then
				return true
			end
		end
		return false
	end
	return typeof(value) == "boolean"
end

function settingValues.normalize(definition, saved: unknown): boolean | number | string
	if settingValues.isValid(definition, saved) then
		return saved :: boolean | number | string
	end
	return definition.default
end

return settingValues
