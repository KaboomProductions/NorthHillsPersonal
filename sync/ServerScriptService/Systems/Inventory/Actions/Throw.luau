--!strict

local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)

local throw = {}

function throw.handle(
	service: types.Service,
	player: Player,
	payload: protocol.ThrowPayload
): protocol.InventoryResponse
	return service.pendingThrows:throw(player, payload)
end

function throw.release(
	service: types.Service,
	player: Player,
	payload: protocol.ReleaseThrowPayload
): protocol.InventoryResponse
	return service.pendingThrows:release(player, payload)
end

return throw
