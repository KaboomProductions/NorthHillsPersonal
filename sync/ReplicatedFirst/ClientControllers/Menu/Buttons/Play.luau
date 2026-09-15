local buttonController = require(script.Parent.Parent.ButtonController)

local playButtonController = {}
playButtonController.__index = playButtonController
setmetatable(playButtonController, { __index = buttonController })

function playButtonController:activate()
	self.menuController:exitMenu()
end

function playButtonController.new(controllerInfo: buttonController.ButtonControllerInfo)
	return setmetatable(buttonController.new(controllerInfo), playButtonController)
end

function playButtonController:destroy()
	buttonController.destroy(self)
end

return playButtonController
