--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local HotbarView = require(script.Parent.View.Hotbar.HotbarView)
local SlotRegistry = require(script.Parent.Drag.SlotRegistry)
local DragController = require(script.Parent.Drag.DragController)
local InventoryStore = require(script.Parent.InventoryStore)

local hotbar: { [string]: protocol.ItemDescriptor } = {
	["1"] = { itemId = "story-shovel", itemType = "TacticalShovel", stackCount = 1, attributes = {} },
	["2"] = { itemId = "story-flashlight", itemType = "Flashlight", stackCount = 1, attributes = {} },
	["3"] = { itemId = "story-crowbar", itemType = "Crowbar", stackCount = 1, attributes = {} },
	["4"] = { itemId = "story-bat", itemType = "BaseballBat", stackCount = 1, attributes = {} },
}

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Hotbar",
	summary = "Ten-slot Inventory hotbar with scale-based geometry and drag handles.",
	controls = {
		SelectedSlot = uiLabs.Number(1, 0, 10, 1),
		Enabled = true,
	},
}, function(props)
	local registry = SlotRegistry.new()
	local dragController = (
		{
			attach = function(
				_self,
				button: GuiButton,
				_source: () -> SlotRegistry.DragEntry,
				onActivated: (() -> ())?
			): () -> ()
				local connection = button.Activated:Connect(function()
					if onActivated then
						onActivated()
					end
				end)
				return function()
					connection:Disconnect()
				end
			end,
		} :: unknown
	) :: DragController.DragController
	local function state(): InventoryStore.ReadOnlyState
		return {
			enabled = props.controls.Enabled(),
			disabledReason = if props.controls.Enabled() then nil else "Story disabled state",
			storageCapacity = 20,
			currentSlot = props.controls.SelectedSlot() > 0 and props.controls.SelectedSlot() or nil,
			equipIntentSequence = 0,
			hotbar = hotbar,
			storage = {},
			materials = { Nails = 50, DuctTape = 10 },
		}
	end
	return HotbarView({
		state = state,
		onEquip = function(index)
			props.controls.SelectedSlot(
				if state().currentSlot == index or hotbar[tostring(index)] == nil then 0 else index
			)
		end,
		registry = registry,
		dragController = dragController,
	})
end)
