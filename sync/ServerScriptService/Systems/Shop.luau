local replicatedStorage = game:GetService("ReplicatedStorage")

local networking = require(replicatedStorage.Communication.Networking)

local shopController = {}
shopController.__index = shopController

type ShopRequestPayload = {
	action: string,
	itemId: string,
}

function shopController:handleRequest(_player: Player, shopRequestPayload: ShopRequestPayload): any?
	if shopRequestPayload.action == "buy" then
		return nil
	end

	return nil
end

function shopController.new()
	local self = setmetatable({}, shopController)

	networking.requests.shopRequest.OnServerInvoke = function(player: Player, shopRequestPayload: any)
		if type(shopRequestPayload) ~= "table" then
			return nil
		end

		if type(shopRequestPayload.action) ~= "string" then
			return nil
		end

		return self:handleRequest(player, shopRequestPayload)
	end

	return self
end

return shopController
