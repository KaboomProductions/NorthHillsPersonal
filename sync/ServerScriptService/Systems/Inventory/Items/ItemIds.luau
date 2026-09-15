--!strict

local itemIds = {}
local reserved: { [string]: boolean } = {}

function itemIds.claim(requestedId: string?, generate: () -> string): string
	local itemId: string
	if requestedId == nil then
		repeat
			itemId = generate()
		until reserved[itemId] ~= true
	elseif typeof(requestedId) ~= "string" or requestedId == "" then
		error("Inventory ItemId must be nil or a non-empty string")
	elseif reserved[requestedId] then
		error(string.format("Duplicate inventory ItemId %s", requestedId))
	else
		itemId = requestedId
	end

	reserved[itemId] = true
	return itemId
end

function itemIds.release(itemOrId: Instance | string)
	local itemId = if typeof(itemOrId) == "Instance" then itemOrId:GetAttribute("ItemId") else itemOrId
	if typeof(itemId) == "string" then
		reserved[itemId] = nil
	end
end

function itemIds.clear()
	table.clear(reserved)
end

return itemIds
