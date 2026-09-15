--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local currentSlot = require(script.Parent.CurrentSlot)
local equipValidation = require(script.Parent.EquipValidation)
local itemRigging = require(script.Parent.ItemRigging)
local types = require(script.Parent.Parent.Contracts)
local itemFactory = require(script.Parent.Parent.Items.ItemFactory)
local controllerHost = require(script.Parent.ControllerHost)

export type Transition = types.EquipTransition
type Inventory = types.Service
type Factory = itemFactory.Factory
type Host = controllerHost.Host
type State = types.State
type ToolController = types.ToolController
type Prepared = {
	config: types.BaseConfig,
	state: State,
	slot: ObjectValue,
	item: Model,
}
type InternalTransition = Transition & {
	inventory: Inventory,
	host: Host,
	factory: Factory,
	player: Player,
	_currentItem: (InternalTransition, State) -> Model?,
	_waitForHolster: (InternalTransition, number, number) -> boolean,
	_unequip: (InternalTransition, number, number) -> boolean,
	_equip: (InternalTransition, number, number) -> boolean,
	_run: (InternalTransition) -> (),
}

local equipTransition = {}
equipTransition.__index = equipTransition

local function clearPendingTransaction(item: Model): ()
	pcall(item.SetAttribute, item, "PendingTransaction", nil)
end

local function getHolsterDuration(item: Model): number
	local config = itemUtils.getBaseConfig(item)
	local duration = config and config.holsterDurationSeconds
	if typeof(duration) ~= "number" or duration ~= duration or duration < 0 or duration == math.huge then
		return 0
	end
	return duration
end

local function isCurrentVersion(self: InternalTransition, version: number, slotNumber: number?): boolean
	return not self.destroyed and self.transitionVersion == version and self.desiredSlot == slotNumber
end

function equipTransition.new(inventory: Inventory, host: Host, factory: Factory, player: Player): Transition
	local self = (
		setmetatable({
			inventory = inventory,
			host = host,
			factory = factory,
			player = player,
			desiredSlot = nil,
			lastIntentSequence = 0,
			holsterWakeSignal = Instance.new("BindableEvent"),
			holsterWaitVersion = 0,
			holsteringSlot = nil,
			transitionVersion = 0,
			running = false,
			forceCleanup = false,
			destroyed = false,
			setDesiredSlot = equipTransition.setDesiredSlot,
			cancel = equipTransition.cancel,
			forceUnequip = equipTransition.forceUnequip,
			destroy = equipTransition.destroy,
		}, equipTransition) :: unknown
	) :: InternalTransition
	return self
end

function equipTransition._currentItem(_self: InternalTransition, state: State): Model?
	if state.currentSlot == nil then
		return nil
	end
	local slot = state.hotbar:FindFirstChild(tostring(state.currentSlot))
	return if slot and slot:IsA("ObjectValue") and slot.Value and slot.Value:IsA("Model") then slot.Value else nil
end

function equipTransition.setDesiredSlot(
	self: InternalTransition,
	slotNumber: number?,
	intentSequence: number?
): protocol.InventoryResponse
	local didUpdateDesiredSlot = false
	local result: protocol.InventoryResponse = self.inventory:withLock(self.player, function()
		local state = self.inventory:getState(self.player)
		if self.destroyed or state == nil then
			return protocol.failure(protocol.ResponseCodes.notReady)
		end

		if intentSequence ~= nil then
			if not protocol.isFiniteNumber(intentSequence) or intentSequence % 1 ~= 0 or intentSequence < 0 then
				return protocol.failure(protocol.ResponseCodes.invalidPayload)
			end

			local maximumSequence = math.floor(workspace:GetServerTimeNow() * 1000)
				+ protocol.Limits.intentSequenceMaxFutureSeconds * 1000
			if intentSequence > maximumSequence then
				return protocol.failure(protocol.ResponseCodes.invalidPayload)
			end
			if intentSequence <= self.lastIntentSequence then
				return protocol.success({ superseded = true })
			end
			self.lastIntentSequence = intentSequence
		end

		local failure = equipValidation.desiredSlot(state, self.player, slotNumber)
		if failure then
			return failure
		end
		self.desiredSlot = slotNumber
		self.transitionVersion += 1
		didUpdateDesiredSlot = true
		if intentSequence ~= nil and state.replica ~= nil then
			state.replica:setEquipIntentSequence(intentSequence)
		end
		return protocol.success()
	end) :: protocol.InventoryResponse
	if didUpdateDesiredSlot and self.holsteringSlot ~= nil and slotNumber ~= nil then
		self.holsterWakeSignal:Fire()
	end
	if result.ok and not self.running then
		self.running = true
		self:_run()
	end
	return result
end

function equipTransition._waitForHolster(
	self: InternalTransition,
	slotNumber: number,
	duration: number
): boolean
	if duration <= 0 or self.forceCleanup or self.destroyed or self.desiredSlot ~= nil then
		return true
	end

	self.holsteringSlot = slotNumber
	self.holsterWaitVersion += 1
	local waitVersion = self.holsterWaitVersion
	local didFinish = false
	task.delay(duration, function()
		if self.destroyed or self.holsterWaitVersion ~= waitVersion then
			return
		end
		didFinish = true
		self.holsterWakeSignal:Fire()
	end)
	self.holsterWakeSignal.Event:Wait()
	if self.holsterWaitVersion == waitVersion then
		self.holsterWaitVersion += 1
	end
	if self.holsteringSlot == slotNumber then
		self.holsteringSlot = nil
	end
	return didFinish
end

function equipTransition._unequip(self: InternalTransition, slotNumber: number, version: number): boolean
	if not isCurrentVersion(self, version, self.desiredSlot) then
		return false
	end

	local state = self.inventory:getState(self.player)
	if state == nil or state.currentSlot ~= slotNumber then
		return false
	end

	local item = self:_currentItem(state)
	local duration = if item then getHolsterDuration(item) else 0
	local controller = if item then self.host:get(item) else nil

	local beganHolster = self.inventory:withLock(self.player, function(): boolean
		if not isCurrentVersion(self, version, self.desiredSlot) then
			return false
		end
		local lockedState = self.inventory:getState(self.player)
		if lockedState == nil or lockedState ~= state or lockedState.currentSlot ~= slotNumber then
			return false
		end

		if controller and typeof(controller.unequip) == "function" then
			local succeeded, errorMessage = pcall(
				controller.unequip :: types.ControllerMethod,
				controller,
				{ skipAnimation = true }
			)
			if not succeeded then
				warn("[Inventory] Tool controller failed to begin unequip: " .. tostring(errorMessage))
			end
		end
		return true
	end)
	if beganHolster ~= true then
		return false
	end

	while not self.destroyed do
		local didFinishHolster = self:_waitForHolster(slotNumber, duration)
		if self.destroyed then
			return false
		end

		local shouldWaitAgain = false
		local shouldRestoreController = false
		local resolved = self.inventory:withLock(self.player, function(): boolean
			local lockedState = self.inventory:getState(self.player)
			if lockedState == nil or lockedState ~= state or lockedState.currentSlot ~= slotNumber then
				return false
			end
			if not self.forceCleanup and self.desiredSlot == slotNumber then
				shouldRestoreController = true
				return true
			end
			if not self.forceCleanup and self.desiredSlot == nil and not didFinishHolster then
				shouldWaitAgain = true
				return true
			end

			if item then
				self.host:reset(item, lockedState.storedTools)
			end
			currentSlot.clear(lockedState)
			self.inventory:commit(self.player, {}, { clearCurrentSlot = true })
			return true
		end)
		if resolved ~= true then
			return false
		end
		if shouldWaitAgain then
			continue
		end
		if shouldRestoreController then
			if controller and typeof(controller.equip) == "function" then
				local succeeded, errorMessage = pcall(controller.equip :: types.ControllerMethod, controller)
				if not succeeded then
					warn("[Inventory] Tool controller failed to cancel unequip: " .. tostring(errorMessage))
				end
			end
			return true
		end

		self.forceCleanup = false
		if item then
			self.host:destroy(item)
		end
		return true
	end
	return false
end

function equipTransition._equip(self: InternalTransition, slotNumber: number, version: number): boolean
	local preparedResult = self.inventory:withLock(self.player, function()
		local state = self.inventory:getState(self.player)
		if state == nil or not isCurrentVersion(self, version, slotNumber) then
			return nil
		end

		local failure = equipValidation.desiredSlot(state, self.player, slotNumber)
		if failure then
			self.desiredSlot = nil
			return nil
		end

		local slot = self.inventory:getSlot(state, protocol.Zones.hotbar, slotNumber)
		if slot == nil or slot.Value == nil or not slot.Value:IsA("Model") then
			self.desiredSlot = nil
			return nil
		end
		local item: Model = slot.Value
		local config = itemUtils.getBaseConfig(item)
		if config == nil or itemUtils.getControllerClass(item) == nil then
			self.desiredSlot = nil
			return nil
		end
		if not self.inventory.templates:isComplete(item) then
			local repairedItem = self.factory:repair(item)
			if repairedItem == nil then
				self.desiredSlot = nil
				return nil
			end
			slot.Value = repairedItem
			item = repairedItem
			config = itemUtils.getBaseConfig(item)
			if config == nil or itemUtils.getControllerClass(item) == nil then
				self.desiredSlot = nil
				return nil
			end
			self.inventory:rebuildIndex(state)
		end
		item:SetAttribute("PendingTransaction", "equip")
		return { config = config, state = state, slot = slot, item = item }
	end)

	if typeof(preparedResult) ~= "table" then
		return false
	end
	local prepared = preparedResult :: Prepared
	if typeof(prepared.item) ~= "Instance" or not prepared.item:IsA("Model") then
		return false
	end

	local controller: ToolController?
	local ok, result = xpcall(function()
		local character = self.player.Character
		if character == nil or character.Parent == nil or not isCurrentVersion(self, version, slotNumber) then
			return false
		end

		itemRigging.setAnchored(prepared.item, true)
		if not itemRigging.position(prepared.item, character, prepared.config) then
			return false
		end

		controller = self.host:create(self.player, character, prepared.item)
		if controller == nil then
			return false
		end

		if typeof(controller.prepareEquip) == "function" then
			local preparedEquip, prepareError = pcall(controller.prepareEquip, controller)
			if not preparedEquip then
				warn(
					string.format(
						"[Inventory] Equip preparation failed for %s: %s",
						self.player.Name,
						tostring(prepareError)
					)
				)
				return false
			end
		end

		if not isCurrentVersion(self, version, slotNumber) then
			return false
		end
		prepared.item.Parent = character
		local committed = self.inventory:withLock(self.player, function(): boolean
			if not isCurrentVersion(self, version, slotNumber) or self.player:HasTag("Busy") then
				return false
			end
			local state = self.inventory:getState(self.player)
			if state == nil or state ~= prepared.state then
				return false
			end
			clearPendingTransaction(prepared.item)
			prepared.item:AddTag("EquippedItem")
			currentSlot.set(state, slotNumber)
			self.inventory:commit(self.player, {}, { currentSlot = slotNumber })
			return true
		end)
		if committed ~= true then
			return false
		end

		if self.destroyed then
			return false
		end
		if self.desiredSlot ~= slotNumber then
			return true
		end
		itemRigging.setAnchored(prepared.item, false)
		if typeof(controller.equip) == "function" then
			local equipped, equipError = pcall(controller.equip, controller)
			if not equipped then
				warn(
					string.format(
						"[Inventory] Equip activation failed for %s: %s",
						self.player.Name,
						tostring(equipError)
					)
				)
			end
		end
		return true
	end, debug.traceback)

	clearPendingTransaction(prepared.item)
	if not ok then
		pcall(self.host.reset, self.host, prepared.item, prepared.state.storedTools)
		pcall(self.host.destroy, self.host, prepared.item)
		warn(string.format("[Inventory] Equip transition failed for %s: %s", self.player.Name, tostring(result)))
		return false
	end
	if result ~= true and controller ~= nil then
		pcall(self.host.reset, self.host, prepared.item, prepared.state.storedTools)
		pcall(self.host.destroy, self.host, prepared.item)
	end
	return result == true
end

function equipTransition._run(self: InternalTransition): ()
	local blocked = false
	local ok, errorMessage = xpcall(function()
		while not self.destroyed do
			local state = self.inventory:getState(self.player)
			if state == nil then
				break
			end
			local desiredSlot = self.desiredSlot
			local version = self.transitionVersion
			if state.currentSlot == desiredSlot then
				self.forceCleanup = false
				break
			end

			if state.currentSlot ~= nil then
				local completed = self:_unequip(state.currentSlot, version)
				if not completed and self.transitionVersion == version and self.desiredSlot == desiredSlot then
					blocked = true
					break
				end
			end

			if self.destroyed then
				break
			end
			local nextState = self.inventory:getState(self.player)
			local nextSlot = self.desiredSlot
			local nextVersion = self.transitionVersion
			if nextState == nil then
				break
			end
			if nextSlot ~= nil and nextState.currentSlot ~= nextSlot then
				local completed = self:_equip(nextSlot, nextVersion)
				if not completed and self.transitionVersion == nextVersion and self.desiredSlot == nextSlot then
					blocked = true
					break
				end
			end
		end
	end, debug.traceback)

	if not ok then
		self.desiredSlot = nil
		self.transitionVersion += 1
		warn(
			string.format("[Inventory] Equip state machine failed for %s: %s", self.player.Name, tostring(errorMessage))
		)
	end
	self.running = false
	local state = self.inventory:getState(self.player)
	if ok and not blocked and not self.destroyed and state and state.currentSlot ~= self.desiredSlot then
		self.running = true
		task.spawn(self._run, self)
	end
end

function equipTransition.cancel(self: InternalTransition): ()
	self.desiredSlot = nil
	self.transitionVersion += 1
end

function equipTransition.forceUnequip(self: InternalTransition): ()
	self.forceCleanup = true
	self:cancel()
	self.holsterWakeSignal:Fire()
	if not self.running then
		self.running = true
		self:_run()
	end
end

function equipTransition.destroy(self: InternalTransition): ()
	self.destroyed = true
	self.desiredSlot = nil
	self.transitionVersion += 1
	self.forceCleanup = true
	self.holsterWakeSignal:Fire()
	local state = self.inventory:getState(self.player)
	if state then
		for _, slot in ipairs(state.hotbar:GetChildren()) do
			if slot:IsA("ObjectValue") and slot.Value and slot.Value:IsA("Model") then
				clearPendingTransaction(slot.Value)
			end
		end
		local item = self:_currentItem(state)
		if item then
			self.host:reset(item, state.storedTools)
			self.host:destroy(item)
		end
		currentSlot.clear(state)
	end
	self.host:destroyForPlayer(self.player)
	local holsterWakeSignal = self.holsterWakeSignal
	task.defer(function()
		holsterWakeSignal:Destroy()
	end)
end

return equipTransition
