--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local starterGui = game:GetService("StarterGui")

local inventoryRemotes = require(replicatedStorage.Communication.InventoryRemotes)

local InventoryStore = require(script.InventoryStore)
local InventoryRequests = require(script.Requests.InventoryRequests)
local Selection = require(script.Selection)
local ThrowFlow = require(script.Requests.ThrowFlow)
local Keybinds = require(script.Input.Keybinds)
local ToolInput = require(script.Input.ToolInput)
local ToolControllerHost = require(script.ToolControllerHost)
local View = require(script.View)

local inventoryController = {}
inventoryController.__index = inventoryController

type Destroyable = {
	destroy: (self: Destroyable) -> (),
}

export type Controller = {
	store: InventoryStore.Store,
	requests: InventoryRequests.Requests,
	selection: Selection.Selection,
	throwFlow: ThrowFlow.ThrowFlow,
	toolHost: ToolControllerHost.ToolControllerHost,
	view: View.View,
	keybinds: Destroyable,
	toolInput: ToolInput.ToolInput,
	destroyed: boolean,
	destroy: (self: Controller) -> (),
}

function inventoryController.new(): Controller?
	local request = inventoryRemotes.waitForClient()
	if request == nil then
		warn("[Inventory] Inventory request remote is unavailable")
		return nil
	end
	local self: Controller = (setmetatable({}, inventoryController) :: unknown) :: Controller
	pcall(starterGui.SetCoreGuiEnabled, starterGui, Enum.CoreGuiType.Backpack, false)
	self.store = InventoryStore.new()
	self.requests = InventoryRequests.new(request, self.store)
	self.selection = Selection.new(self.store, self.requests)
	self.throwFlow = ThrowFlow.new(self.requests, self.store)
	self.toolHost = ToolControllerHost.new(self.store, self.selection)
	self.view = View.new(self.store, self.requests, self.selection, self.throwFlow)
	self.keybinds = Keybinds.new(self.store, self.requests, self.selection, self.view, self.throwFlow)
	self.toolInput = ToolInput.new(self.store, self.toolHost, self.selection)
	self.destroyed = false
	return self
end

function inventoryController:destroy(): ()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.toolInput:destroy()
	self.keybinds:destroy()
	self.view:destroy()
	self.toolHost:destroy()
	self.selection:destroy()
	self.throwFlow:destroy()
	self.requests:destroy()
	self.store:destroy()
	setmetatable(self, nil)
end

return inventoryController
