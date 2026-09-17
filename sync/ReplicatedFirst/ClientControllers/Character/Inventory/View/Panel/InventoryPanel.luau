--!strict
--# selene: allow(mixed_table)

local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local CategoryHeader = require(replicatedFirst.ClientControllers.Player.Interface.Components.CategoryHeader)
local ContextMenu = require(script.Parent.ContextMenu)
local DisabledOverlay = require(script.Parent.DisabledOverlay)
local DragController = require(script.Parent.Parent.Parent.Drag.DragController)
local DropZoneBanner = require(replicatedFirst.ClientControllers.Player.Interface.Components.DropZoneBanner)
local InventoryPanelAnimator = require(script.Parent.InventoryPanelAnimator)
local InventoryRequests = require(script.Parent.Parent.Parent.Requests.InventoryRequests)
local InventoryStore = require(script.Parent.Parent.Parent.InventoryStore)
local ItemDisplay = require(script.Parent.Parent.ItemDisplay)
local MaterialList = require(replicatedFirst.ClientControllers.Player.Interface.Components.MaterialList)
local PanelBanner = require(replicatedFirst.ClientControllers.Player.Interface.Components.PanelBanner)
local SlotButton = require(replicatedFirst.ClientControllers.Player.Interface.Components.SlotButton)
local SlotRegistry = require(script.Parent.Parent.Parent.Drag.SlotRegistry)
local Theme = require(replicatedFirst.ClientControllers.Player.Interface.Components.Theme)
local ThrowFlow = require(script.Parent.Parent.Parent.Requests.ThrowFlow)

local create = vide.create

export type Props = {
	state: InventoryStore.StateSource,
	isOpen: InventoryStore.Source<boolean>,
	onEquip: (index: number) -> (),
	requests: InventoryRequests.Requests,
	throwFlow: ThrowFlow.ThrowFlow,
	registry: SlotRegistry.SlotRegistry,
	dragController: DragController.DragController,
}

local function countOccupied(items: { [string]: protocol.ItemDescriptor }): number
	local count = 0
	for _ in items do
		count += 1
	end
	return count
end

local function materialDisplayName(materialType: string): string
	local config = materialUtils.getMaterialConfig(materialType)
	if config then
		return string.upper(config.displayName)
	end

	local spaced = string.gsub(materialType, "([a-z])([A-Z])", "%1 %2")
	return string.upper(spaced)
end

local function createStorageSlot(
	entrySource: () -> SlotRegistry.DragEntry,
	index: number,
	props: Props,
	selected: InventoryStore.Source<SlotRegistry.DragEntry?>
): Instance
	local function entry(): SlotRegistry.DragEntry
		return entrySource()
	end

	local function descriptor(): SlotButton.ItemDescriptor?
		local current = entry().descriptor
		return if current then ItemDisplay.withDisplay(current) else nil
	end

	local function isSelected(): boolean
		local current = selected()
		local currentEntry = entry()
		return current ~= nil
			and currentEntry.descriptor ~= nil
			and current.zone == protocol.Zones.storage
			and current.index == index
	end

	return SlotButton({
		descriptor = descriptor,
		selected = isSelected,
		disabled = function()
			return entry().disabled
		end,
		size = Theme.Geometry.InventorySlotSize,
		layoutOrder = index,
		registerDragHandle = function(button: GuiObject): () -> ()
			local unregister = props.registry:register(protocol.Zones.storage, index, button, entry)
			local cleanupDrag = props.dragController:attach(button :: GuiButton, entry)
			local secondaryClick = (button :: ImageButton).MouseButton2Click:Connect(function()
				local current = entry()
				if current.descriptor and not current.disabled and not current.locked then
					selected(current)
				end
			end)
			return function()
				secondaryClick:Disconnect()
				unregister()
				cleanupDrag()
			end
		end,
	})
end

return function(props: Props)
	local selected: InventoryStore.Source<SlotRegistry.DragEntry?> =
		vide.source(nil) :: InventoryStore.Source<SlotRegistry.DragEntry?>

	local storageSlots = vide.indexes(function()
		local state = props.state()
		local result: { [number]: SlotRegistry.DragEntry } = {}
		for index = 1, state.storageCapacity do
			result[index] = {
				zone = protocol.Zones.storage,
				index = index,
				descriptor = state.storage[tostring(index)],
				locked = false,
				disabled = not state.enabled,
			}
		end
		return result
	end, function(entrySource: () -> SlotRegistry.DragEntry, index: number)
		return createStorageSlot(entrySource, index, props, selected)
	end)

	local panel = create("Frame")({
		Name = "InventoryPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = Theme.Geometry.PanelPosition,
		Size = Theme.Geometry.PanelSize,

		Visible = false,
		create("Frame")({
			Name = "InventoryContent",
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromScale(0.926931, 0.998366),

			create("ImageLabel")({
				Name = "BG",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Theme.Images.PanelBackground,
				ImageTransparency = 0.5,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = -1,
				create("CanvasGroup")({
					Name = "CanvasHolder",
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.501, 0.94724),
					SelectionGroup = true,
					Size = UDim2.fromScale(0.948735, 0.704196),
					create("UIGradient")({
						Name = "Fade",
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.03, 0),
							NumberSequenceKeypoint.new(0.960875, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),

					create("ScrollingFrame")({
						Name = "Holder",
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						BottomImage = Theme.Images.ScrollBarBottom,
						CanvasSize = UDim2.fromScale(0, 1),
						MidImage = Theme.Images.ScrollBarMiddle,
						Position = UDim2.fromScale(0.000482383, 0.000267893),
						ScrollBarImageTransparency = 1,
						ScrollBarThickness = 5,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						Selectable = false,
						Size = UDim2.fromScale(1.00033, 0.999454),
						TopImage = Theme.Images.ScrollBarTop,
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,

						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(-0.008, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
							Wraps = true,
						}),

						CategoryHeader({
							occupied = function()
								return countOccupied(props.state().storage)
							end,
							capacity = function()
								return props.state().storageCapacity
							end,
						}),

						storageSlots,
					}),
				}),
			}),

			create("ImageLabel")({
				Name = "Outline",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Theme.Images.PanelOutline,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
			}),

			create("ImageLabel")({
				Name = "Scratches",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Theme.Images.PanelScratches,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}),

			PanelBanner({}),
			DropZoneBanner({
				registerDropZone = function(gui: GuiObject): () -> ()
					return props.registry:registerDropZone(gui)
				end,
			}),
		}),
		MaterialList({
			materials = function()
				return props.state().materials
			end,
			getDisplayName = materialDisplayName,
		}),
		ContextMenu({
			state = props.state,
			selected = selected,
			onEquip = props.onEquip,
			requests = props.requests,
			throwFlow = props.throwFlow,
		}),
		DisabledOverlay({ state = props.state }),
		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = Theme.Geometry.PanelAspectRatio,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),
	})

	local panelAnimator = InventoryPanelAnimator.new(panel)
	vide.effect(function()
		local isOpen = props.isOpen()
		if not isOpen then
			selected(nil)
		end
		panelAnimator:setOpen(isOpen)
	end)
	vide.cleanup(panelAnimator)
	vide.cleanup(props.registry:registerContainer(panel))
	return panel
end
