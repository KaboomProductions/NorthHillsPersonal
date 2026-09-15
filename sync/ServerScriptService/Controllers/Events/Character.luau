local characterEventController = {}
local childControllers = script:GetChildren()

function characterEventController.init()
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

return characterEventController
