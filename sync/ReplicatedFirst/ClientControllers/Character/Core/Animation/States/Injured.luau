local baseState = require(script.Parent.Parent.BaseState)

local injuredState = setmetatable({}, baseState)
injuredState.__index = injuredState
injuredState.stateName = "injured"

function injuredState.new(controller, stateDefinition: { [string]: any }?)
	local self = baseState.new(controller, injuredState.stateName, stateDefinition)
	return setmetatable(self, injuredState)
end

function injuredState:isActive(stateSnapshot)
	return (stateSnapshot.injuredLevel or 0) > 0
end

return injuredState
