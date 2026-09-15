--!strict

local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local collectionService = game:GetService("CollectionService")

local attributes = require(replicatedStorage.SharedAssets.Attributes)
local loadouts = require(replicatedStorage.SharedAssets.Dictionaries.Loadouts)
local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)

local AnimationPreloader = require(script.Parent.AnimationPreloader)
local InventoryStore = require(script.Parent.InventoryStore)
local Selection = require(script.Parent.Selection)

local toolControllerHost = {}
toolControllerHost.__index = toolControllerHost

export type ToolActivation = {
	isServerReplication: boolean,
}

type EquipDetails = {
	isSpecialEquip: boolean?,
}

type UnequipDetails = {
	skipAnimation: boolean?,
}

export type ToolController = {
	activate: ((self: ToolController, activation: ToolActivation) -> ())?,
	deactivate: ((self: ToolController, activation: ToolActivation) -> ())?,
	equip: ((self: ToolController, details: EquipDetails?) -> ())?,
	interruptEquip: ((self: ToolController) -> ())?,
	unequip: ((self: ToolController, details: UnequipDetails?) -> ())?,
	getUnequipDuration: ((self: ToolController) -> number)?,
	destroy: ((self: ToolController) -> ())?,
}

type Preloader = {
	preloadItemTypes: (self: Preloader, itemTypes: { string }) -> (),
	preloadState: (self: Preloader, state: InventoryStore.ReadOnlyState) -> (),
	destroy: (self: Preloader) -> (),
}

type Linger = {
	item: Model,
	controller: ToolController,
	generation: number,
}

export type ToolControllerHost = {
	player: Player,
	store: InventoryStore.Store?,
	selection: Selection.Selection?,
	animationPreloader: Preloader,
	item: Model?,
	controller: ToolController?,
	loadingItem: Model?,
	lingering: Linger?,
	interrupted: boolean,
	generation: number,
	connections: { [string]: RBXScriptConnection? },
	destroyed: boolean,
	_destroyController: (self: ToolControllerHost) -> (),
	_destroyLingering: (self: ToolControllerHost) -> (),
	_destroyAll: (self: ToolControllerHost) -> (),
	_beginLinger: (self: ToolControllerHost) -> (),
	_findEquippedItem: (self: ToolControllerHost) -> Model?,
	_playEquipAnimation: (self: ToolControllerHost, controller: ToolController, item: Model) -> (),
	_interruptEquipAnimation: (self: ToolControllerHost) -> (),
	_skipUnequipAnimation: (self: ToolControllerHost) -> (),
	_onSelectionChanged: (self: ToolControllerHost) -> (),
	_matchesServerEquippedItem: (self: ToolControllerHost) -> boolean,
	_tryUpdate: (self: ToolControllerHost) -> (),
	getController: (self: ToolControllerHost) -> ToolController?,
	destroy: (self: ToolControllerHost) -> (),
}

type ItemConfig = {
	controllerClass: string?,
}

function toolControllerHost.new(store: InventoryStore.Store, selection: Selection.Selection): ToolControllerHost
	local self: ToolControllerHost = (
		setmetatable({
			player = players.LocalPlayer,
			store = store,
			selection = selection,
			animationPreloader = AnimationPreloader.new() :: Preloader,
			item = nil,
			controller = nil,
			loadingItem = nil,
			lingering = nil,
			interrupted = false,
			generation = 0,
			connections = {} :: { [string]: RBXScriptConnection? },
			destroyed = false,
		}, toolControllerHost) :: unknown
	) :: ToolControllerHost

	self.animationPreloader:preloadItemTypes(loadouts.getItemTypes(loadouts.starter))
	self.animationPreloader:preloadState(store.state())
	self.connections.changed = store.changed.Event:Connect(function()
		if self.destroyed then
			return
		end
		self.animationPreloader:preloadState(store.state())
		self:_tryUpdate()
	end)
	self.connections.selectionChanged = selection.changed.Event:Connect(function()
		self:_onSelectionChanged()
	end)
	self.connections.added = collectionService:GetInstanceAddedSignal("EquippedItem"):Connect(function(instance)
		if self.player.Character and instance:IsDescendantOf(self.player.Character) then
			self:_tryUpdate()
		end
	end)
	self.connections.removed = collectionService:GetInstanceRemovedSignal("EquippedItem"):Connect(function(instance)
		if instance == self.item then
			self:_tryUpdate()
		end
	end)

	local function bindCharacter(character: Model)
		if self.connections.childAdded then
			self.connections.childAdded:Disconnect()
		end
		if self.connections.childRemoved then
			self.connections.childRemoved:Disconnect()
		end
		self.connections.childAdded = character.ChildAdded:Connect(function()
			self:_tryUpdate()
		end)
		self.connections.childRemoved = character.ChildRemoved:Connect(function()
			self:_tryUpdate()
		end)
	end

	self.connections.characterAdded = self.player.CharacterAdded:Connect(function(character)
		self:_destroyAll()
		bindCharacter(character)
		self:_tryUpdate()
	end)
	self.connections.characterRemoving = self.player.CharacterRemoving:Connect(function()
		self:_destroyAll()
	end)
	if self.player.Character then
		bindCharacter(self.player.Character)
	end
	self:_tryUpdate()
	return self
end

function toolControllerHost._destroyController(self: ToolControllerHost): ()
	self.generation += 1
	self.loadingItem = nil
	local controller = self.controller
	if controller and controller.destroy then
		pcall(controller.destroy, controller)
	end
	self.controller = nil
	self.item = nil
	self.interrupted = false
end

function toolControllerHost._destroyLingering(self: ToolControllerHost): ()
	local lingering = self.lingering
	if lingering == nil then
		return
	end
	self.generation += 1
	self.lingering = nil
	if lingering.controller.destroy then
		pcall(lingering.controller.destroy, lingering.controller)
	end
end

function toolControllerHost._destroyAll(self: ToolControllerHost): ()
	self:_destroyController()
	self:_destroyLingering()
	self.loadingItem = nil
	self.interrupted = false
end

function toolControllerHost._beginLinger(self: ToolControllerHost): ()
	local controller = self.controller
	local item = self.item
	if controller == nil or item == nil or self.lingering ~= nil then
		return
	end

	local shouldPlayUnequipAnimation = not self.interrupted
	self.generation += 1
	self.controller = nil
	self.item = nil
	self.interrupted = false
	if not shouldPlayUnequipAnimation then
		if controller.destroy then
			pcall(controller.destroy, controller)
		end
		return
	end

	local generation = self.generation
	self.lingering = {
		item = item,
		controller = controller,
		generation = generation,
	}

	if controller.unequip then
		local succeeded, errorMessage = pcall(controller.unequip, controller, {})
		if not succeeded then
			warn("[Inventory] Client holster animation failed: " .. tostring(errorMessage))
		end
	end

	local duration = 0
	if controller.getUnequipDuration then
		local succeeded, result = pcall(controller.getUnequipDuration, controller)
		if succeeded and typeof(result) == "number" then
			duration = math.max(result, 0)
		end
	end
	task.delay(duration, function()
		if self.destroyed or self.generation ~= generation then
			return
		end
		local current = self.lingering
		if current == nil or current.controller ~= controller then
			return
		end
		self.lingering = nil
		if controller.destroy then
			pcall(controller.destroy, controller)
		end
	end)
end

function toolControllerHost._findEquippedItem(self: ToolControllerHost): Model?
	local character = self.player.Character
	if character == nil then
		return nil
	end
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Model") and item:HasTag("EquippedItem") then
			return item
		end
	end
	return nil
end

function toolControllerHost._playEquipAnimation(_self: ToolControllerHost, controller: ToolController, item: Model): ()
	if controller.equip == nil then
		return
	end
	local succeeded, errorMessage = pcall(controller.equip, controller, {
		isSpecialEquip = item:GetAttribute(attributes.tool.specialEquip) == true,
	})
	if not succeeded then
		warn("[Inventory] Client equip animation failed: " .. tostring(errorMessage))
	end
end

function toolControllerHost._interruptEquipAnimation(self: ToolControllerHost): ()
	local controller = self.controller
	if controller == nil or controller.interruptEquip == nil or self.interrupted then
		return
	end
	local succeeded, errorMessage = pcall(controller.interruptEquip, controller)
	if not succeeded then
		warn("[Inventory] Client equip interruption failed: " .. tostring(errorMessage))
		return
	end
	self.interrupted = true
end

function toolControllerHost._skipUnequipAnimation(self: ToolControllerHost): ()
	local controller = self.controller
	if controller == nil then
		return
	end

	self.interrupted = true
	if controller.unequip == nil then
		return
	end
	local succeeded = pcall(controller.unequip, controller, { skipAnimation = true })
	if not succeeded then
		warn("[Inventory] Client failed to skip the unequip animation")
	end
end

function toolControllerHost._onSelectionChanged(self: ToolControllerHost): ()
	local store = self.store
	local selection = self.selection
	local controller = self.controller
	local item = self.item
	if store == nil or selection == nil or controller == nil or item == nil or self.lingering ~= nil then
		return
	end

	local selectedSlot = selection.selectedSlot()
	local currentSlot = store.state().currentSlot
	if selectedSlot == currentSlot then
		if self.interrupted then
			self:_playEquipAnimation(controller, item)
			self.interrupted = false
		end
		return
	end
	if selectedSlot == nil then
		self:_interruptEquipAnimation()
		return
	end
	self:_skipUnequipAnimation()
end

function toolControllerHost._matchesServerEquippedItem(self: ToolControllerHost): boolean
	local store = self.store
	local item = self.item
	local character = self.player.Character
	if store == nil or item == nil or character == nil or not item:IsDescendantOf(character) then
		return false
	end
	local currentSlot = store.state().currentSlot
	if currentSlot == nil then
		return false
	end
	local descriptor = store.state().hotbar[tostring(currentSlot)]
	local itemId = item:GetAttribute("ItemId")
	return descriptor ~= nil
		and typeof(itemId) == "string"
		and descriptor.itemId == itemId
		and item:HasTag("EquippedItem")
end

function toolControllerHost._tryUpdate(self: ToolControllerHost): ()
	if self.destroyed then
		return
	end
	local store = self.store
	local character = self.player.Character
	if store == nil or character == nil or not store:isEnabled() then
		self:_destroyAll()
		return
	end

	local item = self:_findEquippedItem()
	if item == nil then
		if self.controller ~= nil then
			self:_beginLinger()
		elseif self.loadingItem ~= nil then
			self:_destroyController()
		end
		return
	end

	if self.lingering ~= nil then
		self:_destroyLingering()
	end
	if item == self.item and self.controller ~= nil then
		self:_onSelectionChanged()
		return
	end
	if item == self.loadingItem then
		return
	end
	if self.controller ~= nil then
		self:_destroyController()
	end

	self.loadingItem = item
	self.generation += 1
	local generation = self.generation
	task.spawn(function()
		local mainRemote = item:WaitForChild("MainRemote", 3)
		if generation ~= self.generation or self.loadingItem ~= item or item.Parent == nil then
			return
		end
		if mainRemote == nil then
			self.loadingItem = nil
			warn("[Inventory] Tool remote did not replicate for " .. item.Name)
			return
		end

		local config = itemUtils.getBaseConfig(item)
		local className = itemUtils.getControllerClass(item)
		local classModule = className and replicatedFirst.ClientControllers.Tools:FindFirstChild(className)
		if classModule == nil or not classModule:IsA("ModuleScript") then
			self.loadingItem = nil
			return
		end

		local controllerClass = require(classModule)
		local succeeded, controllerValue = pcall(controllerClass.new, item, config)
		if not succeeded then
			self.loadingItem = nil
			warn("[Inventory] Client tool controller failed: " .. tostring(controllerValue))
			return
		end
		local controller = controllerValue :: ToolController
		if generation ~= self.generation or self.loadingItem ~= item or item.Parent == nil then
			if controller.destroy then
				pcall(controller.destroy, controller)
			end
			return
		end

		self.item = item
		self.loadingItem = nil
		self.controller = controller
		self:_playEquipAnimation(controller, item)
		self:_onSelectionChanged()
	end)
end

function toolControllerHost.getController(self: ToolControllerHost): ToolController?
	if self.lingering ~= nil or self.controller == nil or not self:_matchesServerEquippedItem() then
		return nil
	end
	return self.controller
end

function toolControllerHost.destroy(self: ToolControllerHost): ()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, connection in self.connections do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(self.connections)
	self:_destroyAll()
	self.animationPreloader:destroy()
	self.store = nil
	self.selection = nil
end

return toolControllerHost
