--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local PanelBanner = require(script.Parent.PanelBanner)

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Panel Banner",
	summary = "The grunge inventory title and description banner.",
	controls = {
		Title = uiLabs.String("INVENTORY"),
		Description = uiLabs.String("Your own personal belongings are stored here alongside your materials."),
	},
}, function(props)
	return PanelBanner({
		title = props.controls.Title,
		description = props.controls.Description,
	})
end)
