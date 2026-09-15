--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local InventoryStore = require(script.Parent.Parent.InventoryStore)

local inventoryRequests = {}
inventoryRequests.__index = inventoryRequests

export type Requests = {
	remote: RemoteFunction?,
	store: InventoryStore.Store?,
	inFlight: { [protocol.ActionName]: boolean },
	generation: number,
	_invoke: (self: Requests, payload: protocol.ActionPayload) -> protocol.InventoryResponse?,
	equip: (self: Requests, slotNumber: number, intentSequence: number) -> protocol.InventoryResponse?,
	unequip: (self: Requests, intentSequence: number) -> protocol.InventoryResponse?,
	move: (self: Requests, itemId: string, zone: protocol.Zone, index: number) -> protocol.InventoryResponse?,
	swap: (self: Requests, itemId: string, zone: protocol.Zone, index: number) -> protocol.InventoryResponse?,
	mergeStack: (self: Requests, sourceItemId: string, targetItemId: string) -> protocol.InventoryResponse?,
	splitStack: (
		self: Requests,
		itemId: string,
		count: number,
		zone: protocol.Zone,
		index: number
	) -> protocol.InventoryResponse?,
	drop: (self: Requests, itemId: string, direction: Vector3) -> protocol.InventoryResponse?,
	upgrade: (self: Requests, itemId: string, upgradeId: string) -> protocol.InventoryResponse?,
	useCapacityUpgrade: (self: Requests, itemId: string) -> protocol.InventoryResponse?,
	throw: (self: Requests, itemId: string, direction: Vector3) -> protocol.InventoryResponse?,
	releaseThrow: (self: Requests, throwId: string) -> protocol.InventoryResponse?,
	destroy: (self: Requests) -> (),
}

function inventoryRequests.new(remote: RemoteFunction, store: InventoryStore.Store): Requests
	return (
		setmetatable({
			remote = remote,
			store = store,
			inFlight = {} :: { [protocol.ActionName]: boolean },
			generation = 0,
		}, inventoryRequests) :: unknown
	) :: Requests
end

function inventoryRequests:_invoke(payload: protocol.ActionPayload): protocol.InventoryResponse?
	local store = self.store
	local remote = self.remote
	if store == nil or remote == nil then
		return nil
	end
	if not store:isEnabled() then
		return protocol.failure(protocol.ResponseCodes.disabled)
	end
	local action = payload.action
	local isSequencedSelectionAction = action == protocol.Actions.equip or action == protocol.Actions.unequip
	if not isSequencedSelectionAction and self.inFlight[action] then
		return nil
	end
	if not isSequencedSelectionAction then
		self.inFlight[action] = true
	end
	local generation = self.generation
	local hasSettled = false
	local didTimeOut = false
	local didInvokeSucceed: boolean, serverResponse: unknown = false, nil
	local waitingThread = coroutine.running()
	task.spawn(function()
		local invokeSucceeded, invokeResponse = pcall(remote.InvokeServer, remote, payload)
		if hasSettled then
			return
		end
		hasSettled = true
		didInvokeSucceed, serverResponse = invokeSucceeded, invokeResponse
		task.spawn(waitingThread)
	end)
	local timeoutThread = task.delay(protocol.Limits.remoteWaitSeconds, function()
		if hasSettled then
			return
		end
		hasSettled = true
		didTimeOut = true
		task.spawn(waitingThread)
	end)
	coroutine.yield()
	if not didTimeOut then
		task.cancel(timeoutThread)
	end
	if not isSequencedSelectionAction and generation == self.generation then
		self.inFlight[action] = nil
	end
	if not didInvokeSucceed or typeof(serverResponse) ~= "table" or generation ~= self.generation then
		return nil
	end
	return serverResponse :: protocol.InventoryResponse
end

function inventoryRequests:equip(slotNumber: number, intentSequence: number): protocol.InventoryResponse?
	return self:_invoke({
		action = protocol.Actions.equip,
		slotNumber = slotNumber,
		intentSequence = intentSequence,
	})
end

function inventoryRequests:unequip(intentSequence: number): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.unequip, intentSequence = intentSequence })
end

function inventoryRequests:move(itemId: string, zone: protocol.Zone, index: number): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.move, itemId = itemId, toZone = zone, toIndex = index })
end

function inventoryRequests:swap(itemId: string, zone: protocol.Zone, index: number): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.swap, itemId = itemId, toZone = zone, toIndex = index })
end

function inventoryRequests:mergeStack(sourceItemId: string, targetItemId: string): protocol.InventoryResponse?
	return self:_invoke({
		action = protocol.Actions.mergeStack,
		sourceItemId = sourceItemId,
		targetItemId = targetItemId,
	})
end

function inventoryRequests:splitStack(
	itemId: string,
	count: number,
	zone: protocol.Zone,
	index: number
): protocol.InventoryResponse?
	return self:_invoke({
		action = protocol.Actions.splitStack,
		itemId = itemId,
		count = count,
		toZone = zone,
		toIndex = index,
	})
end

function inventoryRequests:drop(itemId: string, direction: Vector3): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.drop, itemId = itemId, dropDirection = direction })
end

function inventoryRequests:upgrade(itemId: string, upgradeId: string): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.upgrade, itemId = itemId, upgradeId = upgradeId })
end

function inventoryRequests:useCapacityUpgrade(itemId: string): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.useCapacityUpgrade, itemId = itemId })
end

function inventoryRequests:throw(itemId: string, direction: Vector3): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.throw, itemId = itemId, aimDirection = direction })
end

function inventoryRequests:releaseThrow(throwId: string): protocol.InventoryResponse?
	return self:_invoke({ action = protocol.Actions.releaseThrow, throwId = throwId })
end

function inventoryRequests.destroy(self: Requests): ()
	self.generation += 1
	table.clear(self.inFlight)
	self.remote = nil
	self.store = nil
end

return inventoryRequests
