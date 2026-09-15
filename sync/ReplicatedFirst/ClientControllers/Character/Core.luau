local moduleLoader = require(game:GetService("ReplicatedFirst").ClientUtilities.ModuleLoader)

local coreController = {}
coreController.__index = coreController

function coreController:init()
	self.controllers = moduleLoader.startModules(script)
end

function coreController.new()
	local self = setmetatable({}, coreController)

	self.controllers = {}

	task.defer(self.init, self)

	return self
end

function coreController:destroy()
	moduleLoader.destroyModules(self.controllers)
	setmetatable(self, nil)
end

return coreController
