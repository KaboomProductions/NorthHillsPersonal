--!strict

local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)
local mouseUnlock = require(replicatedFirst.ClientControllers.Player.Interface.MouseUnlock)

local SlotRegistry = require(script.Parent.Drag.SlotRegistry)
local DragController = require(script.Parent.Drag.DragController)
local DragLayer = require(script.Parent.Drag.DragLayer)
local InventoryRequests = require(script.Parent.Requests.InventoryRequests)
local InventoryStore = require(script.Parent.InventoryStore)
local Selection = require(script.Parent.Selection)
local ThrowFlow = require(script.Parent.Requests.ThrowFlow)
local HotbarView = require(script.Hotbar.HotbarView)
local InventoryPanel = require(script.Panel.InventoryPanel)

local create = vide.create
local view = {}
view.__index = view

export type View = {
	store: InventoryStore.Store?,
	requests: InventoryRequests.Requests?,
	selection: Selection.Selection?,
	throwFlow: ThrowFlow.ThrowFlow?,
	isOpen: InventoryStore.Source<boolean>,
	mouseToken: mouseUnlock.MouseRequestToken?,
	registry: SlotRegistry.SlotRegistry,
	layer: DragLayer.DragLayer,
	dragController: DragController.DragController,
	unmount: (() -> ())?,
	destroyed: boolean,
	equip: (self: View, index: number) -> (),
	setOpen: (self: View, open: boolean) -> (),
	toggle: (self: View) -> (),
	destroy: (self: View) -> (),
}

function view.new(
	store: InventoryStore.Store,
	requests: InventoryRequests.Requests,
	selection: Selection.Selection,
	throwFlow: ThrowFlow.ThrowFlow
): View
	local self: View = (setmetatable({}, view) :: unknown) :: View
	self.store = store
	self.requests = requests
	self.selection = selection
	self.throwFlow = throwFlow
	self.isOpen = vide.source(false) :: InventoryStore.Source<boolean>
	self.mouseToken = nil
	self.registry = SlotRegistry.new()
	local interface = players.LocalPlayer.PlayerGui:WaitForChild("Interface")
	local old = interface:FindFirstChild("Inventory")
	if old then
		old:Destroy()
	end
	self.layer = DragLayer.new(interface)
	self.dragController = DragController.new(store, requests, self.registry, self.layer)
	local viewState: InventoryStore.StateSource = function()
		local state = table.clone(store.state()) :: InventoryStore.ReadOnlyState
		state.currentSlot = selection.selectedSlot()
		return state
	end
	self.unmount = vide.mount(function()
		return create("Frame")({
			Name = "Inventory",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			HotbarView({
				state = viewState,
				onEquip = function(index)
					self:equip(index)
				end,
				registry = self.registry,
				dragController = self.dragController,
			}),
			InventoryPanel({
				state = viewState,
				isOpen = self.isOpen,
				onEquip = function(index)
					self:equip(index)
				end,
				requests = requests,
				throwFlow = throwFlow,
				registry = self.registry,
				dragController = self.dragController,
			}),
		})
	end, interface)
	return self
end

function view:equip(index: number): ()
	local store = self.store
	local selection = self.selection
	if store == nil or selection == nil or not store:isEnabled() then
		return
	end
	selection:setIntent(if selection.selectedSlot() == index then nil else index)
end

function view.setOpen(self: View, open: boolean): ()
	if self.isOpen() == open then
		return
	end
	local setOpen = (self.isOpen :: unknown) :: (boolean) -> boolean
	setOpen(open)
	if open then
		self.mouseToken = mouseUnlock.acquire("inventory")
		return
	end

	local mouseToken = self.mouseToken
	if mouseToken then
		mouseUnlock.release(mouseToken)
	end
	self.mouseToken = nil
end

function view:toggle(): ()
	self:setOpen(not self.isOpen())
end

function view:destroy(): ()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:setOpen(false)
	local unmount = self.unmount
	self.unmount = nil
	if unmount then
		unmount()
	end
	self.dragController:destroy()
	self.layer:destroy()
	self.registry:clear()
	self.store = nil
	self.requests = nil
	self.selection = nil
	self.throwFlow = nil
end

return view
