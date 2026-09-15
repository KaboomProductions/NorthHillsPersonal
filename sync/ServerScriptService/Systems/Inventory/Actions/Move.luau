--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local slotIndex = require(script.Parent.Parent.State.SlotIndex)
local types = require(script.Parent.Parent.Contracts)

local move = {}

local function isForbiddenDestination(
	sourceItem: Model,
	sourceZone: protocol.Zone,
	destinationZone: protocol.Zone,
	destinationItem: Model?,
	shouldSwap: boolean
): boolean
	if not itemUtils.canMoveToZone(sourceItem, destinationZone) then
		return true
	end

	return shouldSwap and destinationItem ~= nil and not itemUtils.canMoveToZone(destinationItem, sourceZone)
end

local function isPreflightForbidden(
	service: types.Service,
	player: Player,
	payload: protocol.MovePayload | protocol.SwapPayload
): boolean
	local state = service:getState(player)
	if state == nil then
		return false
	end

	local owned = slotIndex.findOwned(state, payload.itemId)
	local destination = service:getSlot(state, payload.toZone, payload.toIndex)
	if owned == nil or destination == nil or destination == owned.slot then
		return false
	end

	local destinationItem = destination.Value
	if destinationItem ~= nil and not destinationItem:IsA("Model") then
		return false
	end

	return isForbiddenDestination(
		owned.item,
		owned.zone,
		payload.toZone,
		destinationItem :: Model?,
		payload.action == protocol.Actions.swap
	)
end

function move.handle(
	service: types.Service,
	player: Player,
	payload: protocol.MovePayload | protocol.SwapPayload
): protocol.InventoryResponse
	if isPreflightForbidden(service, player, payload) then
		return protocol.failure(protocol.ResponseCodes.invalidSlot)
	end
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
		if owned.item:GetAttribute("PendingTransaction") then
			return protocol.failure(protocol.ResponseCodes.pending)
		end
		local destination = service:getSlot(state, payload.toZone, payload.toIndex)
		if destination == nil then
			return protocol.failure(protocol.ResponseCodes.invalidSlot)
		end
		if slotIndex.isCurrent(state, owned.slot) or slotIndex.isCurrent(state, destination) then
			return protocol.failure(protocol.ResponseCodes.busy)
		end
		if destination == owned.slot then
			return protocol.success()
		end
		local shouldSwap = payload.action == protocol.Actions.swap
		if destination.Value and not shouldSwap then
			return protocol.failure(protocol.ResponseCodes.occupied)
		end
		local destinationItem = destination.Value
		if destinationItem ~= nil and not destinationItem:IsA("Model") then
			return protocol.failure(protocol.ResponseCodes.invalidPayload)
		end
		local destinationModel: Model? = nil
		if destinationItem ~= nil then
			destinationModel = (destinationItem :: unknown) :: Model
		end
		if isForbiddenDestination(owned.item, owned.zone, payload.toZone, destinationModel, shouldSwap) then
			return protocol.failure(protocol.ResponseCodes.invalidSlot)
		end
		if destinationModel and destinationModel:GetAttribute("PendingTransaction") then
			return protocol.failure(protocol.ResponseCodes.pending)
		end
		owned.slot.Value = destinationModel
		destination.Value = owned.item
		service:commit(player, {
			{ zone = owned.zone, index = owned.index, item = destinationModel },
			{ zone = payload.toZone, index = payload.toIndex, item = owned.item },
		})
		return protocol.success()
	end) :: protocol.InventoryResponse
end

return move
