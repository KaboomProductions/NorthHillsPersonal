--!strict

local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)
local slotIndex = require(script.Parent.Parent.State.SlotIndex)
local dropPlacement = require(script.Parent.Parent.World.DropPlacement)
local types = require(script.Parent.Parent.Contracts)

local drop = {}

function drop.handle(service: types.Service, player: Player, payload: protocol.DropPayload): protocol.InventoryResponse
	if not service:unequipIfNeeded(player, payload.itemId) then
		return protocol.failure(protocol.ResponseCodes.busy)
	end
	return service:withLock(player, function(): protocol.InventoryResponse
		local state = service:getState(player)
		if state == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		local owned = slotIndex.findOwned(state, payload.itemId)
		if owned == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		if owned.item:GetAttribute("PendingTransaction") or slotIndex.isCurrent(state, owned.slot) then
			return protocol.failure(protocol.ResponseCodes.busy)
		end
		local pivot = dropPlacement.calculate(player, service.worldItems.folder, payload.dropDirection)
		if pivot == nil then
			return protocol.failure(protocol.ResponseCodes.notReady)
		end
		owned.slot.Value = nil
		service.placement.moveToWorld(owned.item, service.worldItems.folder, pivot)
		service:commit(player, { { zone = owned.zone, index = owned.index, item = nil } })
		return protocol.success()
	end) :: protocol.InventoryResponse
end

return drop
