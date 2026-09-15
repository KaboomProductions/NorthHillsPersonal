local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local chasingController = inheriter.extend("Chasing")

function chasingController:enter()
	self.ai:runAction("Scream")
	self.behavior:setAttackEnabled(true)
	self.behavior:toggleAlignOrientation()
	self.speed:setModifier("Chasing", self.walkSpeedConfig.run - self.walkSpeedConfig.walk)
	self.agent:SetAttribute("Chasing", true)
end

function chasingController:exit()
	self.behavior:toggleIKControl()
	self.speed:clearModifier("Chasing")
	self.ai:recordActionFlag("NearTarget", false)
end

function chasingController.new(ai)
	return inheriter.new(ai, chasingController)
end

function chasingController:update(_deltaTime: number)
	local nearestTarget = self.targeting:getNearestTarget({
		range = self.rangeConfig.chase,
		useTargetCache = true,
	})

	if nearestTarget then
		self.ai:traverseTo(nearestTarget.root.Position)
		self.behavior:toggleIKControl(nearestTarget.root, true)
	end

	self.ai:recordActionFlag("NearTarget", nearestTarget and nearestTarget.distance <= self.rangeConfig.registerNear)
end

return chasingController
