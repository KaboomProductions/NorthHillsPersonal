local fuseboxController = {}
fuseboxController.__index = fuseboxController

export type newInfo = {
	instance: Instance,
	prompt: ProximityPrompt,
	promptHolder: Instance,
}

function fuseboxController:preload()
	local instance = self.instance
	local subClassName = instance:GetAttribute("Subclass")

	if type(subClassName) ~= "string" then
		return
	end

	local subClassModule = script:FindFirstChild(subClassName)

	if not (subClassModule and subClassModule:IsA("ModuleScript")) then
		warn(("Missing subclass module: %s"):format(subClassName))
		return
	end

	local module = require(subClassModule)

	if type(module) ~= "table" or type(module.new) ~= "function" then
		warn(("Invalid subclass module API: %s"):format(subClassName))
		return
	end

	local controller = module.new(instance)

	if type(controller) ~= "table" or type(controller.toggle) ~= "function" then
		warn(("Subclass controller missing :toggle() in %s"):format(subClassName))
		return
	end

	self.subClassInteractable = controller
end

function fuseboxController:init()
	local connections = self.connections

	self:preload()

	if self.subClassInteractable ~= nil then
		connections.promptActivated = self.prompt.Triggered:Connect(function(_player: Player)
			self.subClassInteractable:toggle()
		end)

		connections.instanceDestroyed = self.instance.Destroying:Once(function()
			self:destroy()
		end)
	end
end

function fuseboxController.new(info: newInfo)
	local self = setmetatable({}, fuseboxController)

	self.connections = {}
	self.instance = info.instance
	self.prompt = info.prompt
	self.promptHolder = info.promptHolder

	task.spawn(self.init, self)

	return self
end

function fuseboxController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
end

return fuseboxController
