--!strict

local collectionService = game:GetService("CollectionService")

local replicatedStorage = game:GetService("ReplicatedStorage")
local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local allocator = require(script.Parent.Parent.Grants.Allocator)
local types = require(script.Parent.Parent.Contracts)

local pickup = {}

function pickup.handle(
	service: types.Service,
	player: Player,
	worldItem: Model,
	promptHolder: Instance?
): protocol.InventoryResponse
	if not service.worldItems:claim(worldItem, player) then
		return protocol.failure(protocol.ResponseCodes.busy)
	end
	local character = player.Character
	local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
	local holderPart: BasePart?
	if promptHolder then
		if promptHolder:IsA("BasePart") then
			holderPart = promptHolder
		elseif promptHolder:IsA("Model") then
			holderPart = promptHolder.PrimaryPart or promptHolder:FindFirstChildWhichIsA("BasePart", true)
		else
			holderPart = promptHolder:FindFirstAncestorWhichIsA("BasePart")
		end
	end
	if
		root == nil
		or not root:IsA("BasePart")
		or holderPart == nil
		or (root.Position - holderPart.Position).Magnitude > 15
		or worldItem:GetAttribute("Class") ~= "ItemPickup"
		or not collectionService:HasTag(worldItem, "Interactable")
	then
		service.worldItems:release(worldItem)
		return protocol.failure(protocol.ResponseCodes.invalidPayload)
	end

	local materialType = itemUtils.resolveItemType(worldItem)
	if materialUtils.isMaterialType(materialType) then
		local validMaterial = service.templates:validateMaterial(materialType)
		local count = worldItem:GetAttribute("StackCount")
		if
			not validMaterial
			or not protocol.isFiniteNumber(count)
			or (count :: number) % 1 ~= 0
			or (count :: number) < 1
		then
			service.worldItems:release(worldItem)
			return protocol.failure(protocol.ResponseCodes.invalidPayload)
		end

		local materialResult = service:giveMaterial(player, materialType, count :: number)
		if materialResult.ok then
			service.factory:destroy(worldItem)
			service.worldItems:release(worldItem)
			return protocol.success({ materialType = materialType, granted = materialResult.granted })
		end
		service.worldItems:release(worldItem)
		return protocol.failure(materialResult.code)
	end

	local result: protocol.InventoryResponse = service:withLock(player, function(): protocol.InventoryResponse
		local state = service:getState(player)
		local config = itemUtils.getBaseConfig(worldItem)
		if state == nil or config == nil then
			return protocol.failure(protocol.ResponseCodes.invalidPayload)
		end
		local allocation = allocator.allocate(state, worldItem, service.placement, state.storedTools)
		if allocation.granted == 0 then
			return protocol.failure(protocol.ResponseCodes.inventoryFull)
		end
		if allocation.remaining == 0 then
			collectionService:RemoveTag(worldItem, "Interactable")
			if worldItem.Parent ~= state.storedTools then
				service.factory:destroy(worldItem)
			end
		else
			worldItem:SetAttribute("StackCount", allocation.remaining)
		end
		service:commit(player, allocation.changes)
		return protocol.success({ remaining = allocation.remaining })
	end) :: protocol.InventoryResponse
	service.worldItems:release(worldItem)
	return result
end

return pickup
