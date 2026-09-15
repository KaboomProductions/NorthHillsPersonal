--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)
local playerState = require(script.Parent.Parent.State.PlayerState)
local itemPlacement = require(script.Parent.Parent.Items.ItemPlacement)
local itemIds = require(script.Parent.Parent.Items.ItemIds)

export type Allocation = types.Allocation
export type Change = types.AllocationChange

type State = playerState.State
type Placement = itemPlacement.Placement

local allocator = {}

export type Entry = { zone: protocol.Zone, index: number, slot: ObjectValue }

local function entries(state: State): { Entry }
	local result: { Entry } = {}
	local zones: { protocol.Zone } = { protocol.Zones.storage, protocol.Zones.hotbar }
	for _, zone in ipairs(zones) do
		local folder = if zone == protocol.Zones.storage then state.storage else state.hotbar
		local maximum = if zone == protocol.Zones.storage then state.storageCapacity else protocol.Limits.hotbarCapacity
		for index = 1, maximum do
			local slot = folder:FindFirstChild(tostring(index))
			if slot and slot:IsA("ObjectValue") then
				table.insert(result, { zone = zone :: protocol.Zone, index = index, slot = slot })
			end
		end
	end
	return result
end

function allocator.allocate(state: State, item: Model, placement: Placement, storedTools: Folder): Allocation
	local itemType = itemUtils.resolveItemType(item)
	assert(not materialUtils.isMaterialType(itemType), "Materials cannot be allocated to inventory slots")
	local config = assert(itemUtils.getBaseConfig(itemType), "ItemConfig is missing")
	local remaining = itemUtils.getStackCount(item, config)
	local granted = 0
	local changes: { Change } = {}
	local itemDescriptors: { protocol.ItemDescriptor } = {}
	local allEntries = entries(state)

	for _, entry in ipairs(allEntries) do
		local target = entry.slot.Value
		if remaining <= 0 then
			break
		end
		if
			target
			and itemUtils.canMoveToZone(itemType, entry.zone)
			and target:IsA("Model")
			and target:GetAttribute("PendingTransaction") == nil
			and itemUtils.areStacksCompatible(item, target, config)
		then
			local targetCount = itemUtils.getStackCount(target, config)
			local amount = itemUtils.getMergeAmount(remaining, targetCount, itemUtils.getMaxStack(config))
			if amount > 0 then
				target:SetAttribute("StackCount", targetCount + amount)
				remaining -= amount
				granted += amount
				table.insert(changes, { zone = entry.zone, index = entry.index, item = target })
				local descriptor = itemUtils.makeDescriptor(target)
				if descriptor then
					table.insert(itemDescriptors, descriptor :: protocol.ItemDescriptor)
				end
			end
		end
	end

	if remaining > 0 then
		for _, entry in ipairs(allEntries) do
			if entry.slot.Value == nil and itemUtils.canMoveToZone(itemType, entry.zone) then
				item:SetAttribute("StackCount", remaining)
				placement.moveToOwner(item, storedTools)
				entry.slot.Value = item
				granted += remaining
				table.insert(changes, { zone = entry.zone, index = entry.index, item = item })
				local descriptor = itemUtils.makeDescriptor(item)
				if descriptor then
					table.insert(itemDescriptors, descriptor :: protocol.ItemDescriptor)
				end
				remaining = 0
				break
			end
		end
	end

	if remaining == 0 and item.Parent == nil then
		itemIds.release(item)
		item:Destroy()
	end

	return {
		granted = granted,
		remaining = remaining,
		changes = changes,
		items = itemDescriptors,
	}
end

function allocator.entries(state: State): { Entry }
	return entries(state)
end

return allocator
