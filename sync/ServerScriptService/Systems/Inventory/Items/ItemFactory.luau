--!strict

local collectionService = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local itemIds = require(script.Parent.ItemIds)
local mutation = require(script.Parent.Parent.State.Mutation)
local types = require(script.Parent.Parent.Contracts)
local templateService = require(script.Parent.Templates)

export type Factory = types.ItemFactory
type CreateRecord = types.CreateRecord
type TemplateService = templateService.TemplateService

local itemFactory = {}
itemFactory.__index = itemFactory

local transientAttributes = {
	"Charging",
	"ChargeStrength",
	"Cooldown",
	"Equipped",
	"PendingTransaction",
	"SpecialEquip",
	"Toggled",
}

local function isFiniteNumber(value: unknown): boolean
	if typeof(value) ~= "number" then
		return false
	end
	local numberValue = value :: number
	return numberValue == numberValue and numberValue > -math.huge and numberValue < math.huge
end

local function isPrimitive(value: unknown): boolean
	local valueType = typeof(value)
	return valueType == "boolean" or valueType == "string" or isFiniteNumber(value)
end

local function validateRecord(record: unknown, templates: TemplateService): (boolean, string?)
	if typeof(record) ~= "table" then
		return false, "Invalid inventory record"
	end

	local typedRecord = record :: { [string]: unknown }
	local itemTypeValue = rawget(typedRecord, "itemType")
	if typeof(itemTypeValue) ~= "string" or itemTypeValue == "" then
		return false, "Inventory record itemType is invalid"
	end
	local itemType = itemTypeValue :: string
	if materialUtils.isMaterialType(itemType) then
		return false, "Materials cannot be stored as inventory items"
	end

	local valid, reason = templates:validate(itemType)
	if not valid then
		return false, reason or "Inventory item is invalid"
	end
	local config = templates:getConfig(itemType)
	if config == nil then
		return false, "Inventory item config is missing"
	end

	local stackCountValue = rawget(typedRecord, "stackCount")
	if not isFiniteNumber(stackCountValue) then
		return false, "Inventory record stackCount is invalid"
	end
	local stackCount = stackCountValue :: number
	if stackCount % 1 ~= 0 or stackCount < 1 or stackCount > itemUtils.getMaxStack(config) then
		return false, "Inventory record stackCount is out of bounds"
	end

	local itemId = rawget(typedRecord, "itemId")
	if
		itemId ~= nil
		and (
			typeof(itemId) ~= "string"
			or itemId == ""
			or #(itemId :: string) > protocol.Limits.maximumIdentifierLength
		)
	then
		return false, "Inventory record itemId is invalid"
	end

	local attributes = rawget(typedRecord, "attributes")
	if typeof(attributes) ~= "table" then
		return false, "Inventory record attributes are invalid"
	end
	local persistentAttributes = config.persistentAttributes or {}
	local typedAttributes = attributes :: { [string]: unknown }
	for attributeName, value in typedAttributes do
		if typeof(attributeName) ~= "string" or not isPrimitive(value) then
			return false, "Inventory record attributes must contain primitive values"
		end
		local defaultValue = persistentAttributes[attributeName]
		if defaultValue ~= nil and typeof(value) ~= typeof(defaultValue) then
			return false, "Inventory record persistent attribute type is invalid"
		end
	end

	return true, nil
end

local function setPartsAnchored(item: Instance, anchored: boolean)
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
end

function itemFactory.new(templateServiceInstance: TemplateService): Factory
	return (
		setmetatable({
			templates = templateServiceInstance,
			resetTransients = itemFactory.resetTransients,
			create = itemFactory.create,
			materialize = itemFactory.materialize,
			adoptWorldItem = itemFactory.adoptWorldItem,
			replaceClone = itemFactory.replaceClone,
			repair = itemFactory.repair,
			destroy = itemFactory.destroy,
		}, itemFactory) :: unknown
	) :: Factory
end

function itemFactory:resetTransients(item: Instance): ()
	for _, attributeName in ipairs(transientAttributes) do
		item:SetAttribute(attributeName, nil)
	end
	collectionService:RemoveTag(item, "EquippedItem")
end

function itemFactory.isValidRecord(record: unknown, templates: TemplateService): boolean
	local valid = validateRecord(record, templates)
	return valid
end

function itemFactory:create(itemType: string, record: CreateRecord?): Model
	local input: CreateRecord = record or {}
	assert(not materialUtils.isMaterialType(itemType), "Materials cannot be created as inventory items")
	local valid, reason = self.templates:validate(itemType)
	assert(valid, reason)
	local config = self.templates:getConfig(itemType)
	assert(config, string.format("ItemConfig %s is missing", itemType))
	local template = self.templates:getTemplate(itemType)
	assert(template, string.format("Item template %s is missing", itemType))
	local count = input.stackCount or 1
	assert(isFiniteNumber(count) and count % 1 == 0, "StackCount must be a finite integer")
	assert(count >= 1 and count <= itemUtils.getMaxStack(config), "StackCount is out of bounds")
	local clone = template:Clone()
	if not clone:IsA("Model") then
		clone:Destroy()
		error(string.format("Item template %s did not clone to a Model", itemType))
	end
	local item: Model = (clone :: unknown) :: Model
	mutation.created(item)
	local initialized, problem = pcall(function()
	item.Name = itemType
	item:SetAttribute("ItemId", itemIds.claim(input.itemId, itemUtils.generateItemId))
	item:SetAttribute("ItemType", itemType)
	item:SetAttribute("Class", itemUtils.getControllerClass(itemType))

	item:SetAttribute("StackCount", count)
	itemUtils.applyPersistentAttributes(item, config, input.attributes)
	self:resetTransients(item)
	setPartsAnchored(item, true)
	end)
	if not initialized then
		-- Claim may have failed before this clone received an ID.
		self:destroy(item)
		error(tostring(problem), 0)
	end
	return item
end

function itemFactory:materialize(record: protocol.ItemRecord): Model
	local valid, reason = validateRecord(record, self.templates)
	assert(valid, reason or "Invalid inventory record")
	return self:create(record.itemType, record)
end

function itemFactory:adoptWorldItem(item: Model): (Model?, string?)
	local itemType = itemUtils.resolveItemType(item)
	if materialUtils.isMaterialType(itemType) then
		local valid, reason = self.templates:validateMaterial(itemType)
		if not valid then
			return nil, reason
		end
		local count = item:GetAttribute("StackCount")
		if not protocol.isFiniteNumber(count) or (count :: number) % 1 ~= 0 or (count :: number) < 1 then
			return nil, "Material pickup StackCount is invalid"
		end
		local oldItemId = item:GetAttribute("ItemId")
		if typeof(oldItemId) == "string" then
			itemIds.release(oldItemId)
		end
		item:SetAttribute("ItemId", nil)
		item:SetAttribute("ItemType", itemType)
		item:SetAttribute("StackCount", count)
		item:SetAttribute("Class", "ItemPickup")
		self:resetTransients(item)
		setPartsAnchored(item, true)
		return item
	end
	local valid, reason = self.templates:validate(itemType)
	if not valid then
		return nil, reason
	end
	local config = assert(self.templates:getConfig(itemType))
	local count = item:GetAttribute("StackCount") or 1
	if typeof(count) ~= "number" or count % 1 ~= 0 or count < 1 or count > itemUtils.getMaxStack(config) then
		return nil, "World item StackCount is invalid"
	end
	local requestedIdValue = item:GetAttribute("ItemId")
	local requestedId: string? = if typeof(requestedIdValue) == "string" then requestedIdValue else nil
	local ok, claimedId = pcall(itemIds.claim, requestedId, itemUtils.generateItemId)
	if not ok or typeof(claimedId) ~= "string" then
		return nil, tostring(claimedId)
	end
	item:SetAttribute("ItemId", claimedId)
	item:SetAttribute("ItemType", itemType)
	item:SetAttribute("StackCount", count)
	item:SetAttribute("Class", "ItemPickup")
	itemUtils.applyPersistentAttributes(item, config, item:GetAttributes())
	self:resetTransients(item)
	setPartsAnchored(item, true)
	end)
	if not initialized then
		-- Claim may have failed before this clone received an ID.
		self:destroy(item)
		error(tostring(problem), 0)
	end
	return item
end

local function replaceModel(self: Factory, item: Model, resultItemType: string, count: number): Model
	local itemId = item:GetAttribute("ItemId")
	assert(typeof(itemId) == "string" and itemId ~= "", "Replacement target has no ItemId")
	local config = assert(self.templates:getConfig(resultItemType))
	-- Build with a temporary identity; the original remains valid if cloning fails.
	local replacement = self:create(resultItemType, {
		stackCount = count,
		attributes = itemUtils.getPersistentAttributes(item, config) :: types.PersistentAttributes,
	})
	local placed, problem = pcall(function()
		replacement:PivotTo(item:GetPivot())
		replacement.Parent = item.Parent
	end)
	if not placed then
		self:destroy(replacement)
		error(tostring(problem), 0)
	end
	mutation.watch(item)
	itemIds.release(replacement)
	item:SetAttribute("ItemId", nil)
	replacement:SetAttribute("ItemId", itemId)
	self:destroy(item)
	return replacement
end

function itemFactory:replaceClone(item: Model, resultItemType: string): Model
	return replaceModel(self, item, resultItemType, 1)
end

function itemFactory:repair(item: Model): Model?
	if materialUtils.isMaterialType(itemUtils.resolveItemType(item)) then
		return nil
	end
	if self.templates:isComplete(item) then
		return item
	end
	local itemType = itemUtils.resolveItemType(item)
	local config = self.templates:getConfig(itemType)
	if config == nil or self.templates:getTemplate(itemType) == nil then
		return nil
	end
	local ok, replacement = pcall(replaceModel, self, item, itemType, itemUtils.getStackCount(item, config))
	if not ok then
		warn("[Inventory] Repair failed:", replacement)
		return nil
	end
	return replacement
end

function itemFactory:destroy(item: Instance)
	if mutation.retire(item) then
		return
	end
	itemIds.release(item)
	item:Destroy()
end

return itemFactory
