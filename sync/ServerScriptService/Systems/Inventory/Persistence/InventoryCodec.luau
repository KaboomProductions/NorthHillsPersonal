--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)
local playerState = require(script.Parent.Parent.State.PlayerState)
local itemFactory = require(script.Parent.Parent.Items.ItemFactory)

export type SerializedInventory = types.SerializedInventory
type State = playerState.State
type Factory = itemFactory.Factory

local inventoryCodec = {}
local SCHEMA_VERSION = 2
inventoryCodec.SCHEMA_VERSION = SCHEMA_VERSION

local function serializeZone(folder: Folder): { [string]: protocol.ItemDescriptor }
	local records: { [string]: protocol.ItemDescriptor } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if not child:IsA("ObjectValue") or child.Value == nil then
			continue
		end
		local descriptor = itemUtils.makeDescriptor(child.Value)
		if descriptor then
			records[child.Name] = descriptor :: protocol.ItemDescriptor
		end
	end
	return records
end

local function serializeMaterials(materials: { [string]: number }): { [string]: number }
	return table.clone(materials)
end

function inventoryCodec.serialize(state: State): SerializedInventory
	return {
		schemaVersion = SCHEMA_VERSION,
		hotbar = serializeZone(state.hotbar),
		storage = serializeZone(state.storage),
		storageCapacity = state.storageCapacity,
		materials = serializeMaterials(state.materials),
	}
end

function inventoryCodec.default(): SerializedInventory
	return {
		schemaVersion = SCHEMA_VERSION,
		hotbar = {},
		storage = {},
		storageCapacity = protocol.Limits.storageCapacityDefault,
		materials = {},
	}
end

function inventoryCodec.validateCapacity(value: unknown): number
	if not protocol.isFiniteNumber(value) or (value :: number) % 1 ~= 0 then
		return protocol.Limits.storageCapacityDefault
	end
	return math.clamp(value :: number, protocol.Limits.storageCapacityDefault, protocol.Limits.storageCapacityMaximum)
end

function inventoryCodec.validateMaterialCount(value: unknown): number?
	if not protocol.isFiniteNumber(value) or (value :: number) % 1 ~= 0 or (value :: number) < 0 then
		return nil
	end
	return value :: number
end

function inventoryCodec.validateRecord(record: unknown, factory: Factory): protocol.ItemRecord?
	if typeof(record) ~= "table" then
		return nil
	end
	local typedRecord = record :: { [string]: unknown }
	if typeof(typedRecord.itemType) ~= "string" then
		return nil
	end
	local itemType = typedRecord.itemType
	if materialUtils.isMaterialType(itemType) then
		return nil
	end
	local config = factory.templates:getConfig(itemType)
	local template = factory.templates:getTemplate(itemType)
	local countValue = typedRecord.stackCount
	local count = if countValue == nil then 1 else countValue
	if
		config == nil
		or template == nil
		or typeof(count) ~= "number"
		or count % 1 ~= 0
		or count < 1
		or count > itemUtils.getMaxStack(config)
	then
		return nil
	end
	local itemIdValue = rawget(typedRecord, "itemId")
	local itemId: string? = nil
	if itemIdValue ~= nil then
		if
			typeof(itemIdValue) ~= "string"
			or itemIdValue == ""
			or #(itemIdValue :: string) > protocol.Limits.maximumIdentifierLength
		then
			return nil
		end
		itemId = itemIdValue
	end
	return {
		itemId = itemId,
		itemType = itemType,
		stackCount = count,
		attributes = itemUtils.sanitizePersistentAttributes(config, typedRecord.attributes) :: types.PersistentAttributes,
	}
end

return inventoryCodec
