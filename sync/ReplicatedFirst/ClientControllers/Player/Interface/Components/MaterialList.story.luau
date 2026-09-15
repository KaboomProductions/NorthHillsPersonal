--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local MaterialList = require(script.Parent.MaterialList)

local function parseMaterials(value: string): { [string]: number }
	local result: { [string]: number } = {}
	for _, part in ipairs(string.split(value, ",")) do
		local materialType, amountText = string.match(part, "^%s*([%w_]+)%s*:%s*(%d+)%s*$")
		if materialType and amountText then
			result[materialType] = tonumber(amountText) or 0
		end
	end
	return result
end

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Material List",
	summary = "The material sidebar backed by an editable map of resource counts.",
	controls = {
		Materials = uiLabs.String("Nails:50, DuctTape:10"),
	},
}, function(props)
	return MaterialList({
		materials = function()
			return parseMaterials(props.controls.Materials())
		end,
	})
end)
