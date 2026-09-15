--!strict

local marketplaceService = game:GetService("MarketplaceService")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local loadouts = require(replicatedStorage.SharedAssets.Dictionaries.Loadouts)
local itemUtilities = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtilities = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local inventoryContracts = require(serverScriptService.Systems.Inventory.Contracts)

type Loadout = loadouts.Loadout
type LoadoutItem = loadouts.LoadoutItem
type InventoryService = inventoryContracts.Service
type InventoryState = inventoryContracts.State

type PlayerLoadoutSession = {
	ownedKitIds: { [string]: boolean },
	characterAddedConnection: RBXScriptConnection?,
	isGranting: boolean,
	shouldRerunGrant: boolean,
}

local starterItemsController = {}

local inventoryService: InventoryService? = nil
local sessionsByPlayer: { [Player]: PlayerLoadoutSession } = {}
local purchaseFinishedConnection: RBXScriptConnection? = nil

local function warnForLoadout(loadout: Loadout, message: string)
	warn(string.format("[StarterItems] %s: %s", loadout.id, message))
end

local function validateLoadoutItems(service: InventoryService, loadout: Loadout): boolean
	local areItemsValid = true

	for _, loadoutItem in ipairs(loadout.items) do
		local isTemplateValid, invalidReason = service.templates:validate(loadoutItem.itemType)
		if not isTemplateValid then
			warnForLoadout(loadout, tostring(invalidReason))
			areItemsValid = false
			continue
		end

		local preferredZone: protocol.Zone? = loadoutItem.preferredZone
		if preferredZone and not itemUtilities.canMoveToZone(loadoutItem.itemType, preferredZone) then
			warnForLoadout(loadout, string.format("%s cannot be placed in %s", loadoutItem.itemType, preferredZone))
			areItemsValid = false
		end
	end

	return areItemsValid
end

local function validateLoadoutMaterials(loadout: Loadout): boolean
	local areMaterialsValid = true

	for materialType, targetBalance in pairs(loadout.materials) do
		if not materialUtilities.isMaterialType(materialType) then
			warnForLoadout(loadout, string.format("unknown material %s", tostring(materialType)))
			areMaterialsValid = false
			continue
		end

		local isWholePositive = protocol.isFiniteNumber(targetBalance) and targetBalance % 1 == 0 and targetBalance >= 1
		if not isWholePositive then
			warnForLoadout(loadout, string.format("invalid amount for %s", materialType))
			areMaterialsValid = false
		end
	end

	return areMaterialsValid
end

local function validateLoadout(service: InventoryService, loadout: Loadout): boolean
	local areItemsValid = validateLoadoutItems(service, loadout)
	local areMaterialsValid = validateLoadoutMaterials(loadout)

	return areItemsValid and areMaterialsValid
end

local function collectOwnedItemTypes(inventoryState: InventoryState): { [string]: boolean }
	local ownedItemTypes: { [string]: boolean } = {}

	for _, zoneFolder in { inventoryState.hotbar, inventoryState.storage } do
		for _, slot in ipairs(zoneFolder:GetChildren()) do
			if slot:IsA("ObjectValue") and slot.Value then
				ownedItemTypes[itemUtilities.resolveItemType(slot.Value)] = true
			end
		end
	end

	return ownedItemTypes
end

local function isPreferredSlotUnavailable(responseCode: protocol.ResponseCode): boolean
	return responseCode == protocol.ResponseCodes.occupied or responseCode == protocol.ResponseCodes.invalidSlot
end

local function grantLoadoutItem(
	service: InventoryService,
	player: Player,
	loadoutItem: LoadoutItem
): protocol.ResponseCode
	local itemRecord: protocol.ItemRecord = {
		itemType = loadoutItem.itemType,
		stackCount = loadoutItem.stackCount or 1,
		attributes = loadoutItem.attributes or {},
	}
	local preferredZone: protocol.Zone? = loadoutItem.preferredZone
	local preferredIndex = loadoutItem.preferredIndex

	if preferredZone and preferredIndex then
		local slotResponse = service:giveToSlot(player, itemRecord, preferredZone, preferredIndex)
		if slotResponse.ok then
			return protocol.ResponseCodes.ok
		end
		if not isPreferredSlotUnavailable(slotResponse.code) then
			return slotResponse.code
		end
	end

	return service:addItem(player, itemRecord).code
end

local function isInventoryUnavailable(responseCode: protocol.ResponseCode): boolean
	return responseCode == protocol.ResponseCodes.notReady or responseCode == protocol.ResponseCodes.disabled
end

local function grantMissingItems(
	service: InventoryService,
	player: Player,
	loadout: Loadout,
	inventoryState: InventoryState
): boolean
	local ownedItemTypes = collectOwnedItemTypes(inventoryState)

	for _, loadoutItem in ipairs(loadout.items) do
		if ownedItemTypes[loadoutItem.itemType] then
			continue
		end

		local responseCode: protocol.ResponseCode = grantLoadoutItem(service, player, loadoutItem)
		if responseCode == protocol.ResponseCodes.ok then
			ownedItemTypes[loadoutItem.itemType] = true
			continue
		end
		if isInventoryUnavailable(responseCode) then
			return false
		end

		warnForLoadout(
			loadout,
			string.format("could not grant %s to %s (%s)", loadoutItem.itemType, player.Name, responseCode)
		)
	end

	return true
end

local function topUpMaterials(
	service: InventoryService,
	player: Player,
	loadout: Loadout,
	inventoryState: InventoryState
)
	for materialType, targetBalance in pairs(loadout.materials) do
		local storedBalance = inventoryState.materials[materialType]
		local currentBalance = if protocol.isFiniteNumber(storedBalance) then storedBalance :: number else 0
		if currentBalance >= targetBalance then
			continue
		end

		local grantResult = service:giveMaterial(player, materialType, targetBalance - currentBalance)
		if not grantResult.ok then
			warnForLoadout(
				loadout,
				string.format("could not grant %s to %s (%s)", materialType, player.Name, grantResult.code)
			)
		end
	end
end

local function grantLoadout(service: InventoryService, player: Player, loadout: Loadout)
	local inventoryState = service:getState(player)
	if inventoryState == nil or inventoryState.removing then
		return
	end

	local canContinue = grantMissingItems(service, player, loadout, inventoryState)
	if not canContinue then
		return
	end

	topUpMaterials(service, player, loadout, inventoryState)
end

local function grantOwnedKits(service: InventoryService, player: Player, session: PlayerLoadoutSession)
	for kitId, kit in pairs(loadouts.kits) do
		local isSessionCurrent = sessionsByPlayer[player] == session
		if session.ownedKitIds[kitId] and isSessionCurrent then
			grantLoadout(service, player, kit)
		end
	end
end

local function runGrantPass(player: Player)
	local service = inventoryService
	local session = sessionsByPlayer[player]
	if service == nil or session == nil then
		return
	end
	if session.isGranting then
		session.shouldRerunGrant = true
		return
	end

	session.isGranting = true
	repeat
		session.shouldRerunGrant = false
		grantLoadout(service, player, loadouts.starter)
		grantOwnedKits(service, player, session)
	until not session.shouldRerunGrant or sessionsByPlayer[player] ~= session
	session.isGranting = false
end

local function doesPlayerOwnGamePass(player: Player, gamePassId: number): boolean
	if gamePassId <= 0 then
		return false
	end

	local didLookupSucceed, ownsPass =
		pcall(marketplaceService.UserOwnsGamePassAsync, marketplaceService, player.UserId, gamePassId)
	if not didLookupSucceed then
		warn(
			string.format(
				"[StarterItems] Game pass %d lookup failed for %s: %s",
				gamePassId,
				player.Name,
				tostring(ownsPass)
			)
		)
		return false
	end

	return ownsPass == true
end

local function onGamePassPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	local session = sessionsByPlayer[player]
	if not wasPurchased or session == nil then
		return
	end

	local didUnlockKit = false
	for kitId, kit in pairs(loadouts.kits) do
		if kit.gamePassId == gamePassId and not session.ownedKitIds[kitId] then
			session.ownedKitIds[kitId] = true
			didUnlockKit = true
		end
	end

	if didUnlockKit and player.Character then
		runGrantPass(player)
	end
end

function starterItemsController.init(service: InventoryService)
	inventoryService = service

	validateLoadout(service, loadouts.starter)
	for _, kit in pairs(loadouts.kits) do
		validateLoadout(service, kit)
	end

	if purchaseFinishedConnection == nil then
		purchaseFinishedConnection =
			marketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
	end
end

--// Yields on game pass lookups, so call this after the player's inventory has loaded.
function starterItemsController.onPlayerAdded(player: Player)
	if sessionsByPlayer[player] then
		return
	end

	local session: PlayerLoadoutSession = {
		ownedKitIds = {},
		characterAddedConnection = nil,
		isGranting = false,
		shouldRerunGrant = false,
	}
	sessionsByPlayer[player] = session

	for kitId, kit in pairs(loadouts.kits) do
		if doesPlayerOwnGamePass(player, kit.gamePassId) then
			session.ownedKitIds[kitId] = true
		end
	end

	local didPlayerLeave = sessionsByPlayer[player] ~= session or player.Parent ~= players
	if didPlayerLeave then
		return
	end

	session.characterAddedConnection = player.CharacterAdded:Connect(function()
		runGrantPass(player)
	end)
	if player.Character then
		runGrantPass(player)
	end
end

function starterItemsController.onPlayerRemoving(player: Player)
	local session = sessionsByPlayer[player]
	if session == nil then
		return
	end

	sessionsByPlayer[player] = nil
	if session.characterAddedConnection then
		session.characterAddedConnection:Disconnect()
	end
end

function starterItemsController.doesPlayerOwnKit(player: Player, kitId: string): boolean
	local session = sessionsByPlayer[player]
	return session ~= nil and session.ownedKitIds[kitId] == true
end

return starterItemsController
