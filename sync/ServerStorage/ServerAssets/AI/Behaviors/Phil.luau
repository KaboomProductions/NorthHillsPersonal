local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local philBehaviorController = inheriter.extend("Phil")
philBehaviorController.startingState = "Wandering"
philBehaviorController.__vars = {
	ikControl = {
		lerpSpeed = 4,
		weightThreshold = 0.01,
	},
}

function philBehaviorController:setAttackEnabled(state: boolean)
	self.agent:SetAttribute("CanAttack", state)
end

function philBehaviorController:canAttack()
	return self.agent:GetAttribute("CanAttack") and self.ai:isActionReady("attack", self.cooldownConfig.attack)
end

function philBehaviorController:turnToward(position: Vector3)
	self.rootAttachment.CFrame =
		CFrame.lookAt(self.rootPart.Position, Vector3.new(position.X, self.rootPart.Position.Y, position.Z)):Inverse()
end

function philBehaviorController:toggleIKControl(object: any, state: boolean)
	self.ikControlData.targetWeight = state and 1 or 0

	if object then
		self.ikControlData.instance.Target = object
	end
end

function philBehaviorController:toggleAlignOrientation(object: any, state: boolean)
	self.alignOrientation.Enabled = state
	self.humanoid.AutoRotate = not state

	if object then
		self:turnToward(object.Position)
	end
end

function philBehaviorController:controlIKWeight(deltaTime: number)
	local ikData = self.ikControlData
	local ikControl = ikData.instance

	if not ikControl then
		return
	end

	local current = ikData.currentWeight
	local target = ikData.targetWeight

	if math.abs(target - current) <= self.__vars.ikControl.weightThreshold then
		if current ~= target then
			ikData.currentWeight = target
			ikControl.Weight = target
		end
	else
		local alpha = 1 - math.exp(-self.__vars.ikControl.lerpSpeed * deltaTime)
		local newWeight = current + (target - current) * alpha

		ikData.currentWeight = newWeight
		ikControl.Weight = newWeight
	end
end

function philBehaviorController.new(ai)
	local self = inheriter.new(ai, philBehaviorController)

	self.headBone = self.rootPart.HeadBone.Value
	self.rootAttachment = self.rootPart.RootAttachment
	self.alignOrientation = self.rootPart:FindFirstChildOfClass("AlignOrientation")

	self.ikControlData = {
		instance = self.humanoid:FindFirstChildOfClass("IKControl"),
		targetWeight = 0,
		currentWeight = 0,
	}

	return self
end

function philBehaviorController:update(deltaTime: number)
	self:controlIKWeight(deltaTime)
end

return philBehaviorController
