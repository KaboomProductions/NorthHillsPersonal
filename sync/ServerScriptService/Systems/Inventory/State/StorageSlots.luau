--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local storageSlots = {}

local function createSlot(parent: Folder, index: number): ObjectValue
	local slot = Instance.new("ObjectValue")
	slot.Name = tostring(index)
	slot.Parent = parent
	return slot
end

function storageSlots.createFolders(parent: Folder): (Folder, Folder, Folder)
	local hotbar = Instance.new("Folder")
	hotbar.Name = "Hotbar"
	hotbar.Parent = parent

	for index = 1, protocol.Limits.hotbarCapacity do
		createSlot(hotbar, index)
	end

	local storage = Instance.new("Folder")
	storage.Name = "Storage"
	storage.Parent = parent

	local storedTools = Instance.new("Folder")
	storedTools.Name = "StoredTools"
	storedTools.Parent = parent

	return hotbar, storage, storedTools
end

function storageSlots.ensure(storage: Folder, capacity: number)
	for index = 1, capacity do
		if storage:FindFirstChild(tostring(index)) == nil then
			createSlot(storage, index)
		end
	end

	for _, child in ipairs(storage:GetChildren()) do
		local index = tonumber(child.Name)
		if child:IsA("ObjectValue") and index and index > capacity then
			child:Destroy()
		end
	end
end

return storageSlots
