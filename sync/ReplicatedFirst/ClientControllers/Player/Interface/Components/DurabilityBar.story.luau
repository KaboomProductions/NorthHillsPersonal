--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local DurabilityBar = require(script.Parent.DurabilityBar)

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Durability Bar",
	summary = "The design durability bar at empty, half, and full values.",
	controls = {
		Durability = uiLabs.Number(0.5, 0, 1, 0.01),
	},
}, function(props)
	return DurabilityBar({
		value = function()
			return props.controls.Durability()
		end,
	})
end)
