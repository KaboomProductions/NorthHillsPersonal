--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")

local itemConfigs = replicatedStorage.SharedAssets.Dictionaries.ItemConfigs
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local configTypes = require(replicatedStorage.SharedAssets.Dictionaries.ItemConfigTypes)

local itemUtilities = {}

export type BaseConfig = configTypes.BaseConfig
export type DisplayConfig = configTypes.DisplayConfig
export type MeleeConfig = configTypes.MeleeConfig
export type StackConfig = configTypes.StackConfig
export type ThrowableConfig = configTypes.ThrowableConfig
export type Upgrade = configTypes.Upgrade

local function readConfig(itemOrType: Instance | string): configTypes.ItemConfig?
	local itemType = if typeof(itemOrType) == "Instance" then itemUtilities.resolveItemType(itemOrType) else itemOrType
	local configModule = itemConfigs:FindFirstChild(itemType)
	if configModule == nil or not configModule:IsA("ModuleScript") then
		return nil
	end

	return require(configModule) :: configTypes.ItemConfig
end

function itemUtilities.resolveItemType(item: Instance): string
	local itemType = item:GetAttribute("ItemType")
	local legacyType = item:GetAttribute("Type")
	if typeof(itemType) == "string" and itemType ~= "" then
		return itemType
	end
	if typeof(legacyType) == "string" and legacyType ~= "" then
		return legacyType
	end
	return item.Name
end

function itemUtilities.getBaseConfig(itemOrType: Instance | string): configTypes.BaseConfig?
	return readConfig(itemOrType)
end

-- Compatibility entry point for Shop, Dialogue, and ViewModel consumers.
function itemUtilities.getItemConfig(itemOrType: Instance | string): configTypes.BaseConfig?
	return itemUtilities.getBaseConfig(itemOrType)
end

function itemUtilities.getToolConfig(tool: Tool): configTypes.BaseConfig?
	return itemUtilities.getBaseConfig(tool)
end

function itemUtilities.getControllerClass(itemOrType: Instance | string): string?
	local config = itemUtilities.getBaseConfig(itemOrType)
	return config and config.controllerClass
end

function itemUtilities.canMoveToZone(itemOrType: Instance | string, zone: protocol.Zone): boolean
	if zone ~= protocol.Zones.hotbar then
		return true
	end

	return itemUtilities.getControllerClass(itemOrType) ~= nil
end

function itemUtilities.getStackConfig(itemOrType: Instance | string): configTypes.StackConfig?
	local config = readConfig(itemOrType)
	return config and config.stack
end

function itemUtilities.getThrowableConfig(itemOrType: Instance | string): configTypes.ThrowableConfig?
	local config = readConfig(itemOrType)
	return config and config.throwable
end

function itemUtilities.getUpgrades(itemOrType: Instance | string): { configTypes.Upgrade }?
	local config = readConfig(itemOrType)
	return config and config.upgrades
end

function itemUtilities.getCapacityIncrease(itemOrType: Instance | string): number?
	local config = readConfig(itemOrType)
	return config and config.storageCapacityIncrease
end

function itemUtilities.getDisplay(itemOrType: Instance | string): configTypes.DisplayConfig?
	local config = itemUtilities.getBaseConfig(itemOrType)
	if config == nil then
		return nil
	end

	return {
		displayName = config.displayName,
		description = config.description,
		imageId = if config.imageId > 0 then config.imageId else nil,
	}
end

function itemUtilities.getMeleeConfig(itemOrType: Instance | string): configTypes.MeleeConfig?
	local config = readConfig(itemOrType)
	if config == nil or config.controllerClass ~= "Melee" then
		return nil
	end

	return config :: configTypes.MeleeConfig
end

function itemUtilities.generateItemId(): string
	return httpService:GenerateGUID(false)
end

function itemUtilities.isValidZoneIndex(zone: string, index: number, storageCapacity: number?): boolean
	if index % 1 ~= 0 or index < 1 then
		return false
	end

	if zone == protocol.Zones.hotbar then
		return index <= protocol.Limits.hotbarCapacity
	end

	return zone == protocol.Zones.storage and index <= (storageCapacity or protocol.Limits.storageCapacityMaximum)
end

local function isPersistentPrimitive(value: unknown): boolean
	local valueType = typeof(value)
	if valueType == "number" then
		return (value :: number) == (value :: number)
			and (value :: number) > -math.huge
			and (value :: number) < math.huge
	end

	return valueType == "boolean" or valueType == "string"
end

function itemUtilities.getPersistentAttributes(
	item: Instance,
	config: configTypes.BaseConfig
): configTypes.PersistentAttributes
	local attributes: configTypes.PersistentAttributes = {}
	for attributeName in pairs(config.persistentAttributes or {}) do
		local value = item:GetAttribute(attributeName)
		if isPersistentPrimitive(value) then
			attributes[attributeName] = value :: configTypes.Primitive
		end
	end

	return attributes
end

function itemUtilities.sanitizePersistentAttributes(
	config: configTypes.BaseConfig,
	attributes: unknown
): configTypes.PersistentAttributes
	local sanitized: configTypes.PersistentAttributes = {}
	if typeof(attributes) ~= "table" then
		attributes = {}
	end

	local typedAttributes = attributes :: { [string]: unknown }
	for attributeName, defaultValue in pairs(config.persistentAttributes or {}) do
		local value = typedAttributes[attributeName]
		if isPersistentPrimitive(value) and typeof(value) == typeof(defaultValue) then
			sanitized[attributeName] = value :: configTypes.Primitive
		elseif isPersistentPrimitive(defaultValue) then
			sanitized[attributeName] = defaultValue
		end
	end

	return sanitized
end

function itemUtilities.applyPersistentAttributes(
	item: Instance,
	config: configTypes.BaseConfig,
	attributes: unknown
): ()
	for attributeName, value in pairs(itemUtilities.sanitizePersistentAttributes(config, attributes)) do
		item:SetAttribute(attributeName, value)
	end
end

function itemUtilities.getMaxStack(config: configTypes.BaseConfig): number
	local stack = config.stack
	local maxCount = if stack then stack.maxCount else nil
	return if typeof(maxCount) == "number" and maxCount % 1 == 0 and maxCount >= 1 then maxCount else 1
end

function itemUtilities.getStackCount(item: Instance, config: configTypes.BaseConfig?): number
	local maxCount = if config then itemUtilities.getMaxStack(config) else 1
	local count = item:GetAttribute("StackCount")
	return if typeof(count) == "number" and count % 1 == 0 then math.clamp(count, 1, maxCount) else 1
end

function itemUtilities.areStacksCompatible(first: Instance, second: Instance, config: configTypes.BaseConfig): boolean
	if itemUtilities.resolveItemType(first) ~= itemUtilities.resolveItemType(second) then
		return false
	end

	local firstAttributes = itemUtilities.getPersistentAttributes(first, config)
	local secondAttributes = itemUtilities.getPersistentAttributes(second, config)
	for attributeName in pairs(config.persistentAttributes or {}) do
		if firstAttributes[attributeName] ~= secondAttributes[attributeName] then
			return false
		end
	end

	return true
end

function itemUtilities.getMergeAmount(sourceCount: number, targetCount: number, maxCount: number): number
	return math.max(0, math.min(sourceCount, maxCount - targetCount))
end

function itemUtilities.makeDescriptor(item: Instance): protocol.ItemDescriptor?
	local itemId = item:GetAttribute("ItemId")
	local itemType = itemUtilities.resolveItemType(item)
	local config = itemUtilities.getBaseConfig(itemType)
	if typeof(itemId) ~= "string" or itemId == "" or config == nil then
		return nil
	end

	return {
		itemId = itemId,
		itemType = itemType,
		stackCount = itemUtilities.getStackCount(item, config),
		attributes = itemUtilities.getPersistentAttributes(item, config),
	}
end

function itemUtilities.checkForTool(character: Model): Model?
	for _, tool in character:GetChildren() do
		if not tool:IsA("Model") or not tool:HasTag("EquippedItem") then
			continue
		end

		return tool
	end

	return nil
end

function itemUtilities.isRigArtifact(instance: Instance, toolName: string): boolean
	if instance.Name ~= toolName then
		return false
	end

	return instance:IsA("JointInstance")
		or instance:IsA("WeldConstraint")
		or instance:IsA("RigidConstraint")
		or instance:IsA("Weld")
end

return itemUtilities
