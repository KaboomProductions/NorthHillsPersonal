local entitiesController = {}
entitiesController.__index = entitiesController

function entitiesController:init() end

function entitiesController.new()
	local self = setmetatable({}, entitiesController)
	self.connections = {}

	task.spawn(self.init, self)

	return self
end

function entitiesController:destroy()
	setmetatable(self, nil)
end

return entitiesController
