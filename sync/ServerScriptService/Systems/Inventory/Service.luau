--!strict

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local inventoryRemotes = require(replicatedStorage.Communication.InventoryRemotes)
local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local projectilesController = require(serverScriptService.Controllers.Projectiles)
local itemPickup = require(serverScriptService.Systems.Interactables.ItemPickup)
local playerData = require(serverScriptService.GameHandler.PlayerData)

local playerState = require(script.Parent.State.PlayerState)
local slotIndex = require(script.Parent.State.SlotIndex)
local mutation = require(script.Parent.State.Mutation)
local templates = require(script.Parent.Items.Templates)
local itemFactory = require(script.Parent.Items.ItemFactory)
local itemPlacement = require(script.Parent.Items.ItemPlacement)
local projectileCosmetics = require(script.Parent.Items.ProjectileCosmetics)
local worldItems = require(script.Parent.World.WorldItems)
local persistenceStore = require(script.Parent.Persistence.PersistenceStore)
local hydrator = require(script.Parent.Persistence.Hydrator)
local inventoryReplica = require(script.Parent.Replication.InventoryReplica)
local controllerHost = require(script.Parent.Equipment.ControllerHost)
local equipTransition = require(script.Parent.Equipment.EquipTransition)
local grant = require(script.Parent.Grants.Grant)
local pendingThrows = require(script.Parent.Throwing.PendingThrows)
local gateway = require(script.Parent.Requests.Gateway)
local rateLimiter = require(script.Parent.Requests.RateLimiter)
local pickupAction = require(script.Parent.Actions.Pickup)
local types = require(script.Parent.Contracts)

export type GrantResult = types.GrantResult
export type ServiceType = types.Service
type State = types.State
type InternalService = ServiceType & {
	pickupLimiter: types.RateLimiter,
}
type PlayerActionContext = {
	service: ServiceType,
	player: Player,
	state: State,
	generation: number,
}

local Service = {}
Service.__index = Service
local singleton: ServiceType?
local playerActionContexts: { [thread]: PlayerActionContext } = (
	setmetatable({}, { __mode = "k" }) :: any
) :: { [thread]: PlayerActionContext }
local playerActionGenerations: { [State]: number } = {}

local function runWithPlayerActionContext(
	context: PlayerActionContext,
	callback: types.TransactionCallback
): types.TransactionValue?
	local currentThread = coroutine.running()
	local previous = playerActionContexts[currentThread]
	playerActionContexts[currentThread] = context
	local packed = table.pack(xpcall(callback, debug.traceback))
	playerActionContexts[currentThread] = previous
	if not packed[1] then
		error(packed[2], 0)
	end
	return table.unpack(packed, 2, packed.n) :: types.TransactionValue?
end

local function isProfileReady(player: Player): boolean
	return playerData.get(player) ~= nil
end

local PICKUP_RATE_LIMIT = 8
local PICKUP_RATE_WINDOW_SECONDS = 1

function Service.new(): ServiceType
	local self = (
		setmetatable({
			pickupLimiter = rateLimiter.new(PICKUP_RATE_LIMIT, PICKUP_RATE_WINDOW_SECONDS),
		}, Service) :: unknown
	) :: InternalService
	self.requestRemote = inventoryRemotes.ensureServer()
	local oldCache = replicatedStorage:FindFirstChild("InventoryCache")
	if oldCache then
		oldCache:Destroy()
	end
	self.states = {}
	self.templates = templates.new()
	self.factory = itemFactory.new(self.templates)
	self.placement = itemPlacement
	self.projectileCosmetics = projectileCosmetics.new(self.templates)
	self.worldItems = worldItems.new(self.factory)
	self.persistence = persistenceStore.new()
	self.hydrator = hydrator.new(self.factory, self.persistence)
	self.toolHost = controllerHost.new()
	self.replica = inventoryReplica
	self.pendingThrows = pendingThrows.new(
		self,
		self.factory,
		self.projectileCosmetics,
		self.toolHost,
		projectilesController,
		self.worldItems
	)
	self.grants = grant.new(self, self.factory, self.placement)
	self.worldItems:adoptExisting()
	self.gateway = gateway.new(self, self.requestRemote)
	itemPickup.setService(self)
	if singleton == nil then
		singleton = self
	end
	return self
end

function Service.start(): ServiceType
	if singleton == nil then
		singleton = Service.new()
	end
	return assert(singleton, "Inventory service was not created")
end

function Service.get(): ServiceType?
	return singleton
end

function Service.getState(self: ServiceType, player: Player): State?
	return self.states[player]
end

function Service.getSlot(_self: ServiceType, state: State, zone: protocol.Zone, index: number): ObjectValue?
	return playerState.getSlot(state, zone, index)
end

function Service.rebuildIndex(_self: ServiceType, state: State): ()
	slotIndex.rebuild(state)
end

function Service.withLock(self: ServiceType, player: Player, callback: types.TransactionCallback): ...unknown
	local state = self.states[player]
	if state == nil or state.removing then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end

	local context = playerActionContexts[coroutine.running()]
	local isPlayerAction = context ~= nil and context.service == self and context.player == player
	local actionContext = if isPlayerAction then context else nil
	local expectedState = if actionContext then actionContext.state else nil
	local expectedGeneration = if actionContext then actionContext.generation else nil
	if isPlayerAction and expectedState ~= state then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	if isPlayerAction and (not state.enabled or (playerActionGenerations[state] or 0) ~= expectedGeneration) then
		return protocol.failure(protocol.ResponseCodes.disabled)
	end

	if not isProfileReady(player) then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end

	local profileGuardedCallback: types.TransactionCallback = function()
		if not isProfileReady(player) then
			return protocol.failure(protocol.ResponseCodes.notReady)
		end
		return callback()
	end
	local guardedCallback = profileGuardedCallback
	if isPlayerAction then
		guardedCallback = function()
			return runWithPlayerActionContext(assert(actionContext, "Player action context is missing"), function()
				local currentState = self.states[player]
				if currentState == nil or currentState.removing then
					return protocol.failure(protocol.ResponseCodes.notReady)
				end
				if currentState ~= expectedState then
					return protocol.failure(protocol.ResponseCodes.notReady)
				end
				if not currentState.enabled or (playerActionGenerations[currentState] or 0) ~= expectedGeneration then
					return protocol.failure(protocol.ResponseCodes.disabled)
				end
				return profileGuardedCallback()
			end)
		end
	end
	--// mutation.run forwards every callback return value, so the queue callback is variadic rather than a TransactionValue.
	local queuedTransaction = function(): ...unknown
		local data = playerData.get(player)
		if data == nil or self.states[player] ~= state or state.removing then
			return protocol.failure(protocol.ResponseCodes.notReady)
		end
		local savedInventory = data.Inventory
		return mutation.run(state, guardedCallback, function()
			data.Inventory = savedInventory
			self:rebuildIndex(state)
			if state.replica then
				state.replica:sync(state)
			end
		end)
	end
	return state.queue:withLock(player, (queuedTransaction :: any) :: types.TransactionCallback)
end

function Service.commit(
	self: ServiceType,
	player: Player,
	changes: { types.AllocationChange },
	extra: {
		storageCapacity: number?,
		currentSlot: number?,
		clearCurrentSlot: boolean?,
		materialChanges: { [string]: number }?,
	}?
): ()
	local state = assert(self.states[player], "Inventory player is not loaded")
	mutation.publish(function()
		self:rebuildIndex(state)
		if not self.persistence:write(player, state) then
			error(string.format("[Inventory] Persistence is not ready for %s", player.Name))
		end
		if state.replica then
			for _, change in ipairs(changes) do
				local descriptor = if change.item then itemUtils.makeDescriptor(change.item) else nil
				state.replica:setSlot(change.zone, change.index, descriptor :: protocol.ItemDescriptor?)
			end
			if extra and extra.materialChanges then
				for materialType, count in pairs(extra.materialChanges) do
					state.replica:setMaterial(materialType, count)
				end
			end
			if extra and typeof(extra.storageCapacity) == "number" then
				state.replica:setCapacity(extra.storageCapacity :: number)
			end
			if extra and extra.clearCurrentSlot == true then
				state.replica:setCurrentSlot(nil)
			elseif extra then
				local currentSlot = extra.currentSlot
				if typeof(currentSlot) == "number" then
					state.replica:setCurrentSlot(currentSlot :: number?)
				end
			end
		end
	end)
end

function Service.loadForPlayer(self: ServiceType, player: Player): boolean
	if self.states[player] then
		return true
	end
	for _, legacyName in ipairs({ "Slots", "Storage" }) do
		local legacyFolder = player:FindFirstChild(legacyName)
		if legacyFolder then
			legacyFolder:Destroy()
		end
	end
	player:SetAttribute("StorageCapacity", nil)
	local state = playerState.new(player)
	self.states[player] = state
	playerActionGenerations[state] = 0
	local hydrated, loadResult = pcall(self.hydrator.load, self.hydrator, player, state)
	if not hydrated then
		warn(string.format("[Inventory] Failed to load inventory for %s: %s", player.Name, tostring(loadResult)))
	end
	if not hydrated or not loadResult then
		self.states[player] = nil
		playerActionGenerations[state] = nil
		for _, item in ipairs(state.storedTools:GetChildren()) do
			self.factory:destroy(item)
		end
		playerState.destroy(state)
		return false
	end
	self:rebuildIndex(state)
	state.replica = self.replica.new(player, state)
	state.equipTransition = equipTransition.new(self, self.toolHost, self.factory, player)
	state.enabled = true
	state.disabledReason = nil

	local function bindCharacter(character: Model)
		if state.connections.humanoidDied then
			state.connections.humanoidDied:Disconnect()
			state.connections.humanoidDied = nil
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			local candidate = character:WaitForChild("Humanoid", 5)
			humanoid = if candidate and candidate:IsA("Humanoid") then candidate else nil
		end
		if self.states[player] ~= state or state.removing or player.Character ~= character then
			return
		end
		if humanoid then
			state.connections.humanoidDied = humanoid.Died:Connect(function()
				if state.equipTransition then
					state.equipTransition:forceUnequip()
				end
			end)
		end
	end
	state.connections.characterAdded = player.CharacterAdded:Connect(bindCharacter)
	state.connections.characterRemoving = player.CharacterRemoving:Connect(function()
		if state.equipTransition then
			state.equipTransition:forceUnequip()
		end
	end)
	if player.Character then
		bindCharacter(player.Character)
	end
	return true
end

function Service.unloadForPlayer(self: ServiceType, player: Player): ()
	local internalSelf = self :: InternalService
	internalSelf.pickupLimiter:clear(player)
	local state = self.states[player]
	if state == nil then
		return
	end
	if state.equipTransition then
		state.equipTransition:destroy()
	end
	self.pendingThrows:destroyForPlayer(player)
	state.removing = true
	playerActionGenerations[state] = nil
	local persisted, persistenceResult = pcall(self.persistence.write, self.persistence, player, state)
	if not persisted or persistenceResult ~= true then
		warn(
			string.format(
				"[Inventory] Failed to persist inventory for %s during unload: %s",
				player.Name,
				tostring(persistenceResult)
			)
		)
	end
	for _, item in ipairs(state.storedTools:GetChildren()) do
		self.factory:destroy(item)
	end
	if player.Character then
		for _, child in ipairs(player.Character:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("ItemId") then
				self.factory:destroy(child)
			end
		end
	end
	if state.replica then
		state.replica:destroy()
	end
	self.gateway:clear(player)
	self.states[player] = nil
	playerState.destroy(state)
end

function Service.giveItem(
	self: ServiceType,
	player: Player,
	itemType: string,
	count: number?,
	attributes: types.PersistentAttributes?
): GrantResult
	if typeof(itemType) ~= "string" or materialUtils.isMaterialType(itemType) then
		warn(string.format("[Inventory] Rejected material %s from giveItem", itemType))
		return {
			ok = false,
			code = protocol.ResponseCodes.invalidPayload,
			granted = 0,
			remaining = count or 0,
			items = {},
		}
	end
	local result = self.grants:giveItem(player, itemType, count, attributes)
	if
		typeof(result.granted) ~= "number"
		or typeof(result.remaining) ~= "number"
		or typeof(result.items) ~= "table"
	then
		return {
			ok = false,
			code = result.code,
			granted = 0,
			remaining = 0,
			items = {},
		}
	end
	return result
end

function Service.giveMaterial(self: ServiceType, player: Player, materialType: string, count: number): GrantResult
	if not materialUtils.isMaterialType(materialType) then
		warn(string.format("[Inventory] Rejected unknown material %s from giveMaterial", materialType))
		return {
			ok = false,
			code = protocol.ResponseCodes.invalidPayload,
			granted = 0,
			remaining = count,
			items = {},
		}
	end
	if not protocol.isFiniteNumber(count) or count % 1 ~= 0 or count < 1 then
		warn(string.format("[Inventory] Rejected invalid material count %s for %s", tostring(count), materialType))
		return {
			ok = false,
			code = protocol.ResponseCodes.invalidPayload,
			granted = 0,
			remaining = count,
			items = {},
		}
	end

	local rawResult: unknown = self:withLock(player, function(): GrantResult
		local state = self:getState(player)
		if state == nil then
			return {
				ok = false,
				code = protocol.ResponseCodes.notReady,
				granted = 0,
				remaining = count,
				items = {},
			}
		end

		local current = state.materials[materialType]
		if not protocol.isFiniteNumber(current) or (current :: number) % 1 ~= 0 or (current :: number) < 0 then
			current = 0
		end
		local nextCount = (current :: number) + count
		if not protocol.isFiniteNumber(nextCount) then
			return {
				ok = false,
				code = protocol.ResponseCodes.invalidPayload,
				granted = 0,
				remaining = count,
				items = {},
			}
		end

		state.materials[materialType] = nextCount
		self:commit(player, {}, { materialChanges = { [materialType] = nextCount } })
		return {
			ok = true,
			code = protocol.ResponseCodes.ok,
			granted = count,
			remaining = 0,
			items = {},
		}
	end)
	if typeof(rawResult) ~= "table" then
		return {
			ok = false,
			code = protocol.ResponseCodes.notReady,
			granted = 0,
			remaining = count,
			items = {},
		}
	end
	local result = rawResult :: { [string]: unknown }
	local resultCode: protocol.ResponseCode = if typeof(result.code) == "string"
		then result.code :: protocol.ResponseCode
		else protocol.ResponseCodes.notReady
	if
		typeof(result.granted) ~= "number"
		or typeof(result.remaining) ~= "number"
		or typeof(result.items) ~= "table"
	then
		return {
			ok = false,
			code = resultCode,
			granted = 0,
			remaining = count,
			items = {},
		}
	end
	return (rawResult :: unknown) :: GrantResult
end

function Service.addItem(self: ServiceType, player: Player, record: protocol.ItemRecord): GrantResult
	if typeof(record) ~= "table" or typeof(record.itemType) ~= "string" then
		return {
			ok = false,
			code = protocol.ResponseCodes.invalidPayload,
			granted = 0,
			remaining = 0,
			items = {},
		}
	end
	if materialUtils.isMaterialType(record.itemType) then
		warn(string.format("[Inventory] Rejected material %s from addItem", record.itemType))
		return {
			ok = false,
			code = protocol.ResponseCodes.invalidPayload,
			granted = 0,
			remaining = record.stackCount,
			items = {},
		}
	end
	local result = self.grants:addItem(player, record)
	if
		typeof(result.granted) ~= "number"
		or typeof(result.remaining) ~= "number"
		or typeof(result.items) ~= "table"
	then
		return {
			ok = false,
			code = result.code,
			granted = 0,
			remaining = 0,
			items = {},
		}
	end
	return result
end

function Service.giveToSlot(
	self: ServiceType,
	player: Player,
	record: protocol.ItemRecord,
	zone: protocol.Zone,
	index: number
): protocol.InventoryResponse
	if typeof(record) ~= "table" or typeof(record.itemType) ~= "string" then
		return protocol.failure(protocol.ResponseCodes.invalidPayload)
	end
	if materialUtils.isMaterialType(record.itemType) then
		warn(string.format("[Inventory] Rejected material %s from giveToSlot", record.itemType))
		return protocol.failure(protocol.ResponseCodes.invalidPayload)
	end
	return self.grants:giveToSlot(player, record, zone, index)
end

function Service.setEnabled(
	self: ServiceType,
	player: Player,
	enabled: boolean,
	reason: string?
): protocol.InventoryResponse
	local state = self.states[player]
	if state == nil then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	if state.enabled and not enabled then
		playerActionGenerations[state] = (playerActionGenerations[state] or 0) + 1
	end
	state.enabled = enabled
	state.disabledReason = if enabled then nil else reason
	if state.replica then
		state.replica:setEnabled(enabled, state.disabledReason)
	end
	if not enabled and state.equipTransition then
		state.equipTransition:forceUnequip()
	end
	return protocol.success()
end

function Service.isEnabled(self: ServiceType, player: Player): boolean
	local state = self.states[player]
	return state ~= nil and state.enabled ~= false
end

function Service.withPlayerAction(
	self: ServiceType,
	player: Player,
	callback: () -> protocol.InventoryResponse
): protocol.InventoryResponse
	local state = self.states[player]
	if state == nil or state.removing then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	if not state.enabled then
		return protocol.failure(protocol.ResponseCodes.disabled)
	end

	local currentThread = coroutine.running()
	local previous = playerActionContexts[currentThread]
	playerActionContexts[currentThread] = {
		service = self,
		player = player,
		state = state,
		generation = playerActionGenerations[state] or 0,
	}
	local packed = table.pack(xpcall(callback, debug.traceback))
	playerActionContexts[currentThread] = previous

	if not packed[1] then
		warn(string.format("[Inventory] Player action failed for %s: %s", player.Name, tostring(packed[2])))
		return protocol.failure(protocol.ResponseCodes.internalError)
	end
	return packed[2] :: protocol.InventoryResponse
end

function Service.equip(self: ServiceType, player: Player, slotNumber: number?): protocol.InventoryResponse
	local state = self.states[player]
	if state == nil or state.equipTransition == nil then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	return state.equipTransition:setDesiredSlot(slotNumber)
end

function Service.forceUnequip(self: ServiceType, player: Player): ()
	local state = self.states[player]
	if state and state.equipTransition then
		state.equipTransition:forceUnequip()
	end
end

function Service.unequipIfNeeded(self: ServiceType, player: Player, itemId: string): boolean
	local state = self.states[player]
	if state == nil or state.currentSlot == nil then
		return state ~= nil
	end
	local slot = state.hotbar:FindFirstChild(tostring(state.currentSlot))
	if slot and slot:IsA("ObjectValue") and slot.Value and slot.Value:GetAttribute("ItemId") == itemId then
		local transition = state.equipTransition
		if transition == nil then
			return false
		end
		local response = transition:setDesiredSlot(nil)
		return response.ok and state.currentSlot == nil
	end
	return true
end

function Service.pickupWorldItem(
	self: ServiceType,
	player: Player,
	item: Model,
	promptHolder: Instance?
): protocol.InventoryResponse
	local internalSelf = self :: InternalService
	local state = self.states[player]
	if state == nil or state.removing then
		return protocol.failure(protocol.ResponseCodes.notReady)
	end
	if not state.enabled then
		return protocol.failure(protocol.ResponseCodes.disabled)
	end
	if not internalSelf.pickupLimiter:consume(player) then
		return protocol.failure(protocol.ResponseCodes.rateLimited)
	end
	return self:withPlayerAction(player, function()
		return pickupAction.handle(self, player, item, promptHolder)
	end)
end

function Service.destroy(self: ServiceType): ()
	for _, player in ipairs(players:GetPlayers()) do
		self:unloadForPlayer(player)
	end
	self.gateway:destroy()
	local internalSelf = self :: InternalService
	internalSelf.pickupLimiter:destroy()
	itemPickup.setService(nil)
	self.worldItems.claims = {}
	if rawequal(singleton, self) then
		singleton = nil
	end
end

return Service
