local moduleLoader = require(game:GetService("ReplicatedFirst").ClientUtilities.ModuleLoader)

local interfaceController = {}
interfaceController.__index = interfaceController

function interfaceController:init()
	self.controllers = moduleLoader.startModules(script)
end

function interfaceController.new()
	local self = setmetatable({}, interfaceController)

	self.controllers = {}

	task.defer(self.init, self)

	return self
end

function interfaceController:destroy()
	moduleLoader.destroyModules(self.controllers)
	setmetatable(self, nil)
end

return interfaceController
