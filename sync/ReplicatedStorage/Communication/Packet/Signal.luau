--!strict

--// Requires
local packetTask = require(script.Parent.Task)

--// Types
export type Signal<A... = ()> = {
	Type: "Signal",
	Previous: Connection<A...>,
	Next: Connection<A...>,
	Fire: (self: Signal<A...>, A...) -> (),
	Connect: (self: Signal<A...>, callback: (A...) -> ()) -> Connection<A...>,
	Once: (self: Signal<A...>, callback: (A...) -> ()) -> Connection<A...>,
	Wait: (self: Signal<A...>) -> A...,
}

export type Connection<A... = ()> = {
	Type: "Connection",
	Previous: Connection<A...>,
	Next: Connection<A...>,
	Once: boolean,
	Function: (player: Player, A...) -> (),
	Thread: thread,
	Disconnect: (self: Connection<A...>) -> (),
}

--// Variables
local signalPrototype = {} :: Signal<...any>
local connectionPrototype = {} :: Connection<...any>

--// Signal
signalPrototype["__index"] = signalPrototype
signalPrototype.Type = "Signal"

function signalPrototype:Connect(callback)
	local newConnection = (setmetatable({}, connectionPrototype) :: any) :: Connection
	newConnection.Previous = self.Previous
	newConnection.Next = self :: any
	newConnection.Once = false
	newConnection.Function = callback
	self.Previous.Next = newConnection
	self.Previous = newConnection
	return newConnection
end

function signalPrototype:Once(callback)
	local newConnection = (setmetatable({}, connectionPrototype) :: any) :: Connection
	newConnection.Previous = self.Previous
	newConnection.Next = self :: any
	newConnection.Once = true
	newConnection.Function = callback
	self.Previous.Next = newConnection
	self.Previous = newConnection
	return newConnection
end

function signalPrototype:Wait()
	local newConnection = (setmetatable({}, connectionPrototype) :: any) :: Connection
	newConnection.Previous = self.Previous
	newConnection.Next = self :: any
	newConnection.Once = true
	newConnection.Thread = coroutine.running()
	self.Previous.Next = newConnection
	self.Previous = newConnection
	return coroutine.yield()
end

function signalPrototype:Fire(...)
	local currentConnection = self.Next
	while currentConnection.Type == "Connection" do
		if currentConnection.Function then
			packetTask:Defer(currentConnection.Function, ...)
		else
			task.defer(currentConnection.Thread, ...)
		end
		if currentConnection.Once then
			currentConnection.Previous.Next = currentConnection.Next
			currentConnection.Next.Previous = currentConnection.Previous
		end
		currentConnection = currentConnection.Next
	end
end

--// Connection
connectionPrototype["__index"] = connectionPrototype
connectionPrototype.Type = "Connection"

function connectionPrototype:Disconnect()
	self.Previous.Next = self.Next
	self.Next.Previous = self.Previous
end

--// Constructor
local function createSignal<A...>()
	local newSignal = (setmetatable({}, signalPrototype) :: any) :: Signal<A...>
	newSignal.Previous = newSignal :: any
	newSignal.Next = newSignal :: any
	return newSignal
end

return createSignal
