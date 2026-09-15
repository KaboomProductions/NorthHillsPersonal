--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local slotIndex = require(script.Parent.Parent.State.SlotIndex)
local types = require(script.Parent.Parent.Contracts)

local upgrade = {}

function upgrade.handle(
	service: types.Service,
	player: Player,
	payload: protocol.UpgradePayload
): protocol.InventoryResponse
	if not service:unequipIfNeeded(player, payload.itemId) then
		return protocol.failure(protocol.ResponseCodes.busy)
	end
	return service:withLock(player, function(): protocol.InventoryResponse
		local state = service:getState(player)
		if state == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		local target = slotIndex.findOwned(state, payload.itemId)
		if target == nil then
			return protocol.failure(protocol.ResponseCodes.notOwned)
		end
		if target.item:GetAttribute("PendingTransaction") then
			return protocol.failure(protocol.ResponseCodes.pending)
		end
		if slotIndex.isCurrent(state, target.slot) then
			return protocol.failure(protocol.ResponseCodes.busy)
		end

		local config = itemUtils.getBaseConfig(target.item)
		if config == nil or itemUtils.getStackCount(target.item, config) ~= 1 then
			return protocol.failure(protocol.ResponseCodes.notUpgradeable)
		end
		local upgrades = itemUtils.getUpgrades(target.item)
		local selectedUpgrade: types.Upgrade?
		for _, candidate in ipairs(upgrades or {}) do
			if candidate.id == payload.upgradeId then
				selectedUpgrade = candidate
				break
			end
		end
		if selectedUpgrade == nil then
			return protocol.failure(protocol.ResponseCodes.notUpgradeable)
		end

		local resultItemType = selectedUpgrade.resultItemType
		local validResult = service.templates:validate(resultItemType)
		if materialUtils.isMaterialType(resultItemType) or not validResult
			or not itemUtils.canMoveToZone(resultItemType, target.zone) then
			return protocol.failure(protocol.ResponseCodes.notUpgradeable)
		end

		local requiredMaterials: { [string]: number } = {}
		for _, requirement in ipairs(selectedUpgrade.materials or {}) do
			if
				not materialUtils.isMaterialType(requirement.materialType)
				or not protocol.isFiniteNumber(requirement.count)
				or requirement.count % 1 ~= 0
				or requirement.count < 1
			then
				return protocol.failure(protocol.ResponseCodes.invalidPayload)
			end

			local existing = requiredMaterials[requirement.materialType] or 0
			local required = existing + requirement.count
			if not protocol.isFiniteNumber(required) then
				return protocol.failure(protocol.ResponseCodes.invalidPayload)
			end
			requiredMaterials[requirement.materialType] = required
		end

		for materialType, required in pairs(requiredMaterials) do
			local available = state.materials[materialType]
			if
				not protocol.isFiniteNumber(available)
				or (available :: number) % 1 ~= 0
				or (available :: number) < required
			then
				return protocol.failure(protocol.ResponseCodes.missingMaterials)
			end
		end

		local replacement = service.factory:replaceClone(target.item, resultItemType)
		target.slot.Value = replacement
		local materialChanges: { [string]: number } = {}
		for materialType, required in pairs(requiredMaterials) do
			local nextCount = (state.materials[materialType] :: number) - required
			state.materials[materialType] = nextCount
			materialChanges[materialType] = nextCount
		end

		service:commit(
			player,
			{ { zone = target.zone, index = target.index, item = replacement } },
			{ materialChanges = materialChanges }
		)
		return protocol.success(itemUtils.makeDescriptor(replacement))
	end) :: protocol.InventoryResponse
end

return upgrade
