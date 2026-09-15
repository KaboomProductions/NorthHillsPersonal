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
	fadeThread: thread?,
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

local function cancelFade(state: EffectState)
	if state.fadeThread then
		task.cancel(state.fadeThread)
		state.fadeThread = nil
	end
end

local function disconnectEffect(state: EffectState)
	if state.connections then
		for _, connection in state.connections do
			connection:Disconnect()
		end
		state.connections = nil
	end
end

function statusEffectsController:teardownEffect(effectId: string, shouldRunDestroy: boolean?)
	local state = self.activeEffects[effectId]

	if not state then
		return
	end

	state.generation = state.generation + 1
	cancelFade(state)
	disconnectEffect(state)

	local definition = self.definitions[effectId]
	if shouldRunDestroy and state.instances and definition then
		local didDestroy, destroyError = pcall(definition.destroy, state.instances)
		if not didDestroy then
			warn(("[StatusEffects] Destroy failed for %s: %s"):format(effectId, tostring(destroyError)))
		end
	end

	state.instances = nil
	self.activeEffects[effectId] = nil
end

function statusEffectsController:onApply(payload)
	local definition = self.definitions[payload.effectId]

	if not definition then
		return
	end

	local state = self:getOrCreateState(payload.effectId)
	state.generation = state.generation + 1

	local isFadingOut = state.fadeThread ~= nil
	if isFadingOut then
		cancelFade(state)
		disconnectEffect(state)
		state.instances = nil
	end

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

	cancelFade(state)

	if state.instances then
		definition.destroy(state.instances)
	end

	state.fadeThread = task.delay(definition.endDuration or 1, function()
		state.fadeThread = nil
		if state.generation ~= latestGeneration then
			return
		end

		self:teardownEffect(payload.effectId, false)
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
		self:teardownEffect(effectId, true)
	end

	table.clear(self.activeEffects)

	setmetatable(self, nil)
end

return statusEffectsController
