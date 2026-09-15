local moduleLoader = require(game:GetService("ReplicatedFirst").ClientUtilities.ModuleLoader)

local effectsController = {}
effectsController.__index = effectsController

function effectsController:init()
	self.controllers = moduleLoader.startModules(script)
end

function effectsController.new()
	local self = setmetatable({}, effectsController)

	self.controllers = {}

	task.defer(self.init, self)

	return self
end

function effectsController:destroy()
	moduleLoader.destroyModules(self.controllers)
	setmetatable(self, nil)
end

return effectsController
