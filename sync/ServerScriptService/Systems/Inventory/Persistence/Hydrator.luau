--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")
local dataTemplate = require(serverScriptService.GameHandler.DataTemplate)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local codec = require(script.Parent.InventoryCodec)
local types = require(script.Parent.Parent.Contracts)
local playerState = require(script.Parent.Parent.State.PlayerState)
local itemFactory = require(script.Parent.Parent.Items.ItemFactory)
local persistenceStore = require(script.Parent.PersistenceStore)

export type Hydrator = types.Hydrator
type State = playerState.State
type Factory = itemFactory.Factory
type PersistenceStore = persistenceStore.Store

local hydrator = {}
hydrator.__index = hydrator

local function deepCopy(source: any): any
	if typeof(source) ~= "table" then
		return source
	end

	local copy = {}
	for key, value in pairs(source) do
		copy[key] = deepCopy(value)
	end
	return copy
end

function hydrator.new(factory: Factory, persistence: PersistenceStore): Hydrator
	return (
		setmetatable({
			factory = factory,
			persistence = persistence,
			_loadZone = hydrator._loadZone,
			load = hydrator.load,
		}, hydrator) :: unknown
	) :: Hydrator
end

function hydrator:_loadZone(
	player: Player,
	state: State,
	zone: protocol.Zone,
	records: unknown,
	seenIds: { [string]: boolean }
)
	if typeof(records) ~= "table" then
		return
	end
	local folder = if zone == protocol.Zones.hotbar then state.hotbar else state.storage
	local maximum = if zone == protocol.Zones.hotbar then protocol.Limits.hotbarCapacity else state.storageCapacity
	local typedRecords = records :: { [string]: unknown }
	for key, record in typedRecords do
		local index = tonumber(key)
		if typeof(key) ~= "string" or index == nil or index % 1 ~= 0 or index < 1 or index > maximum then
			warn(string.format("[Inventory] Skipping invalid %s slot %s for %s", zone, tostring(key), player.Name))
			continue
		end
		local normalized = codec.validateRecord(record, self.factory)
		local itemType = if typeof(record) == "table" then (record :: { [string]: unknown }).itemType else nil
		if typeof(itemType) == "string" and materialUtils.isMaterialType(itemType) then
			warn(
				string.format("[Inventory] Skipping material %s in %s slot %s for %s", itemType, zone, key, player.Name)
			)
			continue
		end
		if normalized == nil then
			warn(string.format("[Inventory] Skipping malformed %s record %s for %s", zone, key, player.Name))
			continue
		end
		if normalized.itemId and seenIds[normalized.itemId] then
			warn(string.format("[Inventory] Skipping duplicate ItemId %s", normalized.itemId))
			continue
		end

		local ok, item = pcall(self.factory.materialize, self.factory, normalized)
		if not ok then
			warn(string.format("[Inventory] Failed to materialize %s: %s", normalized.itemType, tostring(item)))
			continue
		end
		local itemId = item:GetAttribute("ItemId")
		if typeof(itemId) ~= "string" then
			self.factory:destroy(item)
			continue
		end
		seenIds[itemId] = true
		item.Parent = state.storedTools
		local slot = folder:FindFirstChild(tostring(index))
		if slot and slot:IsA("ObjectValue") then
			slot.Value = item
		else
			self.factory:destroy(item)
		end
	end
end

function hydrator:load(player: Player, state: State): boolean
	local data = require(serverScriptService.GameHandler.PlayerData).get(player)
	if data == nil then
		return false
	end

	local rawInventory = data.Inventory
	local savedVersion = if typeof(rawInventory) == "table"
		then (rawInventory :: { [string]: unknown }).schemaVersion
		else nil
	if savedVersion ~= codec.SCHEMA_VERSION then
		warn(
			string.format(
				"[Inventory] Discarding Inventory schema %s for %s; reseeding schema %d",
				tostring(savedVersion),
				player.Name,
				codec.SCHEMA_VERSION
			)
		)
		data.Inventory = deepCopy(dataTemplate.Inventory)
	end

	local inventory: { [string]: unknown }
	if typeof(data.Inventory) == "table" then
		inventory = data.Inventory :: { [string]: unknown }
	else
		inventory = self.persistence:default() :: { [string]: unknown }
	end
	state.storageCapacity = self.persistence:validateCapacity(inventory.storageCapacity)
	state.ensureStorageSlots(state.storageCapacity)
	table.clear(state.materials)
	local rawMaterials = inventory.materials
	if typeof(rawMaterials) == "table" then
		for materialType, rawCount in rawMaterials :: { [string]: unknown } do
			local count = codec.validateMaterialCount(rawCount)
			if typeof(materialType) == "string" and materialUtils.isMaterialType(materialType) and count ~= nil then
				state.materials[materialType] = count
			else
				warn(
					string.format(
						"[Inventory] Skipping malformed material %s for %s",
						tostring(materialType),
						player.Name
					)
				)
			end
		end
	end
	local seenIds: { [string]: boolean } = {}
	self:_loadZone(player, state, protocol.Zones.hotbar, inventory.hotbar, seenIds)
	self:_loadZone(player, state, protocol.Zones.storage, inventory.storage, seenIds)
	self.persistence:write(player, state)
	return true
end

return hydrator
