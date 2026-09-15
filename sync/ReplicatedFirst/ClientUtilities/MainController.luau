local mainController = {}
mainController.__index = mainController

local clientUtilities = script.Parent
local moduleLoader = require(clientUtilities.ModuleLoader)

function mainController:init()
	for _, controller in self.sourceControllers do
		if not controller:IsA("ModuleScript") then
			continue
		end

		local activeController = moduleLoader.startModule(controller)
		if activeController ~= nil then
			table.insert(self.activeControllers, activeController)
		end
	end
end

function mainController.new(controllers: Folder | { ModuleScript })
	local self = setmetatable({}, mainController)

	self.sourceControllers = controllers
	self.activeControllers = {}

	self:init()

	return self
end

function mainController:destroy()
	moduleLoader.destroyModules(self.activeControllers)

	setmetatable(self, nil)
end

return mainController
