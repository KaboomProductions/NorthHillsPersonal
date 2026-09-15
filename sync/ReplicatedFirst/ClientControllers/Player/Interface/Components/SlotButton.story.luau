--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local SlotButton = require(script.Parent.SlotButton)

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Slot Button",
	summary = "The shared item slot with selection, stack count, durability, and disabled states.",
	controls = {
		Selected = uiLabs.Boolean(true),
		Disabled = uiLabs.Boolean(false),
		Durability = uiLabs.Number(0.5, 0, 1, 0.01),
		Count = uiLabs.Number(1, 1, 99, 1),
	},
}, function(props)
	return SlotButton({
		descriptor = function()
			return {
				itemId = "story-slot",
				itemType = "BaseballBat",
				stackCount = props.controls.Count(),
				attributes = {},
				imageId = 104782145119988,
				displayName = "Baseball Bat",
			}
		end,
		index = 1,
		selected = function()
			return props.controls.Selected()
		end,
		durability = function()
			return props.controls.Durability()
		end,
		disabled = function()
			return props.controls.Disabled()
		end,
		size = UDim2.fromOffset(120, 120),
	})
end)
