local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local healthController = inheriter.extend("Health")

function healthController:init() end

function healthController.new(ai)
	local self = inheriter.new(ai, healthController)

	task.spawn(self.init, self)

	return self
end

function healthController:update(_deltaTime: number) end

return healthController
