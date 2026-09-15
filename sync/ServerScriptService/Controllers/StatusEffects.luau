local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local serverEffects = serverAssets.Effects
local statusEffectParticles = serverEffects.StatusEffects

local communication = replicatedStorage.Communication
local remoteEvents = communication.RemoteEvents
local characterEvents = remoteEvents.Character
local statusEffectSyncEvent = characterEvents.StatusEffectSync

local vfxLifetimePadding = 0.25

local statusEffectManager = {}
statusEffectManager.registeredEffects = {}
statusEffectManager.activeEffects = {}
statusEffectManager.trackedEntities = 0
statusEffectManager.mainConnection = nil

export type EffectInstance = {
	id: string,
	entity: Model,
	config: { [string]: any },
	startTime: number,
	duration: number,
	stacks: number,
	nextTick: number,
	definition: EffectDefinition,
	data: { [string]: any },
}

export type EffectDefinition = {
	id: string,
	defaultDuration: number,
	stackMode: "refresh" | "stack" | "ignore" | "highest",
	maxStacks: number?,
	tickInterval: number?,
	onApply: ((effect: EffectInstance) -> ())?,
	onTick: ((effect: EffectInstance, dt: number) -> ())?,
	onRemove: ((effect: EffectInstance) -> ())?,
	onStack: ((effect: EffectInstance) -> ())?,
}

type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> RBXScriptConnection,
	Fire: (self: Signal, ...any) -> (),
}

local function createSignal(): Signal
	local bindable = Instance.new("BindableEvent")
	return {
		Connect = function(_, fn)
			return bindable.Event:Connect(fn)
		end,
		Fire = function(_, ...)
			bindable:Fire(...)
		end,
	} :: any
end

local function buildReplicationPayload(action: string, instance: EffectInstance): { [string]: any }
	local elapsed = os.clock() - instance.startTime
	local syncedStartTime = workspace:GetServerTimeNow() - elapsed

	return {
		action = action,
		effectId = instance.id,
		stacks = instance.stacks,
		duration = instance.duration,
		startTime = syncedStartTime,
	}
end

local function replicate(action: string, entity: Instance, instance: EffectInstance)
	local player = players:GetPlayerFromCharacter(entity)

	if player ~= nil then
		statusEffectSyncEvent:FireClient(player, buildReplicationPayload(action, instance))
	end
end

local function cleanupEntity(entity: Instance)
	local effects = statusEffectManager.activeEffects[entity]

	if not effects then
		return
	end

	for id in effects do
		statusEffectManager.remove(entity, id)
	end

	statusEffectManager.activeEffects[entity] = nil
	statusEffectManager.trackedEntities = statusEffectManager.trackedEntities - 1
end

local function watchEntity(entity: Instance)
	if statusEffectManager.activeEffects[entity] then
		return
	end

	statusEffectManager.activeEffects[entity] = {}
	statusEffectManager.trackedEntities = statusEffectManager.trackedEntities + 1

	local humanoid = entity:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.Died:Once(function()
			cleanupEntity(entity)
		end)
	end

	entity.Destroying:Once(function()
		cleanupEntity(entity)
	end)
end

local function getVisualAttachmentPoint(entity: Model): BasePart | Instance
	return entity and (entity:FindFirstChild("Torso") or entity.PrimaryPart)
end

local function createVisualsForEffect(instance: EffectInstance)
	local template = statusEffectParticles:FindFirstChild(instance.id)

	if not template then
		return
	end

	local attachmentPoint = getVisualAttachmentPoint(instance.entity)
	local vfxPart = Instance.new("Part")
	vfxPart.Size = attachmentPoint.Size
	vfxPart.CanCollide = false
	vfxPart.CanQuery = false
	vfxPart.Massless = true
	vfxPart.Transparency = 1
	vfxPart.Name = instance.id .. "Part"

	local newWeld = Instance.new("Weld")
	newWeld.Part0 = vfxPart
	newWeld.Part1 = attachmentPoint
	newWeld.Parent = vfxPart

	for _, vfx in template:GetChildren() do
		vfx:Clone().Parent = vfxPart
	end

	vfxPart.Parent = attachmentPoint
	instance.data.vfx = vfxPart
end

local function killVisualsForEffect(instance: EffectInstance)
	local vfx = instance.data.vfx
	local maxLifetime = 0
	local effectsAfterParticles = {}

	if not vfx then
		return
	end

	instance.data.vfx = nil

	for _, descendant in vfx:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			maxLifetime = math.max(maxLifetime, descendant.Lifetime.Max)
		else
			table.insert(effectsAfterParticles, descendant)
		end
	end

	for _, effect in effectsAfterParticles do
		local fadeTween = nil

		if effect:IsA("Light") then
			fadeTween = tweenService:Create(effect, TweenInfo.new(maxLifetime), {
				Brightness = 0,
			})
		end

		if fadeTween then
			fadeTween:Play()
		end
	end

	task.delay(maxLifetime + vfxLifetimePadding, function()
		vfx:Destroy()
	end)
end

function statusEffectManager.preload()
	for _, child in script:GetChildren() do
		if child:IsA("ModuleScript") then
			local returned, definition = pcall(require, child)

			if returned and type(definition) == "table" and definition.id then
				statusEffectManager.registerEffect(definition :: EffectDefinition)
			end
		end
	end
end

function statusEffectManager.registerEffect(definition: EffectDefinition)
	assert(type(definition.id) == "string", "EffectDefinition.id must be a string")
	statusEffectManager.registeredEffects[definition.id] = definition
end

function statusEffectManager.init()
	statusEffectManager.preload()

	if not statusEffectManager.mainConnection then
		statusEffectManager.mainConnection = runService.Heartbeat:Connect(statusEffectManager.update)
	end
end

function statusEffectManager.apply(entity: Instance, effectId: string, overrides: { [string]: any }?): EffectInstance?
	local definition = statusEffectManager.registeredEffects[effectId]

	if not definition then
		return nil
	end

	watchEntity(entity)

	local effects = statusEffectManager.activeEffects[entity] :: { [string]: EffectInstance }
	local existing = effects[effectId]
	local config = overrides or {}
	local now = os.clock()

	if existing then
		local mode = definition.stackMode
		local max = definition.maxStacks
		local duration = config.duration or definition.defaultDuration

		if mode == "ignore" then
			return existing
		elseif mode == "refresh" then
			existing.startTime = now
			existing.duration = duration
			existing.config = config

			return existing
		elseif mode == "stack" then
			if not max or existing.stacks < max then
				existing.stacks = existing.stacks + 1
			end

			existing.startTime = now
			existing.duration = duration

			if definition.onStack then
				pcall(definition.onStack, existing)
			end

			return existing
		elseif mode == "highest" then
			local newDuration = duration
			local remaining = (existing.startTime + existing.duration) - now

			if newDuration <= remaining then
				return existing
			end

			existing.startTime = now
			existing.duration = newDuration
			existing.config = config

			return existing
		end
	end

	local instance: EffectInstance = {
		id = effectId,
		entity = entity,
		config = config,
		startTime = now,
		duration = config.duration or definition.defaultDuration,
		stacks = 1,
		nextTick = now,
		definition = definition,
		data = {},
	}

	effects[effectId] = instance

	if not existing then
		createVisualsForEffect(instance)
	end

	if definition.onApply then
		pcall(definition.onApply, instance)
	end

	statusEffectManager.effectApplied:Fire(entity, effectId, instance)
	replicate("apply", entity, instance)

	return instance
end

function statusEffectManager.remove(entity: Instance, effectId: string)
	local effects = statusEffectManager.activeEffects[entity]
	local instance = effects and effects[effectId]

	if not instance then
		return
	end

	effects[effectId] = nil
	killVisualsForEffect(instance)

	if instance.definition.onRemove then
		pcall(instance.definition.onRemove, instance)
	end

	statusEffectManager.effectRemoved:Fire(entity, effectId, instance)
	replicate("remove", entity, instance)
end

function statusEffectManager.removeAll(entity: Instance)
	local effects = statusEffectManager.activeEffects[entity]

	if not effects then
		return
	end

	for id in effects do
		statusEffectManager.remove(entity, id)
	end
end

function statusEffectManager.has(entity: Instance, effectId: string): boolean
	local effects = statusEffectManager.activeEffects[entity]
	return effects ~= nil and effects[effectId] ~= nil
end

function statusEffectManager.get(entity: Instance, effectId: string): EffectInstance?
	local effects = statusEffectManager.activeEffects[entity]
	return effects and effects[effectId]
end

function statusEffectManager.getActive(entity: Instance): { [string]: EffectInstance }
	return statusEffectManager.activeEffects[entity] or {}
end

function statusEffectManager.update(deltaTime: number)
	if statusEffectManager.trackedEntities == 0 then
		return
	end

	local now = os.clock()

	for entity, effects in statusEffectManager.activeEffects do
		for effectId, instance in effects do
			local definition = instance.definition

			if instance.duration > 0 and now - instance.startTime >= instance.duration then
				statusEffectManager.remove(entity, effectId)
				continue
			end

			if definition.onTick and definition.tickInterval and now >= instance.nextTick then
				instance.nextTick = now + definition.tickInterval
				pcall(definition.onTick, instance, deltaTime)
			end
		end
	end
end

statusEffectManager.effectApplied = createSignal()
statusEffectManager.effectRemoved = createSignal()

return statusEffectManager
