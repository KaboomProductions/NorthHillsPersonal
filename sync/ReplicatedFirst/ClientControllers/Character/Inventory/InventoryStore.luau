--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local vide = require(replicatedStorage.ExternalLibraries.vide)
local Replica = require(replicatedStorage.ExternalLibraries.replica)

local inventoryStore = {}
inventoryStore.__index = inventoryStore

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type ReadOnlyState = protocol.InventoryState

export type Source<T> = (() -> T) & ((value: T) -> T)

export type StateSource = () -> ReadOnlyState

export type Replica = {
	Data: { [string]: unknown },
	OnChange: (self: Replica, callback: (...unknown) -> ()) -> Connection,
}

export type Store = {
	state: Source<ReadOnlyState>,
	changed: BindableEvent,
	connections: { [string]: Connection? },
	changeConnection: Connection?,
	replica: Replica?,
	destroyed: boolean,
	_publish: (self: Store, nextState: ReadOnlyState) -> (),
	_attach: (self: Store, replica: Replica) -> (),
	isEnabled: (self: Store) -> boolean,
	findItem: (self: Store, itemId: string) -> (protocol.Zone?, number?, protocol.ItemDescriptor?),
	destroy: (self: Store) -> (),
}

local function emptyState(): ReadOnlyState
	return {
		enabled = true,
		disabledReason = nil,
		storageCapacity = protocol.Limits.storageCapacityDefault,
		currentSlot = nil,
		equipIntentSequence = 0,
		hotbar = {},
		storage = {},
		materials = {},
	}
end

local function cloneMap(value: unknown): { [string]: protocol.ItemDescriptor }
	local result: { [string]: protocol.ItemDescriptor } = {}
	if typeof(value) ~= "table" then
		return result
	end

	local typedValue = value :: { [string]: unknown }
	for key, descriptor in typedValue do
		if typeof(key) == "string" and typeof(descriptor) == "table" then
			result[key] = descriptor :: protocol.ItemDescriptor
		end
	end

	return result
end

local function cloneNumberMap(value: unknown): { [string]: number }
	local result: { [string]: number } = {}
	if typeof(value) ~= "table" then
		return result
	end
	local typedValue = value :: { [string]: unknown }
	for key, amount in typedValue do
		if typeof(key) == "string" and typeof(amount) == "number" then
			result[key] = amount
		end
	end
	return result
end

local function readReplica(replica: Replica): ReadOnlyState
	local data = replica.Data
	return {
		enabled = data.enabled ~= false,
		disabledReason = if typeof(data.disabledReason) == "string" then data.disabledReason else nil,
		storageCapacity = if typeof(data.storageCapacity) == "number"
			then data.storageCapacity
			else protocol.Limits.storageCapacityDefault,
		currentSlot = if typeof(data.currentSlot) == "number" then data.currentSlot else nil,
		equipIntentSequence = if typeof(data.equipIntentSequence) == "number" then data.equipIntentSequence else 0,
		hotbar = cloneMap(data.hotbar),
		storage = cloneMap(data.storage),
		materials = cloneNumberMap(data.materials),
	}
end

function inventoryStore.new(): Store
	local self = (
		setmetatable({
			state = vide.source(emptyState()) :: Source<ReadOnlyState>,
			changed = Instance.new("BindableEvent"),
			connections = {} :: { [string]: Connection? },
			changeConnection = nil,
			replica = nil,
			destroyed = false,
		}, inventoryStore) :: unknown
	) :: Store

	self.connections.newReplica = (Replica.OnNew :: (string, (Replica) -> ()) -> Connection)(
		"Inventory",
		function(replica: Replica)
			self:_attach(replica)
		end
	)
	return self
end

function inventoryStore:_publish(nextState: ReadOnlyState)
	if self.destroyed then
		return
	end
	self.state(nextState)
	self.changed:Fire(nextState)
end

function inventoryStore:_attach(replica: Replica)
	if self.destroyed or self.replica == replica then
		return
	end
	local oldChangeConnection = self.changeConnection
	if oldChangeConnection then
		oldChangeConnection:Disconnect()
	end
	self.replica = replica
	self:_publish(readReplica(replica))
	self.changeConnection = replica:OnChange(function()
		self:_publish(readReplica(replica))
	end)
end

function inventoryStore:isEnabled(): boolean
	return self.state().enabled
end

function inventoryStore:findItem(itemId: string): (protocol.Zone?, number?, protocol.ItemDescriptor?)
	local state: ReadOnlyState = self.state()
	local zones: { protocol.Zone } = { protocol.Zones.hotbar, protocol.Zones.storage }
	for _, zone in ipairs(zones) do
		local map = if zone == protocol.Zones.hotbar then state.hotbar else state.storage
		local typedMap = map :: { [string]: protocol.ItemDescriptor }
		for key, descriptor in typedMap do
			if descriptor.itemId == itemId then
				local index: number? = tonumber(key)
				if index ~= nil then
					return zone :: protocol.Zone, index, descriptor
				end
			end
		end
	end
	return nil, nil, nil
end

function inventoryStore:destroy(): ()
	if self.destroyed then
		return
	end
	self.destroyed = true
	local changeConnection = self.changeConnection
	if changeConnection then
		changeConnection:Disconnect()
	end
	for _, connection in self.connections do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(self.connections)
	self.changed:Destroy()
	self.replica = nil
end

return inventoryStore
