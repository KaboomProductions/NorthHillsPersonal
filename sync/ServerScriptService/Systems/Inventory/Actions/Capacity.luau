--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local slotIndex = require(script.Parent.Parent.State.SlotIndex)
local types = require(script.Parent.Parent.Contracts)

local capacity = {}

function capacity.handle(
	service: types.Service,
	player: Player,
	payload: protocol.CapacityUpgradePayload
): protocol.InventoryResponse
	return service:withLock(player, function(): protocol.InventoryResponse
		local state = service:getState(player)
		if state == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		local owned = slotIndex.findOwned(state, payload.itemId)
		if owned == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		if slotIndex.isCurrent(state, owned.slot) then
			return protocol.failure(protocol.ResponseCodes.busy)
		end
		if owned.item:GetAttribute("PendingTransaction") then
			return protocol.failure(protocol.ResponseCodes.pending)
		end
		local increase = itemUtils.getCapacityIncrease(owned.item)
		if increase == nil or not protocol.isFiniteNumber(increase) or increase % 1 ~= 0 or increase < 1 then
			return protocol.failure(protocol.ResponseCodes.invalidPayload)
		end
		if state.storageCapacity >= protocol.Limits.storageCapacityMaximum then
			return protocol.failure(protocol.ResponseCodes.capacityMax)
		end
		state.storageCapacity = math.min(state.storageCapacity + increase, protocol.Limits.storageCapacityMaximum)
		state.ensureStorageSlots(state.storageCapacity)
		owned.slot.Value = nil
		service.factory:destroy(owned.item)
		service:commit(player, {
			{ zone = owned.zone, index = owned.index, item = nil },
		}, { storageCapacity = state.storageCapacity })
		return protocol.success()
	end) :: protocol.InventoryResponse
end

return capacity
