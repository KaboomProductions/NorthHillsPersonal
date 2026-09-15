--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local currentSlot = require(script.Parent.Parent.Equipment.CurrentSlot)
local types = require(script.Parent.Parent.Contracts)
local itemFactory = require(script.Parent.Parent.Items.ItemFactory)
local projectileCosmetics = require(script.Parent.Parent.Items.ProjectileCosmetics)
local controllerHost = require(script.Parent.Parent.Equipment.ControllerHost)

export type PendingThrows = types.PendingThrows
type Inventory = types.InventoryApi
type Factory = itemFactory.Factory
type Cosmetics = projectileCosmetics.Cosmetics
type ToolHost = controllerHost.Host
type Projectiles = types.ProjectileController

local pendingThrows = {}
pendingThrows.__index = pendingThrows

function pendingThrows.new(
	inventory: Inventory,
	factory: Factory,
	cosmetics: Cosmetics,
	toolHost: ToolHost,
	projectiles: Projectiles
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
			folder = folder,
			pending = {},
			_finalize = pendingThrows._finalize,
			_launch = pendingThrows._launch,
			throw = pendingThrows.throw,
			release = pendingThrows.release,
			destroyForPlayer = pendingThrows.destroyForPlayer,
		}, pendingThrows) :: unknown
	) :: PendingThrows
end

function pendingThrows._finalize(self: PendingThrows, throwId: string): ()
	local entry = self.pending[throwId]
	if entry == nil or entry.finalized then
		return
	end
	entry.finalized = true
	self.pending[throwId] = nil
	self.factory:destroy(entry.item)
end

function pendingThrows._launch(self: PendingThrows, throwId: string): boolean
	local entry = self.pending[throwId]
	if entry == nil or entry.launched then
		return false
	end
	entry.launched = true
	local finalize = function()
		self:_finalize(throwId)
	end
	local cosmetic: Model? = nil
	local existingCosmetic = self.cosmetics.folder:FindFirstChild(entry.projectileId)
	if existingCosmetic and existingCosmetic:IsA("Model") then
		cosmetic = existingCosmetic
	else
		cosmetic = self.cosmetics:ensure(entry.itemType)
	end
	if cosmetic == nil then
		finalize()
		return false
	end
	local projectileObject: Model = (cosmetic :: unknown) :: Model
	local filterDescendantsInstances: { Instance } = {
		(entry.character :: unknown) :: Instance,
	}
	local projectileData: types.ProjectileData = {
		origin = entry.origin,
		direction = entry.direction,
		velocity = entry.velocity,
		projectileId = entry.projectileId,
		projectileObject = projectileObject,
		filterDescendantsInstances = filterDescendantsInstances,
		specialInfo = { trueId = entry.itemType },
	}
	local projectileHooks: types.ProjectileHooks = {
		onRayHit = function(_cast: unknown, _result: RaycastResult, _velocity: Vector3, _bullet: Instance?)
			finalize()
		end,
		onCastTerminated = function(_cast: unknown)
			finalize()
		end,
	}
	local ok, castValue = pcall(self.projectiles.createProjectile, projectileData, projectileHooks)
	if not ok or typeof(castValue) ~= "table" then
		finalize()
		warn(string.format("[Inventory] Failed to launch throw %s: %s", throwId, tostring(castValue)))
		return false
	end
	local cast: types.ProjectileCast = (castValue :: unknown) :: types.ProjectileCast
	task.delay(15, function()
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
			self.pending[throwId] = {
				player = player,
				character = character,
				item = owned.item,
				itemId = payload.itemId,
				itemType = itemUtils.resolveItemType(owned.item),
				origin = root.Position + root.CFrame.LookVector * 2,
				direction = direction,
				velocity = throwable.velocity,
				projectileId = throwable.projectileId,
				deadline = deadline,
				launched = false,
				finalized = false,
			}
			assert(state.equipTransition, "Inventory equip transition is missing"):cancel()
			self.inventory:commit(player, { { zone = owned.zone, index = owned.index, item = nil } })
			task.defer(function()
				self.toolHost:reset(owned.item, nil)
				self.toolHost:destroy(owned.item)
			end)
			task.delay(math.max(deadline - workspace:GetServerTimeNow(), 0), function()
				self:_launch(throwId)
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

function pendingThrows.destroyForPlayer(self: PendingThrows, player: Player): ()
	for throwId, entry in self.pending do
		if entry.player == player then
			self.factory:destroy(entry.item)
			self.pending[throwId] = nil
		end
	end
end

return pendingThrows
