local replicatedStorage = game:GetService("ReplicatedStorage")

local bootstrapUtilities = require(replicatedStorage.SharedUtilities.Bootstrap)

local eventController = {}
eventController.__index = eventController

function eventController.new()
	local self = setmetatable({}, eventController)

	self.controllers = bootstrapUtilities.startModules(script)

	return self
end

function eventController:destroy()
	bootstrapUtilities.destroyModules(self.controllers)
	setmetatable(self, nil)
end

return eventController
