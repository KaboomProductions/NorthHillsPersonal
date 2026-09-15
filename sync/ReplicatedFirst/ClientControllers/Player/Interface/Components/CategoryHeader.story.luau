--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local CategoryHeader = require(script.Parent.CategoryHeader)

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Category Header",
	summary = "The scrolling inventory category label and capacity counter.",
	controls = {
		Occupied = uiLabs.Number(12, 0, 40, 1),
		Capacity = uiLabs.Number(20, 1, 40, 1),
	},
}, function(props)
	return CategoryHeader({
		occupied = function()
			return props.controls.Occupied()
		end,
		capacity = function()
			return props.controls.Capacity()
		end,
	})
end)
