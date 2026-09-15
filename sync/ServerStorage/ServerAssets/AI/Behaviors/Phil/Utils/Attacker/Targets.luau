local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local sharedUtilities = replicatedStorage.SharedUtilities
local communication = replicatedStorage.Communication

local networking = require(communication.Networking)
local audioUtilities = require(sharedUtilities.AudioUtils)
local statusEffectsController = require(serverScriptService.Controllers.StatusEffects)

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local targetsController = inheriter.extend("TargetsAttack")
targetsController.__vars = {
	heavyAttackChance = 0.2,

	attackSpeedVariance = {
		min = 0.9,
		max = 1.1,
	},

	lightDamage = {
		min = 12,
		max = 14,
	},

	heavyDamage = {
		min = 16,
		max = 19,
	},
}

function targetsController:findTarget()
	return self.targeting:getNearestTarget({
		range = self.rangeConfig.attack,
		canRaycast = true,
		ignoreRagdolled = true,
	})
end

function targetsController:reset(isMain: boolean)
	if self.currentTrack and not isMain then
		self.currentTrack:Stop(0.1)
		self.currentTrack = nil
	end

	if self.connections.onSwing then
		self.connections.onSwing:Disconnect()
		self.connections.onSwing = nil
	end

	self.ai:recordActionTime("attack")
	self.behavior:setAttackEnabled(true)
end

function targetsController:onSwing(isHeavyAttack: boolean)
	self.currentTarget = self:findTarget()

	if self.currentTarget then
		local soundList = isHeavyAttack and self.heavyHitSounds or self.lightHitSounds
		local damageList = isHeavyAttack and self.__vars.heavyDamage or self.__vars.lightDamage

		self.currentTarget.humanoid:TakeDamage(math.random(damageList.min, damageList.max))

		networking.events.generic:FireClient(self.currentTarget.player, "damage")

		if isHeavyAttack and self.currentTarget.humanoid.Health > 0 then
			statusEffectsController.apply(self.currentTarget.agent, "Bleeding")
		end

		audioUtilities.playSound({
			sound = soundList[math.random(1, #soundList)],
			parent = self.rootPart,
			useAcousticSimulation = false,
		})
	end

	self:reset(true)
end

function targetsController:attemptTo()
	local canHeavyAttack = math.random() <= self.__vars.heavyAttackChance
	local trackList = canHeavyAttack and self.heavyAttackTracks or self.lightAttackTracks
	local chosenTrack = trackList[math.random(1, #trackList)]

	chosenTrack:Play(0.1)
	chosenTrack:AdjustSpeed(
		self.__vars.attackSpeedVariance.min
			+ math.random() * (self.__vars.attackSpeedVariance.max - self.__vars.attackSpeedVariance.min)
	)

	audioUtilities.playSound({
		sound = self.swingSounds[math.random(1, #self.swingSounds)],
		parent = self.rootPart,
		useAcousticSimulation = false,
	})

	self.connections.onSwing = chosenTrack:GetMarkerReachedSignal("Swing"):Once(function()
		self:onSwing(canHeavyAttack)
	end)

	self.currentTrack = chosenTrack
end

function targetsController.new(ai)
	local self = inheriter.new(ai, targetsController)

	self.attackSounds = self.sounds.Attack
	self.swingSounds = self.attackSounds.Swing:GetChildren()
	self.lightHitSounds = self.attackSounds.LightHit:GetChildren()
	self.heavyHitSounds = self.attackSounds.HeavyHit:GetChildren()

	self.lightAttackTracks = self.tracks.lightAttack
	self.heavyAttackTracks = self.tracks.heavyAttack

	return self
end

function targetsController:update(_deltaTime: number)
	self.currentTarget = self:findTarget()

	if self.currentTarget then
		self.behavior:setAttackEnabled(false)
		self:attemptTo()
	end
end

return targetsController
