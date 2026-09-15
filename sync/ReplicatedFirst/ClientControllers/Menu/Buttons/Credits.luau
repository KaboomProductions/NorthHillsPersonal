local buttonController = require(script.Parent.Parent.ButtonController)

local creditsButtonController = {}
creditsButtonController.__index = creditsButtonController
setmetatable(creditsButtonController, { __index = buttonController })

function creditsButtonController:activate()
	self.menuController:toggleTab("Credits")
end

function creditsButtonController.new(controllerInfo: buttonController.ButtonControllerInfo)
	return setmetatable(buttonController.new(controllerInfo), creditsButtonController)
end

function creditsButtonController:destroy()
	buttonController.destroy(self)
end

return creditsButtonController
