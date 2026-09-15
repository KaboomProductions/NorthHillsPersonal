local baseState = require(script.Parent.Parent.BaseState)

local healthyState = setmetatable({}, baseState)
healthyState.__index = healthyState
healthyState.stateName = "healthy"

function healthyState.new(controller, stateDefinition: { [string]: any }?)
	local self = baseState.new(controller, healthyState.stateName, stateDefinition)
	return setmetatable(self, healthyState)
end

function healthyState:isActive(stateSnapshot)
	return (stateSnapshot.injuredLevel or 0) <= 0
end

return healthyState
