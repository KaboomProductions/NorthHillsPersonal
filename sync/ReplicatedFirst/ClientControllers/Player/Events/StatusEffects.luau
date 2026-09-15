local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local dictionaries = sharedAssets.Dictionaries
local statusEffectDefinitions = dictionaries.StatusEffectDefinitions:GetChildren()

local communication = replicatedStorage.Communication
local remoteEvents = communication.RemoteEvents
local characterEvents = remoteEvents.Character
local statusEffectSyncEvent = characterEvents.StatusEffectSync

local statusEffectsController = {}
statusEffectsController.__index = statusEffectsController

type EffectState = {
	generation: number,
	instances: {
		[string]: Instance,
	}?,
	connections: { RBXScriptConnection }?,
}

function statusEffectsController:preload()
	self.definitions = {}

	for _, newDefinition in statusEffectDefinitions do
		if not newDefinition:IsA("ModuleScript") then
			continue
		end

		self.definitions[newDefinition.Name] = require(newDefinition)
	end
end

function statusEffectsController:getOrCreateState(effectId: string): EffectState
	local state = self.activeEffects[effectId]

	if not state then
		state = {
			generation = 0,
			instances = nil,
		}

		self.activeEffects[effectId] = state
	end

	return state
end

function statusEffectsController:teardownEffect(effectId: string)
	local state = self.activeEffects[effectId]

	if not state then
		return
	end

	if state.connections then
		for _, connection in state.connections do
			connection:Disconnect()
		end

		state.connections = nil
	end

	state.instances = nil
end

function statusEffectsController:onApply(payload)
	local definition = self.definitions[payload.effectId]

	if not definition then
		return
	end

	local state = self:getOrCreateState(payload.effectId)
	state.generation = state.generation + 1

	if not state.instances then
		local instances, connections = definition.build()
		state.instances = instances
		state.connections = connections
	end
end

function statusEffectsController:onRemove(payload)
	local definition = self.definitions[payload.effectId]
	local state = self.activeEffects[payload.effectId]

	if not definition or not state then
		return
	end

	state.generation = state.generation + 1
	local latestGeneration = state.generation

	if state.instances then
		definition.destroy(state.instances)
	end

	task.delay(definition.endDuration or 1, function()
		if state.generation ~= latestGeneration then
			return
		end

		self:teardownEffect(payload.effectId)
	end)
end

function statusEffectsController:init()
	self:preload()

	self.connections.onSyncEvent = statusEffectSyncEvent.OnClientEvent:Connect(function(payload)
		if payload.action == "apply" then
			self:onApply(payload)
		else
			self:onRemove(payload)
		end
	end)
end

function statusEffectsController.new()
	local self = setmetatable({}, statusEffectsController)
	self.connections = {}
	self.activeEffects = {}

	task.defer(self.init, self)

	return self
end

function statusEffectsController:destroy()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	for effectId in self.activeEffects do
		self:teardownEffect(effectId)
	end

	table.clear(self.activeEffects)

	setmetatable(self, nil)
end

return statusEffectsController
