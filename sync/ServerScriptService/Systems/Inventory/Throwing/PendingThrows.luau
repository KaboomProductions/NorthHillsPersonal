--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local currentSlot = require(script.Parent.Parent.Equipment.CurrentSlot)
local types = require(script.Parent.Parent.Contracts)
local itemFactory = require(script.Parent.Parent.Items.ItemFactory)
local itemPlacement = require(script.Parent.Parent.Items.ItemPlacement)
local projectileCosmetics = require(script.Parent.Parent.Items.ProjectileCosmetics)
local controllerHost = require(script.Parent.Parent.Equipment.ControllerHost)
local allocator = require(script.Parent.Parent.Grants.Allocator)
local mutation = require(script.Parent.Parent.State.Mutation)
local dropPlacement = require(script.Parent.Parent.World.DropPlacement)

export type PendingThrows = types.PendingThrows
type Inventory = types.InventoryApi
type Factory = itemFactory.Factory
type Cosmetics = projectileCosmetics.Cosmetics
type ToolHost = controllerHost.Host
type Projectiles = types.ProjectileController
type PendingThrow = types.PendingThrow

local launchTimeoutSeconds = 15

local pendingThrows = {}
pendingThrows.__index = pendingThrows

function pendingThrows.new(
	inventory: Inventory,
	factory: Factory,
	cosmetics: Cosmetics,
	toolHost: ToolHost,
	projectiles: Projectiles,
	worldItems: types.WorldItems
): PendingThrows
	local folder = serverStorage:FindFirstChild("PendingThrows")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "PendingThrows"
		folder.Parent = serverStorage
	end
	assert(folder:IsA("Folder"))
	return (
		setmetatable({
			inventory = inventory,
			factory = factory,
			cosmetics = cosmetics,
			toolHost = toolHost,
			projectiles = projectiles,
			worldItems = worldItems,
			folder = folder,
			pending = {},
			_finalize = pendingThrows._finalize,
			_refund = pendingThrows._refund,
			_restore = pendingThrows._restore,
			_dropToWorld = pendingThrows._dropToWorld,
			_launch = pendingThrows._launch,
			throw = pendingThrows.throw,
			release = pendingThrows.release,
			destroyForPlayer = pendingThrows.destroyForPlayer,
		}, pendingThrows) :: unknown
	) :: PendingThrows
end

local function cancelScheduledThreads(pendingThrow: PendingThrow)
	if pendingThrow.releaseThread then
		task.cancel(pendingThrow.releaseThread)
		pendingThrow.releaseThread = nil
	end
	if pendingThrow.timeoutThread then
		task.cancel(pendingThrow.timeoutThread)
		pendingThrow.timeoutThread = nil
	end
end

local function claimPendingThrow(self: PendingThrows, throwId: string): PendingThrow?
	local pendingThrow = self.pending[throwId]
	if pendingThrow == nil or pendingThrow.finalized then
		return nil
	end
	pendingThrow.finalized = true
	self.pending[throwId] = nil
	cancelScheduledThreads(pendingThrow)
	return pendingThrow
end

function pendingThrows._finalize(self: PendingThrows, throwId: string): ()
	local pendingThrow = claimPendingThrow(self, throwId)
	if pendingThrow then
		self.factory:destroy(pendingThrow.item)
	end
end

function pendingThrows._restore(
	self: PendingThrows,
	state: types.State,
	pendingThrow: PendingThrow
): protocol.InventoryResponse
	local thrownItem = pendingThrow.item
	local player = pendingThrow.player
	local originalZone: protocol.Zone = pendingThrow.zone
	local originalIndex = pendingThrow.index

	mutation.watch(thrownItem)
	thrownItem:SetAttribute("PendingTransaction", nil)

	local originalSlot = self.inventory:getSlot(state, originalZone, originalIndex)
	if originalSlot and originalSlot.Value == nil and itemUtils.canMoveToZone(thrownItem, originalZone) then
		itemPlacement.moveToOwner(thrownItem, state.storedTools)
		originalSlot.Value = thrownItem
		self.inventory:commit(player, { { zone = originalZone, index = originalIndex, item = thrownItem } })
		return protocol.success({ remaining = 0 })
	end

	local allocation = allocator.allocate(state, thrownItem, itemPlacement, state.storedTools)
	if allocation.granted == 0 then
		return protocol.failure(protocol.ResponseCodes.inventoryFull)
	end
	local wasMergedIntoExistingStack = allocation.remaining == 0 and thrownItem.Parent ~= state.storedTools
	if wasMergedIntoExistingStack then
		self.factory:destroy(thrownItem)
	end
	self.inventory:commit(player, allocation.changes)
	return protocol.success({ remaining = allocation.remaining })
end

function pendingThrows._dropToWorld(self: PendingThrows, pendingThrow: PendingThrow): ()
	local thrownItem = pendingThrow.item
	local worldItemsFolder = self.worldItems.folder

	local dropPivot = dropPlacement.calculate(pendingThrow.player, worldItemsFolder)
	if dropPivot == nil then
		warn(
			string.format(
				"[Inventory] Destroying unlaunched %s for %s: no drop location",
				pendingThrow.itemType,
				pendingThrow.player.Name
			)
		)
		self.factory:destroy(thrownItem)
		return
	end

	thrownItem:SetAttribute("PendingTransaction", nil)
	itemPlacement.moveToWorld(thrownItem, worldItemsFolder, dropPivot)
end

local function wasFullyRestored(restoreResponse: unknown): boolean
	if typeof(restoreResponse) ~= "table" then
		return false
	end
	local typedResponse = restoreResponse :: protocol.InventoryResponse
	if not typedResponse.ok or typeof(typedResponse.data) ~= "table" then
		return false
	end
	return (typedResponse.data :: { remaining: number }).remaining == 0
end

function pendingThrows._refund(self: PendingThrows, throwId: string): ()
	local pendingThrow = claimPendingThrow(self, throwId)
	if pendingThrow == nil then
		return
	end

	local player = pendingThrow.player
	local state = self.inventory:getState(player)
	if state == nil or state.removing then
		self.factory:destroy(pendingThrow.item)
		return
	end

	local restoreResponse = self.inventory:withLock(player, function()
		return self:_restore(state, pendingThrow)
	end)
	if wasFullyRestored(restoreResponse) then
		return
	end

	local wasItemDestroyed = pendingThrow.item.Parent == nil
	if wasItemDestroyed then
		return
	end
	self:_dropToWorld(pendingThrow)
end

function pendingThrows._launch(self: PendingThrows, throwId: string): boolean
	local pendingThrow = self.pending[throwId]
	if pendingThrow == nil or pendingThrow.launched then
		return false
	end
	pendingThrow.launched = true
	if pendingThrow.releaseThread then
		task.cancel(pendingThrow.releaseThread)
		pendingThrow.releaseThread = nil
	end
	local finalize = function()
		self:_finalize(throwId)
	end
	local cosmetic: Model? = nil
	local existingCosmetic = self.cosmetics.folder:FindFirstChild(pendingThrow.projectileId)
	if existingCosmetic and existingCosmetic:IsA("Model") then
		cosmetic = existingCosmetic
	else
		cosmetic = self.cosmetics:ensure(pendingThrow.itemType)
	end
	if cosmetic == nil then
		warn(string.format("[Inventory] Throw %s has no projectile cosmetic; refunding", throwId))
		self:_refund(throwId)
		return false
	end
	local projectileObject: Model = (cosmetic :: unknown) :: Model
	local filterDescendantsInstances: { Instance } = {
		(pendingThrow.character :: unknown) :: Instance,
	}
	local projectileData: types.ProjectileData = {
		origin = pendingThrow.origin,
		direction = pendingThrow.direction,
		velocity = pendingThrow.velocity,
		projectileId = pendingThrow.projectileId,
		projectileObject = projectileObject,
		filterDescendantsInstances = filterDescendantsInstances,
		specialInfo = { trueId = pendingThrow.itemType },
	}
	local projectileHooks: types.ProjectileHooks = {
		onRayHit = function(_cast: unknown, _result: RaycastResult, _velocity: Vector3, _bullet: Instance?)
			finalize()
		end,
		onCastTerminated = function(_cast: unknown)
			finalize()
		end,
	}
	local didCreateProjectile, castValue = pcall(self.projectiles.createProjectile, projectileData, projectileHooks)
	if not didCreateProjectile or typeof(castValue) ~= "table" then
		warn(string.format("[Inventory] Failed to launch throw %s; refunding: %s", throwId, tostring(castValue)))
		self:_refund(throwId)
		return false
	end
	local cast: types.ProjectileCast = (castValue :: unknown) :: types.ProjectileCast
	pendingThrow.timeoutThread = task.delay(launchTimeoutSeconds, function()
		if self.pending[throwId] then
			pcall(function()
				cast:Terminate()
			end)
			finalize()
		end
	end)
	return true
end

function pendingThrows.throw(
	self: PendingThrows,
	player: Player,
	payload: protocol.ThrowPayload
): protocol.InventoryResponse
	local state = self.inventory:getState(player)
	if state == nil or state.currentSlot == nil then
		return protocol.failure(protocol.ResponseCodes.notThrowable)
	end
	return (
		self.inventory:withLock(player, function()
			local current = state.hotbar:FindFirstChild(tostring(state.currentSlot))
			local owned = state.index[payload.itemId]
			if owned == nil or owned.slot ~= current then
				return protocol.failure(protocol.ResponseCodes.notOwned)
			end
			local throwable = itemUtils.getThrowableConfig(owned.item)
			if throwable == nil then
				return protocol.failure(protocol.ResponseCodes.notThrowable)
			end
			if player:HasTag("Busy") or owned.item:GetAttribute("PendingTransaction") then
				return protocol.failure(protocol.ResponseCodes.busy)
			end
			local character = player.Character
			if character == nil then
				return protocol.failure(protocol.ResponseCodes.notReady)
			end
			local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
			if root == nil or not root:IsA("BasePart") then
				return protocol.failure(protocol.ResponseCodes.notReady)
			end
			local direction = payload.aimDirection.Unit
			local throwId = itemUtils.generateItemId()
			local deadline = workspace:GetServerTimeNow() + (throwable.releaseTimeoutSeconds or 0.75)
			owned.item:SetAttribute("PendingTransaction", throwId)
			owned.slot.Value = nil
			owned.item.Parent = self.folder
			currentSlot.clear(state)
			local pendingThrow: PendingThrow = {
				player = player,
				character = character,
				item = owned.item,
				itemId = payload.itemId,
				itemType = itemUtils.resolveItemType(owned.item),
				zone = owned.zone,
				index = owned.index,
				origin = root.Position + root.CFrame.LookVector * 2,
				direction = direction,
				velocity = throwable.velocity,
				projectileId = throwable.projectileId,
				deadline = deadline,
				launched = false,
				finalized = false,
				releaseThread = nil,
				timeoutThread = nil,
			}
			self.pending[throwId] = pendingThrow
			mutation.onRollback(function()
				self.pending[throwId] = nil
				cancelScheduledThreads(pendingThrow)
			end)
			assert(state.equipTransition, "Inventory equip transition is missing"):cancel()
			self.inventory:commit(player, { { zone = owned.zone, index = owned.index, item = nil } })
			mutation.afterCommit(function()
				self.toolHost:reset(owned.item, nil)
				self.toolHost:destroy(owned.item)
				local secondsUntilDeadline = math.max(deadline - workspace:GetServerTimeNow(), 0)
				pendingThrow.releaseThread = task.delay(secondsUntilDeadline, function()
					pendingThrow.releaseThread = nil
					self:_launch(throwId)
				end)
			end)
			return protocol.success({ throwId = throwId, deadline = deadline })
		end) :: unknown
	) :: protocol.InventoryResponse
end

function pendingThrows.release(
	self: PendingThrows,
	player: Player,
	payload: protocol.ReleaseThrowPayload
): protocol.InventoryResponse
	local entry = self.pending[payload.throwId]
	if entry == nil or entry.player ~= player or entry.launched then
		return protocol.failure(protocol.ResponseCodes.staleThrow)
	end
	if not self:_launch(payload.throwId) then
		return protocol.failure(protocol.ResponseCodes.internalError)
	end
	return protocol.success()
end

local function findReturnSlot(self: PendingThrows, state: types.State?, pendingThrow: PendingThrow): ObjectValue?
	if state == nil or pendingThrow.launched then
		return nil
	end
	local originalSlot = self.inventory:getSlot(state, pendingThrow.zone, pendingThrow.index)
	if originalSlot == nil or originalSlot.Value ~= nil then
		return nil
	end
	if not itemUtils.canMoveToZone(pendingThrow.item, pendingThrow.zone) then
		return nil
	end
	return originalSlot
end

--// Runs before the leaving player's inventory is persisted so unlaunched throws are saved in their slots.
function pendingThrows.destroyForPlayer(self: PendingThrows, player: Player): ()
	local state = self.inventory:getState(player)
	for throwId, pendingThrow in self.pending do
		if pendingThrow.player ~= player then
			continue
		end
		if claimPendingThrow(self, throwId) == nil then
			continue
		end

		local returnSlot = findReturnSlot(self, state, pendingThrow)
		if returnSlot == nil or state == nil then
			self.factory:destroy(pendingThrow.item)
			continue
		end

		pendingThrow.item:SetAttribute("PendingTransaction", nil)
		itemPlacement.moveToOwner(pendingThrow.item, state.storedTools)
		returnSlot.Value = pendingThrow.item
	end
end

return pendingThrows
