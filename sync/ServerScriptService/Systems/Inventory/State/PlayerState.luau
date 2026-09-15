--!strict

local serverStorage = game:GetService("ServerStorage")

local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)

local storageSlots = require(script.Parent.StorageSlots)
local transactionQueue = require(script.Parent.TransactionQueue)
local types = require(script.Parent.Parent.Contracts)

export type State = types.State

local playerState = {}

local function ensureRoot(): Folder
	local root = serverStorage:FindFirstChild("InventoryPlayers")
	if root and root:IsA("Folder") then
		return root
	end

	local created = Instance.new("Folder")
	created.Name = "InventoryPlayers"
	created.Parent = serverStorage
	return created
end

function playerState.new(player: Player): State
	local rootParent = ensureRoot()
	local old = rootParent:FindFirstChild(tostring(player.UserId))
	if old then
		old:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = tostring(player.UserId)
	root.Parent = rootParent
	local hotbar, storage, storedTools = storageSlots.createFolders(root)
	local ensureStorageSlots = function(capacity: number)
		storageSlots.ensure(storage, capacity)
	end

	local state: State = {
		player = player,
		root = root,
		hotbar = hotbar,
		storage = storage,
		storedTools = storedTools,
		storageCapacity = protocol.Limits.storageCapacityDefault,
		materials = {},
		index = {},
		queue = transactionQueue.new(),
		connections = {},
		currentSlot = nil,
		removing = false,
		enabled = true,
		disabledReason = nil,
		replica = nil,
		equipTransition = nil,
		ensureStorageSlots = ensureStorageSlots,
	}

	state.ensureStorageSlots(state.storageCapacity)
	return state
end

function playerState.getSlot(state: State, zone: protocol.Zone, index: number): ObjectValue?
	if zone ~= protocol.Zones.hotbar and zone ~= protocol.Zones.storage then
		return nil
	end
	if not protocol.isFiniteNumber(index) then
		return nil
	end
	local maximum = if zone == protocol.Zones.hotbar then protocol.Limits.hotbarCapacity else state.storageCapacity
	if index % 1 ~= 0 or index < 1 or index > maximum then
		return nil
	end

	local folder = if zone == protocol.Zones.hotbar then state.hotbar else state.storage
	local slot = folder:FindFirstChild(tostring(index))
	return if slot and slot:IsA("ObjectValue") then slot else nil
end

function playerState.destroy(state: State)
	state.removing = true
	state.queue:destroy()
	for _, connection in state.connections do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(state.connections)
	if state.root.Parent then
		state.root:Destroy()
	end
end

return playerState
