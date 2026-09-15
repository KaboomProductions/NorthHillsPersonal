--!strict

local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local userInputService = game:GetService("UserInputService")

local clientData = require(replicatedFirst.ClientData)
local InventoryStore = require(script.Parent.Parent.InventoryStore)
local Selection = require(script.Parent.Parent.Selection)
local ToolControllerHost = require(script.Parent.Parent.ToolControllerHost)

local toolInput = {}
toolInput.__index = toolInput

export type ToolInput = {
	player: Player,
	store: InventoryStore.Store?,
	selection: Selection.Selection?,
	toolHost: ToolControllerHost.ToolControllerHost?,
	connections: { [string]: RBXScriptConnection? },
	destroy: (self: ToolInput) -> (),
}

function toolInput.new(
	store: InventoryStore.Store,
	toolHost: ToolControllerHost.ToolControllerHost,
	selection: Selection.Selection
): ToolInput
	local self: ToolInput = (
		setmetatable({
			player = players.LocalPlayer,
			store = store,
			selection = selection,
			toolHost = toolHost,
			connections = {} :: { [string]: RBXScriptConnection? },
		}, toolInput) :: unknown
	) :: ToolInput
	self.connections.began = userInputService.InputBegan:Connect(function(input, processed)
		local currentStore = self.store
		local currentSelection = self.selection
		local currentToolHost = self.toolHost
		if
			currentStore == nil
			or currentSelection == nil
			or currentToolHost == nil
			or processed
			or not currentStore:isEnabled()
			or clientData.InInventory
			or currentSelection:isPending()
			or currentToolHost:getController() == nil
		then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local controller = currentToolHost:getController()
			local activate = controller and controller.activate
			if controller and activate then
				activate(controller, { isServerReplication = false })
			end
		end
	end)
	self.connections.ended = userInputService.InputEnded:Connect(function(input, processed)
		local currentStore = self.store
		local currentSelection = self.selection
		local currentToolHost = self.toolHost
		if
			currentStore == nil
			or currentSelection == nil
			or currentToolHost == nil
			or processed
			or not currentStore:isEnabled()
			or clientData.InInventory
			or currentSelection:isPending()
			or currentToolHost:getController() == nil
		then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local controller = currentToolHost:getController()
			local deactivate = controller and controller.deactivate
			if controller and deactivate then
				deactivate(controller, { isServerReplication = false })
			end
		end
	end)
	return self
end

function toolInput:destroy(): ()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.store = nil
	self.selection = nil
	self.toolHost = nil
end

return toolInput
