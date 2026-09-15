local newEventController = {}
newEventController.__index = newEventController

local replicatedStorage = game:GetService("ReplicatedStorage")
local networking = require(replicatedStorage.Communication.Networking)

local childControllers = script:GetChildren()

function newEventController:preload()
	for _, controller in childControllers do
		if not controller:IsA("ModuleScript") then
			continue
		end

		self.storedControllers[string.lower(controller.Name)] = require(controller).new(self)
	end
end

function newEventController:onGenericEvent(leadEvent: string, eventType: string, info: {})
	if type(leadEvent) ~= "string" or type(eventType) ~= "string" then
		return
	end

	leadEvent = string.lower(leadEvent)
	local storedController = self.storedControllers[leadEvent]

	if getmetatable(storedController) then
		storedController:onNewEvent(eventType, info)
	end
end

function newEventController:init()
	self:preload()

	self.connections.onGenericEvent = networking.events.generic.OnClientEvent:Connect(
		function(leadEvent: string?, eventType: string?, info: {}?)
			self:onGenericEvent(leadEvent, eventType, info)
		end
	)
end

function newEventController.new()
	local self = setmetatable({}, newEventController)

	self.connections = {}
	self.storedControllers = {}

	task.defer(self.init, self)

	return self
end

function newEventController:destroy()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	for controllerName, controller in self.storedControllers do
		if type(controller.destroy) == "function" then
			controller:destroy()
		end
		self.storedControllers[controllerName] = nil
	end

	setmetatable(self, nil)
end

return newEventController
