local dialogueQueueManager = {}
dialogueQueueManager.__index = dialogueQueueManager

export type npcQueue = {
	activePlayer: Player?,
	queuedPlayers: { Player },
}

function dialogueQueueManager:getQueue(npcId: string): npcQueue?
	return self.queuesByNpcId[npcId]
end

function dialogueQueueManager:getOrCreateQueue(npcId: string): npcQueue
	local existingQueue = self:getQueue(npcId)
	if existingQueue ~= nil then
		return existingQueue
	end

	local newQueue: npcQueue = {
		activePlayer = nil,
		queuedPlayers = {},
	}

	self.queuesByNpcId[npcId] = newQueue
	return newQueue
end

function dialogueQueueManager:isPlayerQueued(npcId: string, player: Player): boolean
	local npcQueue = self:getQueue(npcId)
	if npcQueue == nil then
		return false
	end

	for _, queuedPlayer in ipairs(npcQueue.queuedPlayers) do
		if queuedPlayer == player then
			return true
		end
	end

	return false
end

function dialogueQueueManager:enqueuePlayer(npcId: string, player: Player)
	local npcQueue = self:getOrCreateQueue(npcId)
	if self:isPlayerQueued(npcId, player) then
		return
	end

	table.insert(npcQueue.queuedPlayers, player)
end

function dialogueQueueManager:removePlayer(npcId: string, player: Player)
	local npcQueue = self:getQueue(npcId)
	if npcQueue == nil then
		return
	end

	for index, queuedPlayer in ipairs(npcQueue.queuedPlayers) do
		if queuedPlayer == player then
			table.remove(npcQueue.queuedPlayers, index)
			return
		end
	end
end

function dialogueQueueManager:getPosition(npcId: string, player: Player): number?
	local npcQueue = self:getQueue(npcId)
	if npcQueue == nil then
		return nil
	end

	for index, queuedPlayer in ipairs(npcQueue.queuedPlayers) do
		if queuedPlayer == player then
			return index
		end
	end

	return nil
end

function dialogueQueueManager.new()
	local self = setmetatable({}, dialogueQueueManager)
	self.queuesByNpcId = {}
	return self
end

return dialogueQueueManager
