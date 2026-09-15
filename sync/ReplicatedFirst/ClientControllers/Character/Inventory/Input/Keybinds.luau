--!strict

local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local inputBindings = require(replicatedFirst.ClientUtilities.InputBindings)
local bindingDefinitions = require(replicatedStorage.SharedAssets.Keybinds)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local inventoryStore = require(script.Parent.Parent.InventoryStore)
local inventoryRequests = require(script.Parent.Parent.Requests.InventoryRequests)
local selectionController = require(script.Parent.Parent.Selection)
local inventoryView = require(script.Parent.Parent.View)
local throwFlowController = require(script.Parent.Parent.Requests.ThrowFlow)

local keybinds = {}
keybinds.__index = keybinds

type Keybinds = {
	player: Player,
	store: inventoryStore.Store?,
	requests: inventoryRequests.Requests?,
	selection: selectionController.Selection?,
	view: inventoryView.View?,
	throwFlow: throwFlowController.ThrowFlow?,
	connections: { [string]: inputBindings.Connection },
	bindings: { [string]: inputBindings.Binding },
	_currentDescriptor: (self: Keybinds) -> protocol.ItemDescriptor?,
	_isBlocked: (self: Keybinds) -> boolean,
	_equip: (self: Keybinds, index: number) -> (),
	_cycle: (self: Keybinds, direction: number) -> (),
	_dropCurrent: (self: Keybinds) -> (),
	_isThrowable: (self: Keybinds, descriptor: protocol.ItemDescriptor) -> boolean,
	_throwCurrent: (self: Keybinds) -> (),
	init: (self: Keybinds) -> (),
	destroy: (self: Keybinds) -> (),
}

local function attachBinding(self: Keybinds, definition: bindingDefinitions.Action, callback: () -> ())
	local options = if definition == bindingDefinitions.toggleInventory
		then { priority = Enum.ContextActionPriority.High.Value, sink = false }
		else nil
	local binding = inputBindings.create(definition, options)
	self.bindings[definition.name] = binding
	self.connections[definition.name] = inputBindings.connect(binding, function(_active: boolean, pressed: boolean)
		if pressed then
			callback()
		end
	end)
end

type Options = {
	store: inventoryStore.Store,
	requests: inventoryRequests.Requests,
	selection: selectionController.Selection,
	view: inventoryView.View,
	throwFlow: throwFlowController.ThrowFlow,
}

function keybinds:init()
	attachBinding(self, bindingDefinitions.toggleInventory, function()
		local currentView = self.view :: inventoryView.View
		currentView:toggle()
	end)

	for slot, definition in bindingDefinitions.hotbarSlots do
		attachBinding(self, definition, function()
			self:_equip(slot)
		end)
	end

	attachBinding(self, bindingDefinitions.cycleHotbarNext, function()
		self:_cycle(1)
	end)
	attachBinding(self, bindingDefinitions.cycleHotbarPrevious, function()
		self:_cycle(-1)
	end)

	attachBinding(self, bindingDefinitions.dropItem, function()
		self:_dropCurrent()
	end)

	attachBinding(self, bindingDefinitions.throwItem, function()
		self:_throwCurrent()
	end)
end

function keybinds.new(options: Options): Keybinds
	local self: Keybinds = (
		setmetatable({
			player = players.LocalPlayer,
			store = options.store,
			requests = options.requests,
			selection = options.selection,
			view = options.view,
			throwFlow = options.throwFlow,
			connections = {},
			bindings = {},
		}, keybinds) :: unknown
	) :: Keybinds
	self:init()
	return self
end

function keybinds:_currentDescriptor(): protocol.ItemDescriptor?
	local state = (self.store :: inventoryStore.Store).state()
	return state.currentSlot and state.hotbar[tostring(state.currentSlot)] or nil
end

function keybinds:_isBlocked(): boolean
	return self.player:GetAttribute("InMenu") == true or not (self.store :: inventoryStore.Store):isEnabled()
end

function keybinds:_equip(index: number): ()
	if self:_isBlocked() then
		return
	end

	local selection = self.selection :: selectionController.Selection
	selection:setIntent(if selection.selectedSlot() == index then nil else index)
end

function keybinds:_cycle(direction: number): ()
	if self:_isBlocked() then
		return
	end

	local state = (self.store :: inventoryStore.Store).state()
	local selection = self.selection :: selectionController.Selection
	local start = selection.selectedSlot() or state.currentSlot or (if direction > 0 then 0 else 11)
	for offset = 1, 10 do
		local index = ((start - 1 + direction * offset) % 10) + 1
		if state.hotbar[tostring(index)] then
			selection:setIntent(index)
			return
		end
	end
end

function keybinds:_dropCurrent(): ()
	if self:_isBlocked() then
		return
	end

	local descriptor = self:_currentDescriptor()
	if not descriptor or typeof(descriptor.itemId) ~= "string" then
		return
	end

	local direction = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.zAxis
	local requests = self.requests :: inventoryRequests.Requests
	requests:drop(descriptor.itemId, direction)
end

function keybinds:_isThrowable(descriptor: protocol.ItemDescriptor): boolean
	if typeof(descriptor.itemType) ~= "string" then
		return false
	end

	local ok, throwable = pcall(itemUtils.getThrowableConfig, descriptor.itemType)
	return ok and throwable ~= nil
end

function keybinds:_throwCurrent(): ()
	if self:_isBlocked() then
		return
	end

	local descriptor = self:_currentDescriptor()
	if not descriptor or typeof(descriptor.itemId) ~= "string" or not self:_isThrowable(descriptor) then
		return
	end

	(self.throwFlow :: throwFlowController.ThrowFlow):throw(descriptor.itemId)
end

function keybinds:destroy(): ()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	for _, binding in self.bindings do
		binding:Destroy()
	end
	table.clear(self.bindings)
	self.store = nil
	self.requests = nil
	self.selection = nil
	self.view = nil
	self.throwFlow = nil
end

return keybinds
