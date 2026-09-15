local stateMachineController = {}
stateMachineController.__index = stateMachineController

function stateMachineController:change(newState, extraInfo: { any })
	if self.swappingOut then
		return
	end

	self.swappingOut = true

	extraInfo = extraInfo or {}
	self.pendingState = newState.new(self.ai, extraInfo)

	if self.currentState then
		if self.currentState.exit then
			self.currentState:exit()
		end

		self.currentState:cleanUp()
	end

	self.currentState = self.pendingState
	self.pendingState = nil

	self.agent:SetAttribute("CurrentState", self.currentState.id)
	self.ai:recordActionTime(self.currentState.id)

	if self.currentState.enter then
		self.currentState:enter()
	end

	self.swappingOut = false
end

function stateMachineController.new(ai)
	local self = setmetatable({}, stateMachineController)

	self.ai = ai
	self.agent = self.ai.agent
	self.behavior = self.ai.cachedBehavior
	self.currentState = nil

	return self
end

function stateMachineController:update(deltaTime: number)
	if self.swappingOut then
		return
	end

	if self.currentState and self.currentState.update then
		self.currentState:update(deltaTime)
	end
end

function stateMachineController:destroy()
	if self.currentState then
		self.currentState:cleanUp()
		self.currentState = nil
	end

	setmetatable(self, nil)
end

return stateMachineController
