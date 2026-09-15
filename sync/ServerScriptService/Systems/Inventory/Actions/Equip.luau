--!strict

local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)

local equip = {}

function equip.handle(
	service: types.Service,
	player: Player,
	payload: protocol.EquipPayload | protocol.UnequipPayload
): protocol.InventoryResponse
	local state = service:getState(player)
	if state == nil or state.equipTransition == nil then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	return state.equipTransition:setDesiredSlot(
		if payload.action == protocol.Actions.equip then payload.slotNumber else nil,
		payload.intentSequence
	)
end

return equip
