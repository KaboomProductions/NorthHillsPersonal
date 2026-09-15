local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local bootstrapUtilities = require(replicatedStorage.SharedUtilities.Bootstrap)

local player = players.LocalPlayer
local interfaceController = {}
interfaceController.__index = interfaceController

function interfaceController:preload()
	local interface = player.PlayerGui:WaitForChild("Interface")

	self.interface = interface
	self.vignettes = interface.Vignettes
	self.mainFrame = interface.Main
end

function interfaceController:init()
	self:preload()

	self.vignettes.Visible = true
	self.mainFrame.Visible = true
	self.controllers = bootstrapUtilities.startModules(script)
end

function interfaceController.new()
	local self = setmetatable({}, interfaceController)

	self.controllers = {}
	self.interface = nil
	self.vignettes = nil
	self.mainFrame = nil

	task.defer(self.init, self)

	return self
end

function interfaceController:destroy()
	local controllers = self.controllers

	for controllerIndex = #controllers, 1, -1 do
		local controller = controllers[controllerIndex]
		if type(controller) == "table" and type(controller.destroy) == "function" then
			controller:destroy()
		end
	end

	table.clear(controllers)
	table.clear(self)
	setmetatable(self, nil)
end

return interfaceController
