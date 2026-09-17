local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local clientData = require(replicatedFirst.ClientData)
local inputBindings = require(replicatedFirst.ClientUtilities.InputBindings)
local mobileButtons = require(replicatedStorage.SharedClasses.MobileButton)
local inventoryStore = require(script.Parent.Parent.InventoryStore)
local selection = require(script.Parent.Parent.Selection)
local toolControllerHost = require(script.Parent.Parent.ToolControllerHost)

local toolInput = {}
toolInput.__index = toolInput

local activationAction = {
	name = "activateTool",
	keyCodes = { Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonR2 },
}

local mobileActivationName = "ActivateTool"

export type Options = {
	store: inventoryStore.Store,
	selection: selection.Selection,
	toolHost: toolControllerHost.ToolControllerHost,
}

export type ToolInput = typeof(setmetatable({
	player = players.LocalPlayer,
	store = nil :: inventoryStore.Store?,
	selection = nil :: selection.Selection?,
	toolHost = nil :: toolControllerHost.ToolControllerHost?,
	pressedController = nil :: toolControllerHost.ToolController?,
	activationBind = nil :: inputBindings.Binding?,
	activationConnection = nil :: inputBindings.Connection?,
	stateConnection = nil :: RBXScriptConnection?,
	activationButton = nil :: GuiButton?,
	resultsHolder = nil :: GuiObject?,
}, toolInput))

function toolInput:isBlocked(): boolean
	local store = self.store
	local currentSelection = self.selection
	return store == nil
		or currentSelection == nil
		or not store:isEnabled()
		or clientData.InInventory
		or (self.resultsHolder ~= nil and self.resultsHolder.Visible)
		or currentSelection:isPending()
		or self.player:GetAttribute("InMenu") == true
end

function toolInput:release()
	local controller = self.pressedController
	self.pressedController = nil
	local host = self.toolHost
	if controller and host and host:getController() == controller and controller.deactivate then
		controller:deactivate({ isServerReplication = false })
	end
end

function toolInput:onActivation(pressed: boolean)
	if not pressed then
		self:release()
		return
	end
	if self:isBlocked() then
		return
	end

	local host = self.toolHost
	local controller = host and host:getController()
	if controller and controller.activate then
		self.pressedController = controller
		controller:activate({ isServerReplication = false })
	end
end

function toolInput:syncActivationState()
	local binding = self.activationBind
	if binding == nil then
		return
	end

	local shouldEnable = not self:isBlocked()
	if binding:IsEnabled() == shouldEnable then
		return
	end

	binding:SetEnabled(shouldEnable)
end

function toolInput:syncActivationButton()
	local host = self.toolHost
	local controller = host and host:getController()
	local button = if controller and not self:isBlocked() then controller.activationButton else nil
	if button == self.activationButton then
		return
	end
	if self.activationButton then
		self.activationButton.Visible = false
		mobileButtons.unRegister(mobileActivationName)
	end
	self.activationButton = button
	if self.activationBind then
		self.activationBind:SetUIButton(button)
	end
	if button then
		mobileButtons.register(mobileActivationName, button)
	end
end

function toolInput:init()
	local interface = self.player.PlayerGui:WaitForChild("Interface")
	self.resultsHolder = interface:WaitForChild("ResultsHolder") :: GuiObject
	local binding = inputBindings.create(activationAction)
	self.activationBind = binding
	self.activationConnection = inputBindings.connect(binding, function(_active: boolean, pressed: boolean)
		self:onActivation(pressed)
	end)
	self:syncActivationState()
	self.stateConnection = runService.Heartbeat:Connect(function()
		self:syncActivationState()
		local host = self.toolHost
		if
			self.pressedController and (self:isBlocked() or not host or host:getController() ~= self.pressedController)
		then
			self:release()
		end
		self:syncActivationButton()
	end)
	self:syncActivationButton()
end

function toolInput.new(options: Options): ToolInput
	local self = setmetatable({}, toolInput)
	self.player = players.LocalPlayer
	self.store = options.store
	self.selection = options.selection
	self.toolHost = options.toolHost
	self:init()
	return self
end

function toolInput:destroy()
	self:release()
	if self.activationButton then
		self.activationButton.Visible = false
		mobileButtons.unRegister(mobileActivationName)
		self.activationButton = nil
	end
	if self.activationBind then
		self.activationBind:Destroy()
		self.activationBind = nil
	end
	if self.stateConnection then
		self.stateConnection:Disconnect()
		self.stateConnection = nil
	end
	self.activationConnection = nil
	self.store = nil
	self.selection = nil
	self.toolHost = nil
end

return toolInput
