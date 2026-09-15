local stateMachine = {}
stateMachine.__index = stateMachine

export type StateDefinition = {
	name: string,
	priority: number,
	canEnter: ((controller: any) -> boolean)?,
	enter: ((controller: any) -> ())?,
	exit: ((controller: any) -> ())?,
	update: ((controller: any, deltaTime: number) -> ())?,
}

function stateMachine.new()
	local self = setmetatable({}, stateMachine)

	self.states = {} :: { [string]: StateDefinition }
	self.currentState = nil :: StateDefinition?
	self.controller = nil :: any

	return self
end

function stateMachine:setController(controller: any)
	self.controller = controller
end

function stateMachine:addState(state: StateDefinition)
	self.states[state.name] = state
end

function stateMachine:getCurrentStateName(): string?
	return self.currentState and self.currentState.name or nil
end

function stateMachine:transitionTo(stateName: string): boolean
	local targetState = self.states[stateName]
	if targetState == nil then
		warn("[StateMachine] Unknown state: " .. stateName)
		return false
	end

	if self.currentState == targetState then
		return true
	end

	if targetState.canEnter and not targetState.canEnter(self.controller) then
		return false
	end

	local previousState = self.currentState
	if previousState and previousState.exit then
		previousState.exit(self.controller)
	end

	self.currentState = targetState

	if targetState.enter then
		targetState.enter(self.controller)
	end

	return true
end

function stateMachine:evaluate()
	local controller = self.controller
	local bestState = nil :: StateDefinition?

	for _, state in self.states do
		if state.canEnter and not state.canEnter(controller) then
			continue
		end

		if bestState == nil or state.priority > bestState.priority then
			bestState = state
		end
	end

	if bestState == nil then
		return
	end

	if self.currentState ~= bestState then
		self:transitionTo(bestState.name)
	end
end

function stateMachine:update(deltaTime: number)
	if self.currentState and self.currentState.update then
		self.currentState.update(self.controller, deltaTime)
	end
end

function stateMachine:reset()
	if self.currentState and self.currentState.exit then
		self.currentState.exit(self.controller)
	end

	self.currentState = nil
end

function stateMachine:destroy()
	self:reset()
	table.clear(self.states)
	self.controller = nil
end

return stateMachine
