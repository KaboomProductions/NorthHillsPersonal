local inheriter = {}
inheriter.__index = inheriter

function inheriter.extend(stateId: string)
	local newExtendedState = setmetatable({}, {
		__index = inheriter,
	})

	newExtendedState.__index = newExtendedState
	newExtendedState.id = stateId

	return newExtendedState
end

function inheriter.new(ai, state)
	local newInheriter = setmetatable({}, state)

	newInheriter.ai = ai
	newInheriter.behavior = newInheriter.ai.cachedBehavior
	newInheriter.connections = {}

	newInheriter.agent = newInheriter.ai.agent
	newInheriter.humanoid = newInheriter.ai.humanoid
	newInheriter.rootPart = newInheriter.ai.rootPart
	newInheriter.trueAnimator = newInheriter.ai.trueAnimator

	newInheriter.stateMachine = newInheriter.ai.stateMachine
	newInheriter.pathfinder = newInheriter.ai.pathfinder
	newInheriter.speed = newInheriter.ai.speed

	newInheriter.targeting = newInheriter.ai.targeting
	newInheriter.perception = newInheriter.ai.perception

	newInheriter.sharedConfig = newInheriter.ai.sharedConfig
	newInheriter.cooldownConfig = newInheriter.ai.cooldownConfig
	newInheriter.rangeConfig = newInheriter.ai.rangeConfig
	newInheriter.walkSpeedConfig = newInheriter.ai.walkSpeedConfig

	newInheriter.tracks = newInheriter.ai.cachedTracks
	newInheriter.sounds = newInheriter.ai.sounds

	return newInheriter
end

function inheriter:cleanUp()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end
end

function inheriter:destroy()
	self:cleanUp()

	if self.onDestroy then
		self:onDestroy()
	end
end

return inheriter
