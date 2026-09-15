--!strict

local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local DragController = require(script.Parent.Parent.Parent.Drag.DragController)
local InventoryStore = require(script.Parent.Parent.Parent.InventoryStore)
local SlotRegistry = require(script.Parent.Parent.Parent.Drag.SlotRegistry)
local Theme = require(replicatedFirst.ClientControllers.Player.Interface.Components.Theme)
local HotbarSlot = require(script.Parent.HotbarSlot)

local create = vide.create
local HOTBAR_SLOT_COUNT = protocol.Limits.hotbarCapacity
local HOTBAR_SLOT_SIZE = UDim2.fromScale(Theme.Geometry.HotbarSlotWidth, Theme.Geometry.HotbarSlotHeight)

export type Props = {
	state: InventoryStore.StateSource,
	onEquip: (index: number) -> (),
	registry: SlotRegistry.SlotRegistry,
	dragController: DragController.DragController,
}

return function(props: Props)
	local slots = vide.indexes(function()
		local state = props.state()
		local result: { [number]: HotbarSlot.ItemEntry } = {}
		for index = 1, HOTBAR_SLOT_COUNT do
			result[index] = {
				index = index,
				descriptor = state.hotbar[tostring(index)],
			}
		end
		return result
	end, function(itemSource: HotbarSlot.ItemSource, index: number)
		return HotbarSlot(itemSource, index, {
			state = props.state,
			onEquip = props.onEquip,
			size = HOTBAR_SLOT_SIZE,
			registry = props.registry,
			dragController = props.dragController,
		})
	end)

	local frame = create("Frame")({
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = Theme.Geometry.HotbarPosition,
		Size = Theme.Geometry.HotbarSize,
		create("ImageLabel")({
			Name = "HotbarShadow",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Image = Theme.Images.HotbarShadow,
			Position = UDim2.fromScale(0.5, 1.0609),
			Size = UDim2.fromScale(0.973231, 1.16384),
		}),
		create("Frame")({
			Name = "HotbarSlotsHolder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			slots,
		}),
		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = Theme.Geometry.HotbarAspectRatio,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),
	})

	vide.cleanup(props.registry:registerContainer(frame))
	return frame
end
