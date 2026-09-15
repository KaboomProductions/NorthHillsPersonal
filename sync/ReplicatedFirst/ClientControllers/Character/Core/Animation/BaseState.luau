local baseState = {}
baseState.__index = baseState

function baseState.new(controller, stateName: string, stateDefinition: { [string]: any }?)
	local self = setmetatable({}, baseState)
	self.controller = controller
	self.name = stateName
	self.definition = stateDefinition or {}
	self.priority = self.definition.priority or 0

	return self
end

function baseState:isActive(_stateSnapshot)
	return false
end

function baseState:canEnter(stateSnapshot, _currentState)
	return self:isActive(stateSnapshot)
end

function baseState:canExit(_nextState, _stateSnapshot)
	return true
end

function baseState:enter(_previousState, _stateSnapshot) end

function baseState:exit(_nextState, _stateSnapshot) end

function baseState:getTracks()
	return self.controller.tracks.states[self.name]
end

function baseState:getDefaultVariantName()
	return self.definition.defaultVariant or "walking"
end

function baseState:hasVariant(variantName: string): boolean
	local variantDefinitions = self.definition.variants or {}
	return variantDefinitions[variantName] ~= nil
end

function baseState:getVariantDefinition(variantName: string?)
	local variantDefinitions = self.definition.variants or {}
	return variantName and variantDefinitions[variantName] or nil
end

function baseState:getVariantTracks(variantName: string?)
	local stateTracks = self:getTracks()
	local variantTracksByName = stateTracks and stateTracks.variants or nil
	return variantTracksByName and variantName and variantTracksByName[variantName] or nil
end

function baseState:resolveVariant(stateSnapshot)
	if stateSnapshot.crouching and self:hasVariant("crouching") then
		return "crouching"
	end

	if stateSnapshot.sprinting and self:hasVariant("sprinting") then
		return "sprinting"
	end

	return self:getDefaultVariantName()
end

function baseState:getMovementTracks(variantName: string?)
	local resolvedVariantTracks = self:getVariantTracks(variantName)
	return resolvedVariantTracks and resolvedVariantTracks.movement or nil
end

function baseState:getIdleTrack(variantName: string?)
	local resolvedVariantTracks = self:getVariantTracks(variantName)
	if resolvedVariantTracks and resolvedVariantTracks.idle then
		return resolvedVariantTracks.idle
	end

	local stateTracks = self:getTracks()
	return (stateTracks and stateTracks.idle) or self.controller.tracks.defaultIdle
end

function baseState:getEnterTransition(variantName: string?)
	local resolvedVariantTracks = self:getVariantTracks(variantName)
	return resolvedVariantTracks and resolvedVariantTracks.transitions and resolvedVariantTracks.transitions.enter or nil
end

function baseState:getExitTransition(variantName: string?)
	local resolvedVariantTracks = self:getVariantTracks(variantName)
	return resolvedVariantTracks and resolvedVariantTracks.transitions and resolvedVariantTracks.transitions.exit or nil
end

function baseState:getSpeedKey(variantName: string?)
	local resolvedVariantDefinition = self:getVariantDefinition(variantName)
	return resolvedVariantDefinition and resolvedVariantDefinition.speedKey or self.definition.speedKey
end

return baseState
