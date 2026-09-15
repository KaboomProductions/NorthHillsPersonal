local serverStorage = game:GetService("ServerStorage")

local baseState = require(serverStorage.ServerAssets.AI.BaseState)

local walkingState = baseState.extend("Walking")

function walkingState:enter()
	local speedController = self.controller.speedController
	speedController:clearAll()

	self.controller.targeting:clearTargetCache()
end

function walkingState:update(_deltaTime: number)
	local controller = self.controller
	local targeting = controller.targeting
	local ranges = self.config.shared.ranges

	local nearestTarget = targeting:getNearestTarget({
		range = ranges.walk,
		canRaycast = false,
	})

	if not nearestTarget then
		controller.stateMachine:change(controller.states.Wandering)
		return
	end

	controller:traverse(nearestTarget)

	if nearestTarget.distance > ranges.sneak then
		return
	end

	local isVisible = targeting:isTargetVisible(nearestTarget)
	local isTurnedAway = targeting:isTargetTurnedAway(nearestTarget)

	if not isVisible then
		return
	end

	if
		isTurnedAway
		or not isTurnedAway
			and (nearestTarget.distance <= ranges.lungeMinimum and nearestTarget.distance > ranges.lungeMinimum / 4)
	then
		controller.stateMachine:change(controller.states.Sneaking)
	else
		controller.stateMachine:change(controller.states.Running, {
			runAndScream = true,
		})
	end
end

function walkingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(walkingState, controller, extraInfo)
	return self
end

return walkingState
