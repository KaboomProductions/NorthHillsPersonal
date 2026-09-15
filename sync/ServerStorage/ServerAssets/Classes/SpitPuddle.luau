local spitPuddleController = {}
spitPuddleController.__index = spitPuddleController
spitPuddleController.__vars = {
	radius = 13,
	tickRate = 0.5,
}

local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local serverScriptService = game:GetService("ServerScriptService")

local serverAssets = serverStorage.ServerAssets
local serverEffects = serverAssets.Effects
local puddlePrefabs = serverEffects.SpitPuddles

local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local statusEffectsController = require(serverScriptService.Controllers.StatusEffects)

local sharedAssets = replicatedStorage.SharedAssets
local sharedEffects = sharedAssets.Effects
local sounds = sharedEffects.Sounds
local particles = sharedEffects.Particles

local spitSplashParticles = particles.SpitSplashes
local projectileSounds = sounds.Projectiles
local spitProjectileSounds = projectileSounds.Spit

local gameValues = replicatedStorage.Values
local roundCycleValues = gameValues.RoundCycle
local climateState = roundCycleValues.ClimateState

local components = workspace.Components
local characters = components.Characters

local ignore = workspace.Ignore
local other = ignore.Other

local alignParams = RaycastParams.new()
alignParams.FilterDescendantsInstances = { ignore, components }
alignParams.FilterType = Enum.RaycastFilterType.Exclude

local damageParams = OverlapParams.new()
damageParams.FilterDescendantsInstances = { characters }
damageParams.FilterType = Enum.RaycastFilterType.Include
damageParams.MaxParts = 32

function spitPuddleController:preload()
	self.isDryState = climateState.Value == "Dry"

	local newPuddle = self.isDryState and puddlePrefabs.Fire or puddlePrefabs.Acid
	newPuddle = newPuddle:Clone()
	newPuddle.Parent = other

	local newSplash = self.isDryState and spitSplashParticles.Fire or spitSplashParticles.Acid
	newSplash = newSplash:Clone()
	newSplash.Parent = newPuddle

	for _, particle in newSplash:GetDescendants() do
		if not particle:IsA("ParticleEmitter") then
			continue
		end

		particle:Emit(particle:GetAttribute("EmitCount") or 30)
	end

	local raycastResult = workspace:Raycast(self.origin + Vector3.yAxis * 1, Vector3.yAxis * -1000, alignParams)

	if raycastResult and raycastResult.Position then
		newPuddle.Position = raycastResult.Position
	else
		self:destroy()
		return
	end

	audioUtilities.playSound({
		sound = spitProjectileSounds["Acid Puddle Loop"],
		parent = newPuddle,
	})

	self.puddle = newPuddle
end

function spitPuddleController:startLightFlicker()
	local lights = {}

	for _, instance in self.puddleDescendants do
		if not instance:IsA("Light") then
			continue
		end

		table.insert(lights, {
			light = instance,
			baseBrightness = instance.Brightness,
			seed = math.random() * 1000,
		})
	end

	if #lights == 0 then
		return
	end

	task.spawn(function()
		while self.active do
			local now = os.clock()

			for _, entry in lights do
				local noise = math.noise(now * 6, entry.seed)
				entry.light.Brightness = entry.baseBrightness * (0.7 + noise * 0.6)
			end

			task.wait(0.05)
		end
	end)
end

function spitPuddleController:damageTick()
	if not self.active or not self.puddle then
		return
	end

	local hitParts = workspace:GetPartBoundsInRadius(self.puddle.Position, self.__vars.radius, damageParams)
	local damagedCharacters = {}

	for _, part in hitParts do
		local character = part:FindFirstAncestorOfClass("Model")
		if not character or damagedCharacters[character] then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		damagedCharacters[character] = true
		statusEffectsController.apply(character, self.isDryState and "Burning" or "Corroding")
	end

	task.delay(self.__vars.tickRate, function()
		self:damageTick()
	end)
end

function spitPuddleController:initialize()
	self:preload()

	if self.puddle ~= nil then
		self.puddleDescendants = self.puddle:GetDescendants()
		self.currentLifetime = 0
		self.cooldown = self.cooldown or 10
		self.active = true

		self:damageTick()
		self:startLightFlicker()

		task.delay(self.cooldown, function()
			self.active = false

			for _, instance: ParticleEmitter | Light | Sound in self.puddleDescendants do
				local fadeTween = nil

				if instance:IsA("ParticleEmitter") then
					if instance.Lifetime.Max > self.currentLifetime then
						self.currentLifetime = instance.Lifetime.Max
					end

					instance.Enabled = false
				elseif instance:IsA("Light") then
					fadeTween = tweenService:Create(instance, TweenInfo.new(2), {
						Brightness = 0,
					})
				elseif instance:IsA("Sound") then
					fadeTween = tweenService:Create(instance, TweenInfo.new(2), {
						Volume = 0,
					})
				end

				if fadeTween then
					fadeTween:Play()
				end
			end

			task.delay(self.currentLifetime, function()
				self.puddle:Destroy()
			end)
		end)
	end
end

function spitPuddleController.new(origin)
	local self = setmetatable({}, spitPuddleController)
	self.origin = origin
	self.__vars = table.clone(spitPuddleController.__vars)
	self.active = false

	task.spawn(self.initialize, self)

	return self
end

function spitPuddleController:destroy()
	self.active = false

	if self.puddle then
		self.puddle:Destroy()
	end

	setmetatable(self, nil)
end

return spitPuddleController
