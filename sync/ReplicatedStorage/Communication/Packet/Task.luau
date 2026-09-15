--!strict

--// Types
export type PacketTask = {
	Type: "PacketTask",
	Spawn: (self: PacketTask, callback: (...any) -> (), ...any) -> thread,
	Defer: (self: PacketTask, callback: (...any) -> (), ...any) -> thread,
	Delay: (self: PacketTask, durationSeconds: number, callback: (...any) -> (), ...any) -> thread,
}

--// Variables
local packetTask = {} :: PacketTask
local recycledThreads = {} :: { thread }

--// Local Helper Functions
local function executeAndRecycle(callback: (...any) -> (), ...)
	callback(...)
	table.insert(recycledThreads, coroutine.running())
end

local function createReusableThread()
	while true do
		executeAndRecycle(coroutine.yield())
	end
end

--// PacketTask
packetTask.Type = "PacketTask"

function packetTask:Spawn(callback, ...)
	return task.spawn(table.remove(recycledThreads) or task.spawn(createReusableThread), callback, ...)
end

function packetTask:Defer(callback, ...)
	return task.defer(table.remove(recycledThreads) or task.spawn(createReusableThread), callback, ...)
end

function packetTask:Delay(durationSeconds, callback, ...)
	return task.delay(durationSeconds, table.remove(recycledThreads) or task.spawn(createReusableThread), callback, ...)
end

return packetTask
