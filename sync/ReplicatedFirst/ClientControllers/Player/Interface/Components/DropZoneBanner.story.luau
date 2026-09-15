--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local DropZoneBanner = require(script.Parent.DropZoneBanner)

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Drop Zone Banner",
	summary = "The explicit inventory drop target banner.",
	controls = {
		Label = uiLabs.String("Drag here to drop."),
	},
}, function(props)
	return DropZoneBanner({
		text = props.controls.Label,
	})
end)
