--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
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

function hydrator.new(factory: Factory, persistence: PersistenceStore): Hydrator
	return (
		setmetatable({
			factory = factory,
			persistence = persistence,
			_loadZone = hydrator._loadZone,
			_relocateToStorage = hydrator._relocateToStorage,
			_resolveSavedInventory = hydrator._resolveSavedInventory,
			_loadMaterials = hydrator._loadMaterials,
			load = hydrator.load,
		}, hydrator) :: unknown
	) :: Hydrator
end

local function isEmptyTable(candidate: unknown): boolean
	return typeof(candidate) == "table" and next(candidate :: { [unknown]: unknown }) == nil
end

local function findFirstFreeSlot(zoneFolder: Folder, slotCapacity: number): ObjectValue?
	for slotIndex = 1, slotCapacity do
		local slot = zoneFolder:FindFirstChild(tostring(slotIndex))
		if slot and slot:IsA("ObjectValue") and slot.Value == nil then
			return slot
		end
	end
	return nil
end

--// Alias keys such as "01" would silently overwrite the canonical slot, so only codec-written keys are accepted.
local function isCanonicalSlotKey(slotKey: unknown, slotCapacity: number): boolean
	if typeof(slotKey) ~= "string" then
		return false
	end
	local slotIndex = tonumber(slotKey)
	if slotIndex == nil or tostring(slotIndex) ~= slotKey then
		return false
	end
	return slotIndex % 1 == 0 and slotIndex >= 1 and slotIndex <= slotCapacity
end

local function materializeRecord(factory: Factory, itemRecord: protocol.ItemRecord): Model?
	local didMaterialize, materializedItem = pcall(factory.materialize, factory, itemRecord)
	if not didMaterialize then
		warn(string.format("[Inventory] Failed to materialize %s: %s", itemRecord.itemType, tostring(materializedItem)))
		return nil
	end
	return materializedItem :: Model
end

function hydrator:_loadZone(
	player: Player,
	state: State,
	zone: protocol.Zone,
	savedRecords: unknown,
	seenItemIds: { [string]: boolean }
): { protocol.ItemRecord }
	local recordsToRelocate: { protocol.ItemRecord } = {}
	if typeof(savedRecords) ~= "table" then
		return recordsToRelocate
	end

	local zoneFolder = if zone == protocol.Zones.hotbar then state.hotbar else state.storage
	local slotCapacity = if zone == protocol.Zones.hotbar then protocol.Limits.hotbarCapacity else state.storageCapacity
	local factory = self.factory

	for slotKey, savedRecord in savedRecords :: { [string]: unknown } do
		if not isCanonicalSlotKey(slotKey, slotCapacity) then
			warn(string.format("[Inventory] Skipping invalid %s slot %s for %s", zone, tostring(slotKey), player.Name))
			continue
		end

		local itemRecord = codec.validateRecord(savedRecord, factory)
		if itemRecord == nil then
			warn(string.format("[Inventory] Skipping malformed %s record %s for %s", zone, slotKey, player.Name))
			continue
		end

		local itemId = itemRecord.itemId
		if itemId and seenItemIds[itemId] then
			warn(string.format("[Inventory] Skipping duplicate ItemId %s", itemId))
			continue
		end
		if itemId then
			seenItemIds[itemId] = true
		end

		if not itemUtils.canMoveToZone(itemRecord.itemType, zone) then
			table.insert(recordsToRelocate, itemRecord)
			continue
		end

		local materializedItem = materializeRecord(factory, itemRecord)
		if materializedItem == nil then
			continue
		end

		local slot = zoneFolder:FindFirstChild(slotKey)
		if slot == nil or not slot:IsA("ObjectValue") or slot.Value ~= nil then
			factory:destroy(materializedItem)
			continue
		end

		materializedItem.Parent = state.storedTools
		slot.Value = materializedItem
	end

	return recordsToRelocate
end

function hydrator:_relocateToStorage(player: Player, state: State, recordsToRelocate: { protocol.ItemRecord })
	for _, itemRecord in ipairs(recordsToRelocate) do
		local freeSlot = findFirstFreeSlot(state.storage, state.storageCapacity)
		if freeSlot == nil then
			warn(
				string.format(
					"[Inventory] Dropping %s for %s: not allowed in hotbar and storage is full",
					itemRecord.itemType,
					player.Name
				)
			)
			continue
		end

		local materializedItem = materializeRecord(self.factory, itemRecord)
		if materializedItem == nil then
			continue
		end

		materializedItem.Parent = state.storedTools
		freeSlot.Value = materializedItem
		warn(
			string.format(
				"[Inventory] Moved %s from hotbar to storage %s for %s",
				itemRecord.itemType,
				freeSlot.Name,
				player.Name
			)
		)
	end
end

function hydrator:_resolveSavedInventory(player: Player, savedInventory: unknown): { [string]: unknown }
	local savedSchemaVersion = if typeof(savedInventory) == "table"
		then (savedInventory :: { [string]: unknown }).schemaVersion
		else nil
	if savedSchemaVersion == codec.SCHEMA_VERSION then
		return savedInventory :: { [string]: unknown }
	end

	if savedInventory ~= nil and not isEmptyTable(savedInventory) then
		warn(
			string.format(
				"[Inventory] Unsupported Inventory schema %s for %s; starting a fresh schema %d inventory",
				tostring(savedSchemaVersion),
				player.Name,
				codec.SCHEMA_VERSION
			)
		)
	end

	return self.persistence:default() :: { [string]: unknown }
end

function hydrator:_loadMaterials(player: Player, state: State, savedMaterials: unknown)
	table.clear(state.materials)
	if typeof(savedMaterials) ~= "table" then
		return
	end

	for materialType, savedBalance in savedMaterials :: { [string]: unknown } do
		local materialBalance = codec.validateMaterialCount(savedBalance)
		local isKnownMaterial = typeof(materialType) == "string" and materialUtils.isMaterialType(materialType)
		if not isKnownMaterial or materialBalance == nil then
			warn(
				string.format("[Inventory] Skipping malformed material %s for %s", tostring(materialType), player.Name)
			)
			continue
		end
		state.materials[materialType] = materialBalance
	end
end

function hydrator:load(player: Player, state: State): boolean
	local profileData = require(serverScriptService.GameHandler.PlayerData).get(player)
	if profileData == nil then
		return false
	end

	local savedInventory = self:_resolveSavedInventory(player, profileData.Inventory)

	state.storageCapacity = self.persistence:validateCapacity(savedInventory.storageCapacity)
	state.ensureStorageSlots(state.storageCapacity)
	self:_loadMaterials(player, state, savedInventory.materials)

	local seenItemIds: { [string]: boolean } = {}
	self:_loadZone(player, state, protocol.Zones.storage, savedInventory.storage, seenItemIds)
	local recordsToRelocate = self:_loadZone(player, state, protocol.Zones.hotbar, savedInventory.hotbar, seenItemIds)
	self:_relocateToStorage(player, state, recordsToRelocate)

	self.persistence:write(player, state)
	return true
end

return hydrator
