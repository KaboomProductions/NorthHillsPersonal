--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local MaterialBadge = require(script.Parent.MaterialBadge)

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Material Badge",
	summary = "A grunge material resource badge with rotated labels.",
	controls = {
		Name = uiLabs.String("NAILS"),
		Amount = uiLabs.Number(50, 0, 999, 1),
		Selected = uiLabs.Boolean(false),
	},
}, function(props)
	return MaterialBadge({
		name = props.controls.Name,
		amount = function()
			return props.controls.Amount()
		end,
		selected = function()
			return props.controls.Selected()
		end,
	})
end)
