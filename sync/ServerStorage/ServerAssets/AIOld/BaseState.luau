local baseState = {}
baseState.__index = baseState

function baseState.extend(stateName: string)
	local state = setmetatable({}, { __index = baseState })
	state.__index = state
	state.name = stateName

	return state
end

function baseState.new(stateClass, controller, _extraInfo: { [string]: any }?)
	local self = setmetatable({}, stateClass)

	self.controller = controller
	self.agent = controller.agent
	self.humanoid = controller.humanoid
	self.rootPart = controller.rootPart
	self.pathfinder = controller.pathfinder
	self.config = controller.config
	self.sounds = controller.sounds
	self.tracks = controller.tracks
	self.connections = {}

	return self
end

function baseState:cleanupConnections()
	for _, connection in self.connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		elseif typeof(connection) == "thread" then
			pcall(task.cancel, connection)
		end
	end

	table.clear(self.connections)
end

return baseState
