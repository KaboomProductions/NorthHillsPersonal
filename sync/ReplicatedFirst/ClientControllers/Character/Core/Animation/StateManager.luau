local stateManager = {}
stateManager.__index = stateManager

local function getStateModules(containerInstance: Instance)
	local stateModules = {}

	for _, childInstance in ipairs(containerInstance:GetChildren()) do
		if childInstance:IsA("ModuleScript") then
			table.insert(stateModules, childInstance)
		end
	end

	table.sort(stateModules, function(leftModule, rightModule)
		return leftModule.Name < rightModule.Name
	end)

	return stateModules
end

function stateManager:loadStates()
	local statesFolder = script.Parent:WaitForChild("States")

	for _, stateModuleScript in ipairs(getStateModules(statesFolder)) do
		local stateModule = require(stateModuleScript)
		local stateName = stateModule.stateName
		local stateDefinition = stateName and self.definitions[stateName]

		if stateName and stateDefinition then
			local stateInstance = stateModule.new(self.controller, stateDefinition)
			self.statesByName[stateName] = stateInstance
			table.insert(self.orderedStates, stateInstance)
		end
	end

	table.sort(self.orderedStates, function(leftState, rightState)
		if leftState.priority == rightState.priority then
			return leftState.name < rightState.name
		end

		return leftState.priority > rightState.priority
	end)

	self.defaultState = self.statesByName[self.defaultStateName]
end

function stateManager:resolve(stateSnapshot)
	for _, stateInstance in ipairs(self.orderedStates) do
		if stateInstance:canEnter(stateSnapshot, self.currentState) then
			return stateInstance
		end
	end

	return self.defaultState
end

function stateManager:setState(nextState, stateSnapshot)
	if nextState == self.currentState then
		return false, self.currentState, self.currentState
	end

	if self.currentState and not self.currentState:canExit(nextState, stateSnapshot) then
		return false, self.currentState, self.currentState
	end

	local previousState = self.currentState

	if previousState then
		previousState:exit(nextState, stateSnapshot)
	end

	self.currentState = nextState
	self.currentStateName = nextState and nextState.name or nil

	if self.currentState then
		self.currentState:enter(previousState, stateSnapshot)
	end

	return true, previousState, self.currentState
end

function stateManager:initialize(stateSnapshot)
	local initialState = self:resolve(stateSnapshot)
	self:setState(initialState, stateSnapshot)
end

function stateManager:update(stateSnapshot)
	local resolvedState = self:resolve(stateSnapshot)
	return self:setState(resolvedState, stateSnapshot)
end

function stateManager:getCurrentState()
	return self.currentState
end

function stateManager:getCurrentTracks()
	local activeState = self:getCurrentState()
	return activeState and activeState:getTracks() or nil
end

function stateManager.new(controller, stateDefinitions: { [string]: any }, defaultStateName: string)
	local self = setmetatable({}, stateManager)
	self.controller = controller
	self.currentState = nil
	self.currentStateName = nil
	self.defaultState = nil
	self.defaultStateName = defaultStateName
	self.definitions = stateDefinitions
	self.orderedStates = {}
	self.statesByName = {}

	self:loadStates()

	return self
end

return stateManager
