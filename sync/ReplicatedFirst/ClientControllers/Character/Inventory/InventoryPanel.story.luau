--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local uiLabs = require(replicatedStorage.ExternalLibraries.ui_labs)
local vide = require(replicatedStorage.ExternalLibraries.vide)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local InventoryPanel = require(script.Parent.View.Panel.InventoryPanel)
local SlotRegistry = require(script.Parent.Drag.SlotRegistry)
local DragController = require(script.Parent.Drag.DragController)
local InventoryStore = require(script.Parent.InventoryStore)
local InventoryRequests = require(script.Parent.Requests.InventoryRequests)
local ThrowFlow = require(script.Parent.Requests.ThrowFlow)

local hotbar: { [string]: protocol.ItemDescriptor } = {
	["1"] = { itemId = "story-bat", itemType = "BaseballBat", stackCount = 1, attributes = {} },
	["2"] = { itemId = "story-flashlight", itemType = "Flashlight", stackCount = 1, attributes = {} },
}
local storage: { [string]: protocol.ItemDescriptor } = {
	["1"] = { itemId = "story-crowbar", itemType = "Crowbar", stackCount = 1, attributes = {} },
	["2"] = { itemId = "story-backpack", itemType = "Backpack", stackCount = 1, attributes = {} },
	["3"] = { itemId = "story-lantern", itemType = "Lantern", stackCount = 1, attributes = {} },
}

return uiLabs.CreateVideStory({
	vide = vide,
	name = "Inventory Panel",
	summary = "Design-ported storage grid, materials, disabled overlay, and drag/drop panel.",
	controls = {
		Open = true,
		Enabled = true,
		StorageCapacity = 20,
		SelectedSlot = uiLabs.Number(1, 0, 10, 1),
		Nails = uiLabs.Number(50, 0, 999, 1),
		DuctTape = uiLabs.Number(10, 0, 999, 1),
	},
}, function(props)
	local registry = SlotRegistry.new()
	local dragController = (
		{
			attach = function(_button: GuiObject, _source: () -> SlotRegistry.DragEntry): () -> ()
				return function() end
			end,
			consumeClick = function(): boolean
				return false
			end,
		} :: unknown
	) :: DragController.DragController
	local function emptyResponse(): protocol.InventoryResponse?
		return nil
	end
	local requests = (
		{
			remote = nil,
			store = nil,
			inFlight = {},
			generation = 0,
			_invoke = emptyResponse,
			equip = emptyResponse,
			unequip = emptyResponse,
			move = emptyResponse,
			swap = emptyResponse,
			mergeStack = emptyResponse,
			splitStack = emptyResponse,
			drop = emptyResponse,
			upgrade = emptyResponse,
			useCapacityUpgrade = emptyResponse,
			throw = emptyResponse,
			releaseThrow = emptyResponse,
			destroy = function() end,
		} :: unknown
	) :: InventoryRequests.Requests
	local throwFlow = (
		{
			throw = function(_itemId: string): () end,
			destroy = function() end,
		} :: unknown
	) :: ThrowFlow.ThrowFlow
	local function state(): InventoryStore.ReadOnlyState
		return {
			enabled = props.controls.Enabled(),
			disabledReason = if props.controls.Enabled() then nil else "Story disabled state",
			storageCapacity = math.clamp(math.floor(props.controls.StorageCapacity()), 20, 40),
			currentSlot = props.controls.SelectedSlot() > 0 and props.controls.SelectedSlot() or nil,
			equipIntentSequence = 0,
			hotbar = hotbar,
			storage = storage,
			materials = {
				Nails = props.controls.Nails(),
				DuctTape = props.controls.DuctTape(),
			},
		}
	end
	return vide.create("Frame")({
		Name = "InventoryPanelStory",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 11, 13),
		BorderSizePixel = 0,
		InventoryPanel({
			state = state,
			isOpen = props.controls.Open,
			onEquip = function(index)
				local selected = props.controls.SelectedSlot()
				props.controls.SelectedSlot(if selected == index then 0 else index)
			end,
			requests = requests,
			throwFlow = throwFlow,
			registry = registry,
			dragController = dragController,
		}),
	})
end)
