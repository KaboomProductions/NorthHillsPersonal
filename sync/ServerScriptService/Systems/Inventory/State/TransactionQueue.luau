--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)

export type Queue = types.TransactionQueue
type Entry = types.TransactionEntry

local transactionQueue = {}
transactionQueue.__index = transactionQueue

function transactionQueue.new(): Queue
	return (
		setmetatable({
			queue = {} :: { Entry },
			running = false,
			inCriticalSection = false,
			removing = false,
			_drain = transactionQueue._drain,
			withLock = transactionQueue.withLock,
			destroy = transactionQueue.destroy,
		}, transactionQueue) :: unknown
	) :: Queue
end

function transactionQueue._drain(self: Queue, player: Player?): ()
	while #self.queue > 0 and not self.removing do
		local entry: Entry = assert(table.remove(self.queue, 1), "Inventory transaction queue entry is missing")
		self.inCriticalSection = true
		local packed = table.pack(xpcall(entry.callback, debug.traceback))
		self.inCriticalSection = false

		if packed[1] then
			entry.result = table.pack(table.unpack(packed, 2, packed.n)) :: types.TransactionResult
		else
			warn(
				string.format(
					"[Inventory] Transaction failed for %s: %s",
					if player then player.Name else "unknown",
					tostring(packed[2])
				)
			)
			entry.result = table.pack(protocol.failure(protocol.ResponseCodes.internalError)) :: types.TransactionResult
		end
		entry.done:Fire()
	end

	self.running = false
	if self.removing then
		for _, entry in ipairs(self.queue) do
			entry.result = table.pack(protocol.failure(protocol.ResponseCodes.notReady))
			entry.done:Fire()
		end
		table.clear(self.queue)
	end
end

function transactionQueue.withLock(self: Queue, player: Player, callback: types.TransactionCallback): ...unknown
	if self.removing then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	assert(not self.inCriticalSection, "Inventory lock is not reentrant")
	if #self.queue >= protocol.Limits.maximumQueueDepth then
		return protocol.failure(protocol.ResponseCodes.queueFull)
	end

	local entry: Entry = {
		callback = callback,
		done = Instance.new("BindableEvent"),
		result = nil,
	}
	table.insert(self.queue, entry)
	if not self.running then
		self.running = true
		task.defer(self._drain, self, player)
	end

	entry.done.Event:Wait()
	entry.done:Destroy()
	local result = assert(entry.result, "Inventory transaction result is missing")
	return table.unpack(result, 1, result.n)
end

function transactionQueue.destroy(self: Queue): ()
	self.removing = true
	if not self.running then
		self:_drain(nil)
	end
end

return transactionQueue
