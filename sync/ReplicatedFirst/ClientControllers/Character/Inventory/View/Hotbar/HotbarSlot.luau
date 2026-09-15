--!strict

local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local DragController = require(script.Parent.Parent.Parent.Drag.DragController)
local InventoryStore = require(script.Parent.Parent.Parent.InventoryStore)
local ItemDisplay = require(script.Parent.Parent.ItemDisplay)
local SlotRegistry = require(script.Parent.Parent.Parent.Drag.SlotRegistry)
local SlotButton = require(replicatedFirst.ClientControllers.Player.Interface.Components.SlotButton)
local HotbarSlotAnimator = require(script.Parent.HotbarSlotAnimator)

local selectedSlotScale = 1.08

export type ItemEntry = {
	index: number,
	descriptor: protocol.ItemDescriptor?,
}

export type ItemSource = () -> ItemEntry

export type Props = {
	state: InventoryStore.StateSource,
	onEquip: (index: number) -> (),
	size: UDim2,
	registry: SlotRegistry.SlotRegistry,
	dragController: DragController.DragController,
}

return function(itemSource: ItemSource, index: number, props: Props)
	local function entry(): ItemEntry
		return itemSource()
	end

	local function descriptor(): SlotButton.ItemDescriptor?
		local current = entry().descriptor
		return if current then ItemDisplay.withDisplay(current) else nil
	end

	local function dragEntry(): SlotRegistry.DragEntry
		local current = entry().descriptor
		return {
			zone = protocol.Zones.hotbar,
			index = index,
			descriptor = current,
			locked = false,
			disabled = not props.state().enabled,
		}
	end

	local function isSelected(): boolean
		local state = props.state()
		return state.enabled and state.currentSlot == index
	end

	local selectionAnimator = HotbarSlotAnimator.new(isSelected())
	vide.effect(function()
		selectionAnimator:setSelected(isSelected())
	end)
	vide.cleanup(selectionAnimator)

	return SlotButton({
		descriptor = descriptor,
		index = index,
		selected = function()
			return props.state().currentSlot == index
		end,
		selectionAnimation = {
			selectionProgress = selectionAnimator.selectionProgress,
			selectedScale = selectedSlotScale,
		},
		disabled = function()
			return not props.state().enabled
		end,
		size = props.size,
		layoutOrder = index,
		registerDragHandle = function(button: GuiObject): () -> ()
			local unregister = props.registry:register(protocol.Zones.hotbar, index, button, dragEntry)
			local cleanupDrag = props.dragController:attach(button :: GuiButton, dragEntry, function()
				if props.state().enabled then
					props.onEquip(index)
				end
			end)
			return function()
				unregister()
				cleanupDrag()
			end
		end,
	})
end
