local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local attackController = inheriter.extend("Attack")
local childControllers = script:GetChildren()

function attackController:init()
	for _, controller in childControllers do
		if not controller:IsA("ModuleScript") then
			continue
		end

		table.insert(self.activeControllers, require(controller).new(self.ai))
	end
end

function attackController.new(ai)
	local self = inheriter.new(ai, attackController)
	self.activeControllers = {}

	task.spawn(self.init, self)

	return self
end

function attackController:update(deltaTime: number)
	if not self.behavior:canAttack() then
		return
	end

	for _, controller in self.activeControllers do
		controller:update(deltaTime)
	end
end

return attackController
