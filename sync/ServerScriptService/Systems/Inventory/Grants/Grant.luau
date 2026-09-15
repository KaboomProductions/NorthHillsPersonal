--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local allocator = require(script.Parent.Allocator)
local types = require(script.Parent.Parent.Contracts)
local itemFactory = require(script.Parent.Parent.Items.ItemFactory)
local itemPlacement = require(script.Parent.Parent.Items.ItemPlacement)

local grant = {}
grant.__index = grant

export type Grant = types.Grant
type Result = types.GrantResult
type Inventory = types.InventoryApi
type Factory = itemFactory.Factory
type Placement = itemPlacement.Placement

local function isValidItemRecord(factory: Factory, record: unknown): boolean
	local ok, valid = pcall(itemFactory.isValidRecord, record, factory.templates)
	return ok and valid == true
end

function grant.new(inventory: Inventory, factory: Factory, placement: Placement): Grant
	return (
		setmetatable({
			inventory = inventory,
			factory = factory,
			placement = placement,
			_emptyResult = grant._emptyResult,
			giveItem = grant.giveItem,
			addItem = grant.addItem,
			giveToSlot = grant.giveToSlot,
		}, grant) :: unknown
	) :: Grant
end

local function result(
	ok: boolean,
	code: protocol.ResponseCode,
	granted: number,
	remaining: number,
	items: { protocol.ItemDescriptor }
): Result
	return {
		ok = ok,
		code = code,
		granted = granted,
		remaining = remaining,
		items = items,
	}
end

function grant:_emptyResult(code: protocol.ResponseCode): Result
	return result(false, code, 0, 0, {})
end

function grant:giveItem(
	player: Player,
	itemType: string,
	count: number?,
	attributes: types.PersistentAttributes?
): Result
	-- This method acquires the inventory lock and must not be called inside withLock.
	if typeof(itemType) ~= "string" then
		return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
	end
	local requested = count or 1
	if typeof(requested) ~= "number" or requested % 1 ~= 0 or requested < 1 then
		return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
	end
	if materialUtils.isMaterialType(itemType) then
		warn(string.format("[Inventory] Rejected material %s from slot grant", itemType))
		return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
	end
	if self.factory.templates:getConfig(itemType) == nil or self.factory.templates:getTemplate(itemType) == nil then
		return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
	end
	return self.inventory:withLock(player, function()
		local state = self.inventory:getState(player)
		if state == nil then
			return self:_emptyResult(protocol.ResponseCodes.notReady)
		end
		local maxStack = itemUtils.getMaxStack(assert(self.factory.templates:getConfig(itemType)))
		local remaining = requested
		local granted = 0
		local items: { protocol.ItemDescriptor } = {}
		local changes: { types.AllocationChange } = {}
		while remaining > 0 do
			local chunk = math.min(remaining, maxStack)
			local item = self.factory:create(itemType, { stackCount = chunk, attributes = attributes })
			local allocation = allocator.allocate(state, item, self.placement, state.storedTools)
			granted += allocation.granted
			remaining -= allocation.granted
			for _, change in ipairs(allocation.changes) do
				table.insert(changes, change)
			end
			for _, descriptor in ipairs(allocation.items) do
				table.insert(items, descriptor)
			end
			if allocation.granted == 0 then
				self.factory:destroy(item)
				break
			end
			if allocation.remaining > 0 then
				item:SetAttribute("StackCount", allocation.remaining)
				self.factory:destroy(item)
				break
			end
		end
		if granted > 0 then
			self.inventory:commit(player, changes)
		end
		return result(
			granted > 0,
			if granted > 0 then protocol.ResponseCodes.ok else protocol.ResponseCodes.inventoryFull,
			granted,
			remaining,
			items
		)
	end)
end

function grant:addItem(player: Player, record: protocol.ItemRecord): Result
	-- This method acquires the inventory lock and must not be called inside withLock.
	if typeof(record) ~= "table" or typeof(record.itemType) ~= "string" then
		return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
	end
	if materialUtils.isMaterialType(record.itemType) then
		warn(string.format("[Inventory] Rejected material %s from slot grant", record.itemType))
		return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
	end
	if not isValidItemRecord(self.factory, record) then
		return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
	end
	return self.inventory:withLock(player, function()
		local state = self.inventory:getState(player)
		if state == nil then
			return self:_emptyResult(protocol.ResponseCodes.notReady)
		end
		local ok, item = pcall(self.factory.materialize, self.factory, record)
		if not ok then
			return self:_emptyResult(protocol.ResponseCodes.invalidPayload)
		end
		local allocation = allocator.allocate(state, item, self.placement, state.storedTools)
		if allocation.granted == 0 then
			self.factory:destroy(item)
			return result(false, protocol.ResponseCodes.inventoryFull, 0, record.stackCount, {})
		end
		if allocation.remaining > 0 then
			self.factory:destroy(item)
		end
		self.inventory:commit(player, allocation.changes)
		return result(true, protocol.ResponseCodes.ok, allocation.granted, allocation.remaining, allocation.items)
	end)
end

function grant:giveToSlot(
	player: Player,
	record: protocol.ItemRecord,
	zone: protocol.Zone,
	index: number
): protocol.InventoryResponse
	-- This method acquires the inventory lock and must not be called inside withLock.
	if typeof(record) ~= "table" or typeof(record.itemType) ~= "string" then
		return protocol.failure(protocol.ResponseCodes.invalidPayload)
	end
	if materialUtils.isMaterialType(record.itemType) then
		warn(string.format("[Inventory] Rejected material %s from direct slot grant", record.itemType))
		return protocol.failure(protocol.ResponseCodes.invalidPayload)
	end
	if not isValidItemRecord(self.factory, record) then
		return protocol.failure(protocol.ResponseCodes.invalidPayload)
	end
	return self.inventory:withLock(player, function()
		local state = self.inventory:getState(player)
		if state == nil then
			return protocol.failure(protocol.ResponseCodes.notReady)
		end
		if not itemUtils.canMoveToZone(record.itemType, zone) then
			return protocol.failure(protocol.ResponseCodes.invalidSlot)
		end
		local slot = self.inventory:getSlot(state, zone, index)
		if slot == nil then
			return protocol.failure(protocol.ResponseCodes.invalidSlot)
		end
		if slot.Value ~= nil then
			return protocol.failure(protocol.ResponseCodes.occupied)
		end
		local ok, item = pcall(self.factory.materialize, self.factory, record)
		if not ok then
			return protocol.failure(protocol.ResponseCodes.invalidPayload)
		end
		self.placement.moveToOwner(item, state.storedTools)
		slot.Value = item
		self.inventory:commit(player, { { zone = zone, index = index, item = item } })
		return protocol.success(itemUtils.makeDescriptor(item))
	end)
end

return grant
