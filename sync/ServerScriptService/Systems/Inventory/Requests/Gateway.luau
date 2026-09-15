--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local rateLimiter = require(script.Parent.RateLimiter)
local router = require(script.Parent.Router)
local types = require(script.Parent.Parent.Contracts)

local gateway = {}
gateway.__index = gateway

function gateway.new(service: types.Service, remote: RemoteFunction): types.Gateway
	local self = (
		setmetatable({
			service = service,
			remote = remote,
			limiter = rateLimiter.new(30, 1),
			router = router.new(service),
			_invoke = gateway._invoke,
			clear = gateway.clear,
			destroy = gateway.destroy,
		}, gateway) :: unknown
	) :: types.Gateway
	remote.OnServerInvoke = function(player: Player, rawPayload: unknown)
		return self:_invoke(player, rawPayload)
	end
	return self
end

function gateway._invoke(self: types.Gateway, player: Player, rawPayload: unknown): protocol.InventoryResponse
	if not self.limiter:consume(player) then
		return protocol.failure(protocol.ResponseCodes.rateLimited)
	end
	local payload, code = protocol.validateRequest(rawPayload)
	if payload == nil then
		return protocol.failure((code or protocol.ResponseCodes.invalidPayload) :: protocol.ResponseCode)
	end
	local state = self.service:getState(player)
	if state == nil then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	if not self.service:isEnabled(player) then
		return protocol.failure(protocol.ResponseCodes.disabled)
	end
	return self.service:withPlayerAction(player, function()
		return self.router:route(player, payload)
	end)
end

function gateway.clear(self: types.Gateway, player: Player): ()
	self.limiter:clear(player)
end

function gateway.destroy(self: types.Gateway): ()
	self.remote.OnServerInvoke = function()
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	self.limiter:destroy()
end

return gateway
