local maxTransitionHistoryLength = 10

local stateMachine = {}
stateMachine.__index = stateMachine

function stateMachine:change(stateModule, extraInfo: { [string]: unknown }?)
	if self.controller:isInactive() then
		return
	end

	local safeExtraInfo = extraInfo or {}

	local staticCanEnter = stateModule.canEnter
	if staticCanEnter and not staticCanEnter(self.controller, safeExtraInfo) then
		if self.debugEnabled then
			warn("[StateMachine] Transition to '" .. (stateModule.name or "?") .. "' rejected by static canEnter")
		end

		return
	end

	local currentState = self.currentState
	local newState = stateModule.new(self.controller, safeExtraInfo)
	
	if currentState then
		if currentState.exit then
			currentState:exit()
		end

		if currentState.cleanupConnections then
			currentState:cleanupConnections()
		end
	end

	self.currentState = newState

	local transitionEntry = {
		from = currentState and currentState.name or nil,
		to = newState.name,
		timestamp = os.clock(),
	}

	table.insert(self.transitionHistory, transitionEntry)
	if #self.transitionHistory > maxTransitionHistoryLength then
		table.remove(self.transitionHistory, 1)
	end

	self.controller.agent:SetAttribute("CurrentState", newState.name)

	if newState.enter then
		newState:enter()
	end
end

function stateMachine:update(deltaTime: number)
	if self.controller:isInactive() then
		return
	end

	local currentState = self.currentState
	if currentState and currentState.update then
		currentState:update(deltaTime)
	end
end

function stateMachine:getCurrentName(): string?
	local currentState = self.currentState
	if not currentState then
		return nil
	end

	return currentState.name
end

function stateMachine:getTransitionHistory(): { { from: string?, to: string, timestamp: number } }
	return self.transitionHistory
end

function stateMachine.new(controller)
	local self = setmetatable({}, stateMachine)

	self.controller = controller
	self.currentState = nil
	self.transitionHistory = {}
	self.debugEnabled = false

	return self
end

function stateMachine:destroy()
	local currentState = self.currentState
	if currentState then
		if currentState.exit then
			currentState:exit()
		end

		if currentState.cleanupConnections then
			currentState:cleanupConnections()
		end
	end

	self.currentState = nil
	self.controller = nil
	table.clear(self.transitionHistory)
end

return stateMachine
