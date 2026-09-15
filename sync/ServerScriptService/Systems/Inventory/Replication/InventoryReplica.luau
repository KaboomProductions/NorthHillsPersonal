--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local Replica = require(replicatedStorage.ExternalLibraries.replica)
local types = require(script.Parent.Parent.Contracts)

local inventoryReplica = {}
inventoryReplica.__index = inventoryReplica

export type Replica = types.Replica
type State = types.State

local function replicaHandle(self: Replica): types.ReplicaHandle
	return assert(self.replica, "Inventory replica is destroyed")
end

local token = Replica.Token("Inventory")

local function descriptorMap(folder: Folder): { [string]: protocol.ItemDescriptor }
	local result: { [string]: protocol.ItemDescriptor } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ObjectValue") and child.Value then
			local descriptor = itemUtils.makeDescriptor(child.Value)
			if descriptor then
				result[child.Name] = descriptor :: protocol.ItemDescriptor
			end
		end
	end
	return result
end

local function numberMap(source: { [string]: number }): { [string]: number }
	return table.clone(source)
end

function inventoryReplica.new(player: Player, state: State): Replica
	local replica = Replica.New({
		Token = token,
		Tags = { UserId = player.UserId },
		Data = {
			enabled = true,
			disabledReason = nil,
			storageCapacity = state.storageCapacity,
			currentSlot = state.currentSlot,
			equipIntentSequence = 0,
			hotbar = descriptorMap(state.hotbar),
			storage = descriptorMap(state.storage),
			materials = numberMap(state.materials),
		},
	}) :: types.ReplicaHandle
	local self = (
		setmetatable({
			player = player,
			replica = replica,
			readyConnection = nil,
			setSlot = inventoryReplica.setSlot,
			setCapacity = inventoryReplica.setCapacity,
			setCurrentSlot = inventoryReplica.setCurrentSlot,
			setEquipIntentSequence = inventoryReplica.setEquipIntentSequence,
			setMaterial = inventoryReplica.setMaterial,
			setEnabled = inventoryReplica.setEnabled,
			destroy = inventoryReplica.destroy,
		}, inventoryReplica) :: unknown
	) :: Replica
	if Replica.ReadyPlayers[player] then
		replicaHandle(self):Subscribe(player)
	else
		self.readyConnection = Replica.NewReadyPlayer:Connect(function(readyPlayer: Player)
			if readyPlayer == player and replicaHandle(self):IsActive() then
				replicaHandle(self):Subscribe(player)
				if self.readyConnection then
					self.readyConnection:Disconnect()
					self.readyConnection = nil
				end
			end
		end)
	end
	return self
end

function inventoryReplica.sync(self: Replica, state: State): ()
	local handle = replicaHandle(self)
	handle:Set({ "hotbar" }, descriptorMap(state.hotbar))
	handle:Set({ "storage" }, descriptorMap(state.storage))
	handle:Set({ "materials" }, numberMap(state.materials))
	handle:Set({ "storageCapacity" }, state.storageCapacity)
	handle:Set({ "currentSlot" }, state.currentSlot)
end

function inventoryReplica.setSlot(
	self: Replica,
	zone: protocol.Zone,
	index: number,
	descriptor: protocol.ItemDescriptor?
): ()
	replicaHandle(self):Set({ zone, tostring(index) }, descriptor)
end

function inventoryReplica.setCapacity(self: Replica, capacity: number): ()
	replicaHandle(self):Set({ "storageCapacity" }, capacity)
end

function inventoryReplica.setCurrentSlot(self: Replica, slotNumber: number?): ()
	replicaHandle(self):Set({ "currentSlot" }, slotNumber)
end

function inventoryReplica.setEquipIntentSequence(self: Replica, intentSequence: number): ()
	replicaHandle(self):Set({ "equipIntentSequence" }, intentSequence)
end

function inventoryReplica.setMaterial(self: Replica, materialType: string, count: number): ()
	replicaHandle(self):Set({ "materials", materialType }, count)
end

function inventoryReplica.setEnabled(self: Replica, enabled: boolean, reason: string?): ()
	replicaHandle(self):Set({ "enabled" }, enabled)
	replicaHandle(self):Set({ "disabledReason" }, reason)
end

function inventoryReplica.destroy(self: Replica): ()
	if self.readyConnection then
		self.readyConnection:Disconnect()
		self.readyConnection = nil
	end
	replicaHandle(self):Destroy()
	self.replica = nil
end

return inventoryReplica
