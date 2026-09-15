local guiEventController = {}
guiEventController.__index = guiEventController

local childControllers = script:GetChildren()

function guiEventController:init()
	for _, controller in childControllers do
		if not controller:IsA("ModuleScript") then
			continue
		end

		controller = require(controller)

		if controller.init then
			controller.init()
		end
	end
end

function guiEventController.new()
	local self = setmetatable({}, guiEventController)
	self.controllers = {}

	task.spawn(self.init, self)

	return self
end

function guiEventController:destroy()
	setmetatable(self, nil)
end

return guiEventController
