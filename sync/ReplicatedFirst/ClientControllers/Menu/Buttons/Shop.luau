local buttonController = require(script.Parent.Parent.ButtonController)

local shopButtonController = {}
shopButtonController.__index = shopButtonController
setmetatable(shopButtonController, { __index = buttonController })

function shopButtonController:activate()
	self.menuController:toggleTab("Shop")
end

function shopButtonController.new(controllerInfo: buttonController.ButtonControllerInfo)
	return setmetatable(buttonController.new(controllerInfo), shopButtonController)
end

function shopButtonController:destroy()
	buttonController.destroy(self)
end

return shopButtonController
