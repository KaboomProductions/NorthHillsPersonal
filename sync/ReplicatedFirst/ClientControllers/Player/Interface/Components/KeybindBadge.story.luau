--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local KeybindBadge = require(script.Parent.KeybindBadge)

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Keybind Badge",
	summary = "A numbered hotbar keybind badge with editable text.",
	controls = {
		Index = uiLabs.Number(1, 1, 10, 1),
		BadgeText = uiLabs.String(""),
	},
}, function(props)
	return KeybindBadge({
		index = props.controls.Index(),
		text = props.controls.BadgeText,
	})
end)
