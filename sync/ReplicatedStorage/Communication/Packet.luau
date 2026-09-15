--!strict

--// Services
local runService = game:GetService("RunService")
local playersService = game:GetService("Players")

--// Requires
local signal = require(script.Signal)
local packetTask = require(script.Task)
local packetTypes = require(script.Types)

--// Types
export type Packet<A... = (), B... = ()> = {
	Type: "Packet",
	Id: number,
	Name: string,
	ReadFunctions: { () -> any },
	WriteFunctions: { (any) -> () },
	ResponseTimeout: number,
	ResponseTimeoutValue: any,
	ResponseReadFunctions: { () -> any },
	ResponseWriteFunctions: { (any) -> () },
	OnServerEvent: signal.Signal<(Player, A...)>,
	OnClientEvent: signal.Signal<A...>,
	OnServerInvoke: nil | (player: Player, A...) -> B...,
	OnClientInvoke: nil | (A...) -> B...,
	Response: (self: Packet<A..., B...>, B...) -> Packet<A..., B...>,
	Fire: (self: Packet<A..., B...>, A...) -> B...,
	FireClient: (self: Packet<A..., B...>, player: Player, A...) -> B...,
	Serialize: (self: Packet<A..., B...>, A...) -> (buffer, { Instance }?),
	Deserialize: (self: Packet<A..., B...>, serializeBuffer: buffer, instances: { Instance }?) -> A...,
}

--// Variables
local readFunctionsByType = packetTypes.ReadFunctions
local writeFunctionsByType = packetTypes.WriteFunctions
local importCursor = packetTypes.Import
local exportCursor = packetTypes.Export
local truncateBuffer = packetTypes.Truncate
local hasEnded = packetTypes.Ended
local readU8 = readFunctionsByType.NumberU8
local writeU8 = writeFunctionsByType.NumberU8
local readU16 = readFunctionsByType.NumberU16
local writeU16 = writeFunctionsByType.NumberU16

local packet = {} :: Packet<...any, ...any>
local packetsByNameOrId = {} :: { [string | number]: Packet<...any, ...any> }
local cursorsByPlayer: { [Player]: packetTypes.Cursor }
local responseThreadsByPlayer: { [Player]: { [number]: { Yielded: thread, Timeout: thread }, Index: number } }
local responseThreads: { [number]: { Yielded: thread, Timeout: thread }, Index: number }
local remoteEvent: RemoteEvent
local nextPacketId: number

local activeCursor =
	{ Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0 }

--// Local Helper Functions
local buildReadWriteFunctions, buildTableReadWriteFunctions, readAllParameters, writeAllParameters, handleResponseTimeout

function buildReadWriteFunctions(parameters: { any })
	local parameterReadFunctions = table.create(#parameters)
	local parameterWriteFunctions = table.create(#parameters)

	for parameterIndex, parameterType in ipairs(parameters) do
		if type(parameterType) == "table" then
			parameterReadFunctions[parameterIndex], parameterWriteFunctions[parameterIndex] =
				buildTableReadWriteFunctions(parameterType)
		else
			parameterReadFunctions[parameterIndex] = readFunctionsByType[parameterType]
			parameterWriteFunctions[parameterIndex] = writeFunctionsByType[parameterType]
		end
	end

	return parameterReadFunctions, parameterWriteFunctions
end

function buildTableReadWriteFunctions(parameters: { any })
	if #parameters == 1 then
		local parameterType = parameters[1]
		local readFunction, writeFunction

		if type(parameterType) == "table" then
			readFunction, writeFunction = buildTableReadWriteFunctions(parameterType)
		else
			readFunction, writeFunction = readFunctionsByType[parameterType], writeFunctionsByType[parameterType]
		end

		local readArray = function()
			local arrayLength = readU16()
			local values = table.create(arrayLength)

			for valueIndex = 1, arrayLength do
				values[valueIndex] = readFunction()
			end

			return values
		end

		local writeArray = function(values: { any })
			writeU16(#values)

			for _, arrayValue in values do
				writeFunction(arrayValue)
			end
		end

		return readArray, writeArray
	else
		local sortedKeys = {}

		for key, _ in parameters do
			table.insert(sortedKeys, key)
		end

		table.sort(sortedKeys)

		local keyReadFunctions = table.create(#sortedKeys)
		local keyWriteFunctions = table.create(#sortedKeys)

		for keyIndex, key in sortedKeys do
			local parameterType = parameters[key]

			if type(parameterType) == "table" then
				keyReadFunctions[keyIndex], keyWriteFunctions[keyIndex] = buildTableReadWriteFunctions(parameterType)
			else
				keyReadFunctions[keyIndex] = readFunctionsByType[parameterType]
				keyWriteFunctions[keyIndex] = writeFunctionsByType[parameterType]
			end
		end

		local readDictionary = function()
			local values = {}

			for keyIndex, keyReadFunction in keyReadFunctions do
				values[sortedKeys[keyIndex]] = keyReadFunction()
			end

			return values
		end

		local writeDictionary = function(values: { [any]: any })
			for keyIndex, keyWriteFunction in keyWriteFunctions do
				keyWriteFunction(values[sortedKeys[keyIndex]])
			end
		end

		return readDictionary, writeDictionary
	end
end

function readAllParameters(parameterReadFunctions: { () -> any })
	local values = table.create(#parameterReadFunctions)

	for parameterIndex, readFunction in parameterReadFunctions do
		values[parameterIndex] = readFunction()
	end

	return table.unpack(values)
end

function writeAllParameters(parameterWriteFunctions: { (any) -> () }, values: { any })
	for parameterIndex, writeFunction in parameterWriteFunctions do
		writeFunction(values[parameterIndex])
	end
end

function handleResponseTimeout(
	targetThreads: { [number]: { Yielded: thread, Timeout: thread }, Index: number },
	threadIndex: number,
	timeoutValue: any
)
	local responseThread = targetThreads[threadIndex]
	task.defer(responseThread.Yielded, timeoutValue)
	targetThreads[threadIndex] = nil
end

--// Packet
packet["__index"] = packet
packet.Type = "Packet"

function packet:Response(...)
	self.ResponseTimeout = self.ResponseTimeout or 10
	self.ResponseReadFunctions, self.ResponseWriteFunctions = buildReadWriteFunctions(table.pack(...))
	return self
end

function packet:Fire(...)
	if self.ResponseReadFunctions then
		if runService:IsServer() then
			error("You must use FireClient(player)", 2)
		end

		local existingThread
		for _ = 1, 128 do
			existingThread = responseThreads[responseThreads.Index]
			if existingThread then
				responseThreads.Index = (responseThreads.Index + 1) % 128
			else
				break
			end
		end

		if existingThread then
			error("Cannot have more than 128 yielded threads", 2)
		end

		importCursor(activeCursor)
		writeU8(self.Id)
		writeU8(responseThreads.Index)

		responseThreads[responseThreads.Index] = {
			Yielded = coroutine.running(),
			Timeout = packetTask:Delay(
				self.ResponseTimeout,
				handleResponseTimeout,
				responseThreads,
				responseThreads.Index,
				self.ResponseTimeoutValue
			),
		}

		responseThreads.Index = (responseThreads.Index + 1) % 128
		writeAllParameters(self.WriteFunctions, { ... })
		activeCursor = exportCursor()
		return coroutine.yield()
	else
		importCursor(activeCursor)
		writeU8(self.Id)
		writeAllParameters(self.WriteFunctions, { ... })
		activeCursor = exportCursor()
	end
end

function packet:FireClient(targetPlayer, ...)
	if targetPlayer.Parent == nil then
		return
	end

	if self.ResponseReadFunctions then
		local playerThreads = responseThreadsByPlayer[targetPlayer]
		if playerThreads == nil then
			playerThreads = { Index = 0 }
			responseThreadsByPlayer[targetPlayer] = playerThreads
		end

		local existingThread
		for _ = 1, 128 do
			existingThread = playerThreads[playerThreads.Index]
			if existingThread then
				playerThreads.Index = (playerThreads.Index + 1) % 128
			else
				break
			end
		end

		if existingThread then
			error("Cannot have more than 128 yielded threads", 2)
			return
		end

		importCursor(cursorsByPlayer[targetPlayer] or {
			Buffer = buffer.create(128),
			BufferLength = 128,
			BufferOffset = 0,
			Instances = {},
			InstancesOffset = 0,
		})
		writeU8(self.Id)
		writeU8(playerThreads.Index)

		playerThreads[playerThreads.Index] = {
			Yielded = coroutine.running(),
			Timeout = packetTask:Delay(
				self.ResponseTimeout,
				handleResponseTimeout,
				playerThreads,
				playerThreads.Index,
				self.ResponseTimeoutValue
			),
		}

		playerThreads.Index = (playerThreads.Index + 1) % 128
		writeAllParameters(self.WriteFunctions, { ... })
		cursorsByPlayer[targetPlayer] = exportCursor()
		return coroutine.yield()
	else
		importCursor(cursorsByPlayer[targetPlayer] or {
			Buffer = buffer.create(128),
			BufferLength = 128,
			BufferOffset = 0,
			Instances = {},
			InstancesOffset = 0,
		})
		writeU8(self.Id)
		writeAllParameters(self.WriteFunctions, { ... })
		cursorsByPlayer[targetPlayer] = exportCursor()
	end
end

function packet:Serialize(...)
	importCursor({
		Buffer = buffer.create(128),
		BufferLength = 128,
		BufferOffset = 0,
		Instances = {},
		InstancesOffset = 0,
	})
	writeAllParameters(self.WriteFunctions, { ... })
	return truncateBuffer()
end

function packet:Deserialize(serializeBuffer, deserializeInstances)
	importCursor({
		Buffer = serializeBuffer,
		BufferLength = buffer.len(serializeBuffer),
		BufferOffset = 0,
		Instances = deserializeInstances or {},
		InstancesOffset = 0,
	})
	return readAllParameters(self.ReadFunctions)
end

--// Constructor
local function createPacket<A..., B...>(_, name: string, ...: A...)
	local existingPacket = packetsByNameOrId[name] :: Packet<A..., B...>
	if existingPacket then
		return existingPacket
	end

	local newPacket = (setmetatable({}, packet) :: any) :: Packet<A..., B...>
	newPacket.Name = name

	if runService:IsServer() then
		newPacket.Id = nextPacketId
		newPacket.OnServerEvent = signal() :: signal.Signal<(Player, A...)>
		remoteEvent:SetAttribute(name, nextPacketId)
		packetsByNameOrId[nextPacketId] = newPacket
		nextPacketId += 1
	else
		newPacket.Id = remoteEvent:GetAttribute(name) :: number
		newPacket.OnClientEvent = signal() :: signal.Signal<A...>

		if newPacket.Id then
			packetsByNameOrId[newPacket.Id] = newPacket
		end
	end

	newPacket.ReadFunctions, newPacket.WriteFunctions = buildReadWriteFunctions(table.pack(...))
	packetsByNameOrId[newPacket.Name] = newPacket
	return newPacket
end

--// Initialize
if runService:IsServer() then
	cursorsByPlayer = {}
	responseThreadsByPlayer = {}
	nextPacketId = 0
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Parent = script

	local bytesByPlayer = {}

	local flushThread = task.spawn(function()
		while true do
			coroutine.yield()

			if activeCursor.BufferOffset > 0 then
				local truncatedBuffer = buffer.create(activeCursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, activeCursor.Buffer, 0, activeCursor.BufferOffset)

				if activeCursor.InstancesOffset == 0 then
					remoteEvent:FireAllClients(truncatedBuffer)
				else
					remoteEvent:FireAllClients(truncatedBuffer, activeCursor.Instances)
					activeCursor.InstancesOffset = 0
					table.clear(activeCursor.Instances)
				end

				activeCursor.BufferOffset = 0
			end

			for targetPlayer, playerCursor in cursorsByPlayer do
				local truncatedBuffer = buffer.create(playerCursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, playerCursor.Buffer, 0, playerCursor.BufferOffset)

				if playerCursor.InstancesOffset == 0 then
					remoteEvent:FireClient(targetPlayer, truncatedBuffer)
				else
					remoteEvent:FireClient(targetPlayer, truncatedBuffer, playerCursor.Instances)
				end
			end

			table.clear(cursorsByPlayer)
			table.clear(bytesByPlayer)
		end
	end)

	local function respondToClient(targetPacket: Packet, targetPlayer: Player, threadIndex: number, ...)
		if targetPacket.OnServerInvoke == nil then
			if runService:IsStudio() then
				warn("OnServerInvoke not found for packet:", targetPacket.Name, "discarding event:", ...)
			end
			return
		end

		local responseValues = { targetPacket.OnServerInvoke(targetPlayer, ...) }

		if targetPlayer.Parent == nil then
			return
		end

		importCursor(cursorsByPlayer[targetPlayer] or {
			Buffer = buffer.create(128),
			BufferLength = 128,
			BufferOffset = 0,
			Instances = {},
			InstancesOffset = 0,
		})
		writeU8(targetPacket.Id)
		writeU8(threadIndex + 128)
		writeAllParameters(targetPacket.ResponseWriteFunctions, responseValues)
		cursorsByPlayer[targetPlayer] = exportCursor()
	end

	local function onServerEventReceived(senderPlayer: Player, receivedBuffer: buffer, receivedInstances: { Instance }?)
		local accumulatedBytes = (bytesByPlayer[senderPlayer] or 0) + math.max(buffer.len(receivedBuffer), 800)

		if accumulatedBytes > 8_000 then
			if runService:IsStudio() then
				warn(senderPlayer.Name, "is exceeding the data/rate limit; some events may be dropped")
			end
			return
		end

		bytesByPlayer[senderPlayer] = accumulatedBytes

		importCursor({
			Buffer = receivedBuffer,
			BufferLength = buffer.len(receivedBuffer),
			BufferOffset = 0,
			Instances = receivedInstances or {},
			InstancesOffset = 0,
		})

		while hasEnded() == false do
			local receivedPacket = packetsByNameOrId[readU8()]

			if receivedPacket.ResponseReadFunctions then
				local threadIndex = readU8()

				if threadIndex < 128 then
					packetTask:Defer(
						respondToClient,
						receivedPacket,
						senderPlayer,
						threadIndex,
						readAllParameters(receivedPacket.ReadFunctions)
					)
				else
					threadIndex -= 128
					local playerThreads = responseThreadsByPlayer[senderPlayer]
					local pendingThread = playerThreads[threadIndex]

					if pendingThread then
						task.cancel(pendingThread.Timeout)
						task.defer(pendingThread.Yielded, readAllParameters(receivedPacket.ResponseReadFunctions))
						playerThreads[threadIndex] = nil
					elseif runService:IsStudio() then
						warn(
							"Response thread not found for packet:",
							receivedPacket.Name,
							"discarding response:",
							readAllParameters(receivedPacket.ResponseReadFunctions)
						)
					else
						readAllParameters(receivedPacket.ResponseReadFunctions)
					end
				end
			else
				receivedPacket.OnServerEvent:Fire(senderPlayer, readAllParameters(receivedPacket.ReadFunctions))
			end
		end
	end

	remoteEvent.OnServerEvent:Connect(function(senderPlayer: Player, ...)
		local _success, errorMessage: string? = pcall(onServerEventReceived, senderPlayer, ...)
		if errorMessage and runService:IsStudio() then
			warn(senderPlayer.Name, errorMessage)
		end
	end)

	playersService.PlayerRemoving:Connect(function(removedPlayer)
		cursorsByPlayer[removedPlayer] = nil
		responseThreadsByPlayer[removedPlayer] = nil
		bytesByPlayer[removedPlayer] = nil
	end)

	runService.Heartbeat:Connect(function(_deltaTime)
		task.defer(flushThread)
	end)
else
	responseThreads = { Index = 0 }
	remoteEvent = script:WaitForChild("RemoteEvent")
	local accumulatedTime = 0

	local flushThread = task.spawn(function()
		while true do
			coroutine.yield()

			if activeCursor.BufferOffset > 0 then
				local truncatedBuffer = buffer.create(activeCursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, activeCursor.Buffer, 0, activeCursor.BufferOffset)

				if activeCursor.InstancesOffset == 0 then
					remoteEvent:FireServer(truncatedBuffer)
				else
					remoteEvent:FireServer(truncatedBuffer, activeCursor.Instances)
					activeCursor.InstancesOffset = 0
					table.clear(activeCursor.Instances)
				end

				activeCursor.BufferOffset = 0
			end
		end
	end)

	local function respondToServer(targetPacket: Packet, threadIndex: number, ...)
		if targetPacket.OnClientInvoke == nil then
			warn("OnClientInvoke not found for packet:", targetPacket.Name, "discarding event:", ...)
			return
		end

		local responseValues = { targetPacket.OnClientInvoke(...) }
		importCursor(activeCursor)
		writeU8(targetPacket.Id)
		writeU8(threadIndex + 128)
		writeAllParameters(targetPacket.ResponseWriteFunctions, responseValues)
		activeCursor = exportCursor()
	end

	remoteEvent.OnClientEvent:Connect(function(receivedBuffer: buffer, receivedInstances: { Instance }?)
		importCursor({
			Buffer = receivedBuffer,
			BufferLength = buffer.len(receivedBuffer),
			BufferOffset = 0,
			Instances = receivedInstances or {},
			InstancesOffset = 0,
		})

		while hasEnded() == false do
			local receivedPacket = packetsByNameOrId[readU8()]

			if receivedPacket.ResponseReadFunctions then
				local threadIndex = readU8()

				if threadIndex < 128 then
					packetTask:Defer(
						respondToServer,
						receivedPacket,
						threadIndex,
						readAllParameters(receivedPacket.ReadFunctions)
					)
				else
					threadIndex -= 128
					local pendingThread = responseThreads[threadIndex]

					if pendingThread then
						task.cancel(pendingThread.Timeout)
						task.defer(pendingThread.Yielded, readAllParameters(receivedPacket.ResponseReadFunctions))
						responseThreads[threadIndex] = nil
					else
						warn(
							"Response thread not found for packet:",
							receivedPacket.Name,
							"discarding response:",
							readAllParameters(receivedPacket.ResponseReadFunctions)
						)
					end
				end
			else
				receivedPacket.OnClientEvent:Fire(readAllParameters(receivedPacket.ReadFunctions))
			end
		end
	end)

	remoteEvent.AttributeChanged:Connect(function(attributeName)
		local existingPacket = packetsByNameOrId[attributeName]

		if existingPacket then
			if existingPacket.Id then
				packetsByNameOrId[existingPacket.Id] = nil
			end

			existingPacket.Id = remoteEvent:GetAttribute(attributeName) :: number

			if existingPacket.Id then
				packetsByNameOrId[existingPacket.Id] = existingPacket
			end
		end
	end)

	runService.Heartbeat:Connect(function(deltaTime)
		accumulatedTime += deltaTime
		if accumulatedTime > 0.016666666666666666 then
			accumulatedTime %= 0.016666666666666666
			task.defer(flushThread)
		end
	end)
end

return setmetatable(packetTypes.Types, { __call = createPacket })
