--!strict

local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)

local router = {}
router.__index = router

type Service = types.Service
type Handler = types.RouterHandler

function router.new(service: Service): types.Router
	local actions: { [string]: Handler } = {
		[protocol.Actions.equip] = function(player, payload)
			return require(script.Parent.Parent.Actions.Equip).handle(service, player, payload :: protocol.EquipPayload)
		end,
		[protocol.Actions.unequip] = function(player, payload)
			return require(script.Parent.Parent.Actions.Equip).handle(
				service,
				player,
				payload :: protocol.UnequipPayload
			)
		end,
		[protocol.Actions.move] = function(player, payload)
			return require(script.Parent.Parent.Actions.Move).handle(service, player, payload :: protocol.MovePayload)
		end,
		[protocol.Actions.swap] = function(player, payload)
			return require(script.Parent.Parent.Actions.Move).handle(service, player, payload :: protocol.SwapPayload)
		end,
		[protocol.Actions.mergeStack] = function(player, payload)
			return require(script.Parent.Parent.Actions.Stacks).merge(
				service,
				player,
				payload :: protocol.MergeStackPayload
			)
		end,
		[protocol.Actions.splitStack] = function(player, payload)
			return require(script.Parent.Parent.Actions.Stacks).split(
				service,
				player,
				payload :: protocol.SplitStackPayload
			)
		end,
		[protocol.Actions.drop] = function(player, payload)
			return require(script.Parent.Parent.Actions.Drop).handle(service, player, payload :: protocol.DropPayload)
		end,
		[protocol.Actions.upgrade] = function(player, payload)
			return require(script.Parent.Parent.Actions.Upgrade).handle(
				service,
				player,
				payload :: protocol.UpgradePayload
			)
		end,
		[protocol.Actions.useCapacityUpgrade] = function(player, payload)
			return require(script.Parent.Parent.Actions.Capacity).handle(
				service,
				player,
				payload :: protocol.CapacityUpgradePayload
			)
		end,
		[protocol.Actions.throw] = function(player, payload)
			return require(script.Parent.Parent.Actions.Throw).handle(service, player, payload :: protocol.ThrowPayload)
		end,
		[protocol.Actions.releaseThrow] = function(player, payload)
			return require(script.Parent.Parent.Actions.Throw).release(
				service,
				player,
				payload :: protocol.ReleaseThrowPayload
			)
		end,
	}
	return (setmetatable({ actions = actions, route = router.route }, router) :: unknown) :: types.Router
end

function router.route(self: types.Router, player: Player, payload: protocol.ActionPayload): protocol.InventoryResponse
	local handler = self.actions[payload.action]
	if handler == nil then
		return protocol.failure(protocol.ResponseCodes.invalidPayload)
	end
	return handler(player, payload)
end

return router
