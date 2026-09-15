local serverStorage = game:GetService("ServerStorage")

local baseState = require(serverStorage.ServerAssets.AI.StateMachine.StateMachine.BaseState)
local repositioningState = baseState.extend("Repositioning")

function repositioningState:enter()
	local controller = self.controller
	local sharedConfig = self.config.shared

	local currentGoal = self.forcedGoal
	local goalTolerance = self.goalTolerance

	local targetInfo = {
		range = sharedConfig.ranges.run,
		canRaycast = false,
	}

	controller:setCanStun(false)

	if self.aroundNearestTarget then
		local nearestTarget = self.controller.targeting:getNearestTarget(targetInfo)

		if nearestTarget ~= nil then
			local directionAway = (self.rootPart.Position - nearestTarget.root.Position).Unit
			currentGoal = nearestTarget.root.Position + (directionAway * self.distanceAway)
		end
	end

	if currentGoal ~= nil then
		self.expirationTime = os.clock() + math.random(3, 4)

		currentGoal = currentGoal
			+ Vector3.new(math.random(-goalTolerance, goalTolerance), 0, math.random(-goalTolerance, goalTolerance))

		while task.wait(1 / 10) do
			if not getmetatable(self) then
				break
			end

			local offset = self.rootPart.Position - currentGoal
			self.distanceToGoal = Vector3.new(offset.X, 0, offset.Z).Magnitude

			controller:traverse(currentGoal)

			if self.distanceToGoal <= sharedConfig.pathDistanceTolerance then
				break
			end

			if os.clock() >= self.expirationTime then
				break
			end
		end
	end

	task.delay(0.05, function()
		controller:setCanStun(true)
		controller.stateMachine:change(self.replacementState, self.stateExtraInfo)
	end)
end

function repositioningState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(repositioningState, controller, extraInfo)

	self.controller = controller
	self.rootPart = self.controller.rootPart

	local safeExtraInfo = extraInfo or {}

	self.aroundNearestTarget = safeExtraInfo.aroundNearestTarget
	self.forcedGoal = safeExtraInfo.forcedGoal
	self.goalTolerance = safeExtraInfo.goalTolerance or 0
	self.distanceAway = self.aroundNearestTarget and safeExtraInfo.distanceAway or 0
	self.replacementState = safeExtraInfo.replacementState or self.controller.states.Running
	self.stateExtraInfo = safeExtraInfo.stateExtraInfo or {}

	return self
end

return repositioningState
