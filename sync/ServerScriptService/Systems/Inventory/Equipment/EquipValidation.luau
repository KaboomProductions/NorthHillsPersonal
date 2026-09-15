--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)

type State = types.State

local equipValidation = {}

function equipValidation.desiredSlot(state: State, player: Player, slotNumber: number?): protocol.InventoryResponse?
	if player:HasTag("Busy") then
		return protocol.failure(protocol.ResponseCodes.busy)
	end
	if slotNumber == nil then
		return nil
	end
	local slot = state.hotbar:FindFirstChild(tostring(slotNumber))
	local item = slot and slot:IsA("ObjectValue") and slot.Value or nil
	local controllerClass = item and itemUtils.getControllerClass(item)
	if item == nil then
		return protocol.failure(protocol.ResponseCodes.invalidSlot)
	end
	if controllerClass == nil then
		return protocol.failure(protocol.ResponseCodes.notEquippable)
	end
	local pendingTransaction = item:GetAttribute("PendingTransaction")
	if pendingTransaction ~= nil then
		return protocol.failure(protocol.ResponseCodes.pending)
	end
	return nil
end

return equipValidation
