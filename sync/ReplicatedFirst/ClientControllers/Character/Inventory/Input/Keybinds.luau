--!strict

local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local inputHelpers = require(replicatedFirst.ClientUtilities.InputHelpers)
local InputActionService = require(replicatedStorage.SharedUtilities.InputActionService)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local InventoryStore = require(script.Parent.Parent.InventoryStore)
local InventoryRequests = require(script.Parent.Parent.Requests.InventoryRequests)
local Selection = require(script.Parent.Parent.Selection)
local View = require(script.Parent.Parent.View)
local ThrowFlow = require(script.Parent.Parent.Requests.ThrowFlow)

local keybinds = {}
keybinds.__index = keybinds

local keySlots = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

type Keybinds = {
	player: Player,
	store: InventoryStore.Store?,
	requests: InventoryRequests.Requests?,
	selection: Selection.Selection?,
	view: View.View?,
	throwFlow: ThrowFlow.ThrowFlow?,
	connections: { [string]: InputActionService.IAScriptConnection },
	bindings: { [string]: InputActionService.BindingObject },
	_currentDescriptor: (self: Keybinds) -> protocol.ItemDescriptor?,
	_isBlocked: (self: Keybinds) -> boolean,
	_equip: (self: Keybinds, index: number) -> (),
	_cycle: (self: Keybinds, direction: number) -> (),
	_dropCurrent: (self: Keybinds) -> (),
	_isThrowable: (self: Keybinds, descriptor: protocol.ItemDescriptor) -> boolean,
	_throwCurrent: (self: Keybinds) -> (),
	destroy: (self: Keybinds) -> (),
}

local function attachBinding(
	self: Keybinds,
	name: string,
	keyCodes: { Enum.KeyCode },
	callback: () -> (),
	priority: number?,
	sink: boolean?
)
	local binding = InputActionService.new(name, Enum.InputActionType.Bool)
	if priority ~= nil then
		binding:SetPriority(priority)
	end
	if sink ~= nil then
		binding:SetSink(sink)
	end
	inputHelpers.attachAllKeysToInput(binding, keyCodes)
	self.bindings[name] = binding
	self.connections[name] = binding.Activated:Connect(function(_active: InputActionService.variant, pressed: boolean?)
		if not pressed then
			return
		end

		callback()
	end)
end

function keybinds.new(
	store: InventoryStore.Store,
	requests: InventoryRequests.Requests,
	selection: Selection.Selection,
	view: View.View,
	throwFlow: ThrowFlow.ThrowFlow
): Keybinds
	local self: Keybinds = (
		setmetatable({
			player = players.LocalPlayer,
			store = store,
			requests = requests,
			selection = selection,
			view = view,
			throwFlow = throwFlow,
			connections = {} :: { [string]: InputActionService.IAScriptConnection },
			bindings = {} :: { [string]: InputActionService.BindingObject },
		}, keybinds) :: unknown
	) :: Keybinds

	attachBinding(self, "toggleInventory", { Enum.KeyCode.I }, function()
		local currentView = self.view :: View.View
		currentView:toggle()
	end, Enum.ContextActionPriority.High.Value, false)

	for keyCode, index in keySlots do
		local slot = index
		attachBinding(self, "equipSlot" .. slot, { keyCode }, function()
			self:_equip(slot)
		end)
	end

	attachBinding(self, "cycleHotbarNext", { Enum.KeyCode.ButtonR1 }, function()
		self:_cycle(1)
	end)
	attachBinding(self, "cycleHotbarPrevious", { Enum.KeyCode.ButtonL1 }, function()
		self:_cycle(-1)
	end)

	attachBinding(self, "dropItem", { Enum.KeyCode.Backspace }, function()
		self:_dropCurrent()
	end)

	attachBinding(self, "throwItem", { Enum.KeyCode.G }, function()
		self:_throwCurrent()
	end)

	return self
end

function keybinds:_currentDescriptor(): protocol.ItemDescriptor?
	local state = (self.store :: InventoryStore.Store).state()
	return state.currentSlot and state.hotbar[tostring(state.currentSlot)] or nil
end

function keybinds:_isBlocked(): boolean
	return self.player:GetAttribute("InMenu") == true or not (self.store :: InventoryStore.Store):isEnabled()
end

function keybinds:_equip(index: number): ()
	if self:_isBlocked() then
		return
	end

	local selection = self.selection :: Selection.Selection
	selection:setIntent(if selection.selectedSlot() == index then nil else index)
end

function keybinds:_cycle(direction: number): ()
	if self:_isBlocked() then
		return
	end

	local state = (self.store :: InventoryStore.Store).state()
	local selection = self.selection :: Selection.Selection
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
	local requests = self.requests :: InventoryRequests.Requests
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

	(self.throwFlow :: ThrowFlow.ThrowFlow):throw(descriptor.itemId)
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
