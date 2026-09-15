local batsTriggerController = {}
batsTriggerController.__index = batsTriggerController

function batsTriggerController:init()
end

function batsTriggerController.new()
	local self = setmetatable({}, batsTriggerController)
	task.defer(self.init, self)
	return self
end

return batsTriggerController
