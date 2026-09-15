--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local slotIndex = require(script.Parent.Parent.State.SlotIndex)
local types = require(script.Parent.Parent.Contracts)

local stacks = {}

function stacks.merge(
	service: types.Service,
	player: Player,
	payload: protocol.MergeStackPayload
): protocol.InventoryResponse
	return service:withLock(player, function(): protocol.InventoryResponse
		local state = service:getState(player)
		if state == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		local source = slotIndex.findOwned(state, payload.sourceItemId)
		local target = slotIndex.findOwned(state, payload.targetItemId)
		if source == nil or target == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		if slotIndex.isCurrent(state, source.slot) or slotIndex.isCurrent(state, target.slot) then
			return protocol.failure(protocol.ResponseCodes.busy)
		end
		if source.item:GetAttribute("PendingTransaction") or target.item:GetAttribute("PendingTransaction") then
			return protocol.failure(protocol.ResponseCodes.pending)
		end
		local config = itemUtils.getBaseConfig(source.item)
		if config == nil or not itemUtils.areStacksCompatible(source.item, target.item, config) then
			return protocol.failure(protocol.ResponseCodes.invalidStackCount)
		end
		local sourceCount = itemUtils.getStackCount(source.item, config)
		local targetCount = itemUtils.getStackCount(target.item, config)
		local amount = itemUtils.getMergeAmount(sourceCount, targetCount, itemUtils.getMaxStack(config))
		if amount <= 0 then
			return protocol.failure(protocol.ResponseCodes.invalidStackCount)
		end
		target.item:SetAttribute("StackCount", targetCount + amount)
		local remaining = sourceCount - amount
		if remaining == 0 then
			source.slot.Value = nil
			service.factory:destroy(source.item)
		else
			source.item:SetAttribute("StackCount", remaining)
		end
		service:commit(player, {
			{ zone = source.zone, index = source.index, item = if remaining > 0 then source.item else nil },
			{ zone = target.zone, index = target.index, item = target.item },
		})
		return protocol.success()
	end) :: protocol.InventoryResponse
end

function stacks.split(
	service: types.Service,
	player: Player,
	payload: protocol.SplitStackPayload
): protocol.InventoryResponse
	return service:withLock(player, function(): protocol.InventoryResponse
		local state = service:getState(player)
		if state == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		local source = slotIndex.findOwned(state, payload.itemId)
		local destination = service:getSlot(state, payload.toZone, payload.toIndex)
		if source == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		if source.item:GetAttribute("PendingTransaction") then
			return protocol.failure(protocol.ResponseCodes.pending)
		end
		if slotIndex.isCurrent(state, source.slot) then
			return protocol.failure(protocol.ResponseCodes.busy)
		end
		if destination == nil then
			return protocol.failure(protocol.ResponseCodes.invalidSlot)
		end
		if not itemUtils.canMoveToZone(source.item, payload.toZone) then
			return protocol.failure(protocol.ResponseCodes.invalidSlot)
		end
		if destination.Value then
			return protocol.failure(protocol.ResponseCodes.occupied)
		end
		local config = itemUtils.getBaseConfig(source.item)
		if config == nil then
			return protocol.failure(protocol.ResponseCodes.invalidPayload)
		end
		local count = itemUtils.getStackCount(source.item, config)
		if payload.count < 1 or payload.count >= count then
			return protocol.failure(protocol.ResponseCodes.invalidStackCount)
		end
		local newItem = service.factory:create(itemUtils.resolveItemType(source.item), {
			stackCount = payload.count,
			attributes = itemUtils.getPersistentAttributes(source.item, config) :: types.PersistentAttributes,
		})
		service.placement.moveToOwner(newItem, state.storedTools)
		destination.Value = newItem
		source.item:SetAttribute("StackCount", count - payload.count)
		service:commit(player, {
			{ zone = source.zone, index = source.index, item = source.item },
			{ zone = payload.toZone, index = payload.toIndex, item = newItem },
		})
		return protocol.success(itemUtils.makeDescriptor(newItem))
	end) :: protocol.InventoryResponse
end

return stacks
