local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local effects = sharedAssets.Effects
local particleEffects = effects.Particles
local crowParticles = particleEffects.Crows:GetChildren()

local crowsTriggerController = {}
crowsTriggerController.__index = crowsTriggerController

function crowsTriggerController:fetchEmitCount(): number
	local emitCountRange = self.triggerConfig.particleEmitCount
	return math.random(emitCountRange.min, emitCountRange.max)
end

function crowsTriggerController:emit()
	for _, emitter in self.emitters do
		if not emitter:IsA("ParticleEmitter") then
			continue
		end

		emitter:Emit(self:fetchEmitCount())
	end
end

function crowsTriggerController:activate()
	self.isOnCooldown = true
	self:emit()
end

function crowsTriggerController:refresh()
	self.isOnCooldown = false
end

function crowsTriggerController:preload()
	local trigger = self.trigger
	local emitterInstance = trigger.Emitter

	self.timeWithoutAgents = 0
	self.triggerConfig = require(trigger.Config)
	self.origin = trigger.Origin

	for _, particle in pairs(crowParticles) do
		particle:Clone().Parent = emitterInstance
	end

	self.emitters = emitterInstance:GetChildren()
end

function crowsTriggerController:init()
	self:preload()

	local triggerConfig = self.triggerConfig
	local checkIntervalSeconds = 0.5

	task.spawn(function()
		while self.isActive do
			task.wait(checkIntervalSeconds)

			if not self.isActive then
				break
			end

			if self.originator.checkForAgents(self.origin, triggerConfig) then
				self.timeWithoutAgents = os.clock()

				if not self.isOnCooldown then
					self:activate()
				end
			end

			if os.clock() - self.timeWithoutAgents >= triggerConfig.maxCooldownTime and self.isOnCooldown then
				self:refresh()
			end
		end
	end)
end

function crowsTriggerController.new(triggerInstance: Folder, originator: any)
	local self = setmetatable({}, crowsTriggerController)

	self.trigger = triggerInstance
	self.originator = originator
	self.isOnCooldown = false
	self.isActive = true

	task.defer(self.init, self)

	return self
end

function crowsTriggerController:destroy()
	self.isActive = false
	table.clear(self)
	setmetatable(self, nil)
end

return crowsTriggerController
