local replicatedStorage = game:GetService("ReplicatedStorage")

local bootstrapUtilities = require(replicatedStorage.SharedUtilities.Bootstrap)

local quickTimeController = {}
quickTimeController.__index = quickTimeController

function quickTimeController:init()
	self.controllers = bootstrapUtilities.startModules(script)
end

function quickTimeController.new()
	local self = setmetatable({}, quickTimeController)

	self.controllers = {}

	task.defer(self.init, self)

	return self
end

function quickTimeController:destroy()
	local controllers = self.controllers

	for _, controller in controllers do
		if type(controller) == "table" and type(controller.destroy) == "function" then
			controller:destroy()
		end
	end

	table.clear(controllers)
	table.clear(self)
	setmetatable(self, nil)
end

return quickTimeController
