local eventsController = {}
local childControllers = script:GetChildren()

function eventsController.init()
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

return eventsController
