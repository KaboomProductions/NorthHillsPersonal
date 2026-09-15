--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local itemDisplay = {}

export type DisplayDescriptor = {
	itemId: string,
	itemType: string,
	stackCount: number,
	attributes: { [string]: protocol.Primitive },
	imageId: string | number?,
	displayName: string?,
}

local function getDisplay(itemType: string): (string?, string | number?)
	local config = itemUtils.getDisplay(itemType)
	if config == nil then
		return itemType, nil
	end

	return config.displayName, config.imageId
end

function itemDisplay.withDisplay(descriptor: protocol.ItemDescriptor): DisplayDescriptor
	local displayName, imageId = getDisplay(descriptor.itemType)
	return {
		itemId = descriptor.itemId,
		itemType = descriptor.itemType,
		stackCount = descriptor.stackCount,
		attributes = descriptor.attributes,
		imageId = imageId,
		displayName = displayName,
	}
end

return itemDisplay
