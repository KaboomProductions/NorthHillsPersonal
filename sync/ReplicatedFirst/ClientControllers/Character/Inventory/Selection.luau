--!nonstrict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local InventoryStore = require(script.Parent.InventoryStore)
local InventoryRequests = require(script.Parent.Requests.InventoryRequests)

local selection = {}
selection.__index = selection

local intentTimeoutSeconds = 10
local lastIssuedIntentSequence = 0

type Pending = {
	slot: number?,
	sequence: number,
}

export type Selection = {
	store: InventoryStore.Store?,
	requests: InventoryRequests.Requests?,
	selectedSlot: () -> number?,
	_selectedSlot: InventoryStore.Source<number?>,
	pending: Pending?,
	intentSequence: number,
	changed: BindableEvent,
	storeConnection: RBXScriptConnection?,
	destroyed: boolean,
	_setSelected: (self: Selection, slotNumber: number?) -> (),
	_nextSequence: (self: Selection) -> number,
	_send: (self: Selection, pending: Pending) -> (),
	_handleResponse: (self: Selection, pending: Pending, response: protocol.InventoryResponse) -> (),
	_revert: (self: Selection) -> (),
	selectedDescriptor: (self: Selection) -> protocol.ItemDescriptor?,
	setIntent: (self: Selection, slotNumber: number?) -> (),
	isPending: (self: Selection) -> boolean,
	destroy: (self: Selection) -> (),
}

local function getDescriptor(state: InventoryStore.ReadOnlyState, slotNumber: number?): protocol.ItemDescriptor?
	if slotNumber == nil then
		return nil
	end
	return state.hotbar[tostring(slotNumber)]
end

function selection.new(store: InventoryStore.Store, requests: InventoryRequests.Requests): Selection
	local serverSequence = math.floor(workspace:GetServerTimeNow() * 1000)
	lastIssuedIntentSequence = math.max(lastIssuedIntentSequence, serverSequence)
	local selectedSource = vide.source(store.state().currentSlot) :: InventoryStore.Source<number?>
	local self: Selection = (
		setmetatable({
			store = store,
			requests = requests,
			selectedSlot = function(): number?
				return selectedSource()
			end,
			_selectedSlot = selectedSource,
			pending = nil,
			intentSequence = lastIssuedIntentSequence,
			changed = Instance.new("BindableEvent"),
			storeConnection = nil,
			destroyed = false,
		}, selection) :: unknown
	) :: Selection

	self.storeConnection = store.changed.Event:Connect(function()
		if self.destroyed then
			return
		end
		local state = store.state()
		local pending = self.pending
		if
			pending
			and state.equipIntentSequence >= pending.sequence
			and state.currentSlot == pending.slot
		then
			self.pending = nil
		elseif pending == nil then
			self:_setSelected(state.currentSlot)
		end
	end)
	return self
end

function selection._setSelected(self: Selection, slotNumber: number?): ()
	if self.selectedSlot() == slotNumber then
		return
	end
	self._selectedSlot(slotNumber)
	self.changed:Fire(slotNumber)
end

function selection._nextSequence(self: Selection): number
	local serverSequence = math.floor(workspace:GetServerTimeNow() * 1000)
	lastIssuedIntentSequence = math.max(lastIssuedIntentSequence + 1, serverSequence)
	self.intentSequence = lastIssuedIntentSequence
	return self.intentSequence
end

function selection._revert(self: Selection): ()
	local store = self.store
	if store == nil then
		return
	end
	self.pending = nil
	self:_setSelected(store.state().currentSlot)
end

function selection._handleResponse(self: Selection, pending: Pending, response: protocol.InventoryResponse): ()
	if self.destroyed or self.pending ~= pending then
		return
	end
	if response.ok then
		local data = response.data
		if typeof(data) == "table" and (data :: { [string]: unknown }).superseded == true then
			self:_revert()
			return
		end
		return
	end
	self:_revert()
end

function selection._send(self: Selection, pending: Pending): ()
	local requests = self.requests
	if self.destroyed or requests == nil or self.pending ~= pending then
		return
	end

	task.spawn(function()
		local response = if pending.slot == nil
			then requests:unequip(pending.sequence)
			else requests:equip(pending.slot, pending.sequence)
		if response ~= nil then
			self:_handleResponse(pending, response)
		end
	end)
end

function selection:setIntent(slotNumber: number?): ()
	local store = self.store
	local requests = self.requests
	if self.destroyed or store == nil or requests == nil or not store:isEnabled() then
		return
	end
	local pending: Pending = {
		slot = slotNumber,
		sequence = self:_nextSequence(),
	}
	self.pending = pending
	self:_setSelected(slotNumber)
	self:_send(pending)

	task.delay(intentTimeoutSeconds, function()
		if not self.destroyed and self.pending == pending then
			self:_revert()
		end
	end)
end

function selection:selectedDescriptor(): protocol.ItemDescriptor?
	local store = self.store
	if store == nil then
		return nil
	end
	return getDescriptor(store.state(), self.selectedSlot())
end

function selection:isPending(): boolean
	return self.pending ~= nil
end

function selection:destroy(): ()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.storeConnection then
		self.storeConnection:Disconnect()
		self.storeConnection = nil
	end
	self.pending = nil
	self.store = nil
	self.requests = nil
	self.changed:Destroy()
end

return selection
