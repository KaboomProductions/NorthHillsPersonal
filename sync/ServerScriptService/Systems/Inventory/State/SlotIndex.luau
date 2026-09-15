--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local types = require(script.Parent.Parent.Contracts)
local playerState = require(script.Parent.PlayerState)

export type Entry = types.IndexEntry
type State = playerState.State

local slotIndex = {}

function slotIndex.rebuild(state: State): ()
	table.clear(state.index)
	local zones: { protocol.Zone } = { protocol.Zones.hotbar, protocol.Zones.storage }
	for _, zone in ipairs(zones) do
		local folder = if zone == protocol.Zones.hotbar then state.hotbar else state.storage
		for _, child in ipairs(folder:GetChildren()) do
			if not child:IsA("ObjectValue") or child.Value == nil or not child.Value:IsA("Model") then
				continue
			end
			if materialUtils.isMaterialType(itemUtils.resolveItemType(child.Value)) then
				continue
			end

			local itemId = child.Value:GetAttribute("ItemId")
			local index = tonumber(child.Name)
			if typeof(itemId) == "string" and index and state.index[itemId] == nil then
				local entry: Entry = {
					item = child.Value,
					slot = child,
					zone = zone :: protocol.Zone,
					index = index,
				}
				state.index[itemId] = entry
			end
		end
	end
end

function slotIndex.findOwned(state: State, itemId: string): Entry?
	return state.index[itemId]
end

function slotIndex.isCurrent(state: State, slot: ObjectValue): boolean
	if state.currentSlot == nil then
		return false
	end
	return slot == state.hotbar:FindFirstChild(tostring(state.currentSlot))
end

function slotIndex.descriptor(item: Instance): protocol.ItemDescriptor?
	return itemUtils.makeDescriptor(item) :: protocol.ItemDescriptor?
end

return slotIndex
