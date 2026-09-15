local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local scoreTrackerController = require(serverAssets.ScoreTracker)

local healthController = {}
healthController.__index = healthController

type DamageInfo = {
	eventType: string,
	isHeavyAttack: boolean,
	player: Player,
	damage: number,
	cframe: CFrame,
}

type DamageLogEntry = {
	time: number,
	damage: number,
}

function healthController:preload()
	self.stunController = require(script.Stun).new(self)
	self.crowdControlController = require(script.CrowdControl).new(self)
	self.spitController = require(script.Spit).new(self)
end

function healthController:clearDamageLog(now: number)
	if self.lastLoggedDamageAt and (now - self.lastLoggedDamageAt) > self.combatConfig.damageLogResetSeconds then
		table.clear(self.damageLog)
	end
end

function healthController:logDamage(damageInfo: DamageInfo)
	local now = os.clock()

	self:clearDamageLog(now)
	self.lastLoggedDamageAt = now

	table.insert(self.damageLog, {
		time = now,
		damage = damageInfo.damage,
	})
end

function healthController:computeTotalDamage()
	local totalDamage = 0

	self:clearDamageLog(os.clock())

	for _, entry: DamageLogEntry in self.damageLog do
		totalDamage = totalDamage + entry.damage
	end

	self.currentDamageInSuccession = totalDamage
end

function healthController:onDamageReceived(damageInfo: DamageInfo): string?
	self.lastDamageResult = "regular"

	if self.agent:GetAttribute("CrowdControl") then
		self.crowdControlController.startedAt = os.clock()
	end

	if not self.controller:isMidAction() and self.agent:GetAttribute("CanStun") then
		self.lastObjectSpace = self.rootPart.CFrame:PointToObjectSpace(damageInfo.cframe.Position)
		self.hitDirection = self.lastObjectSpace.X
		self.trackIndex = ((self.hitDirection > 0.5 and 2) or (self.hitDirection < -0.5 and 3)) or 1

		self.controller.attacker.targetsController:cancelAttack(false)
		self.controller:setCanAttack(false)

		if self.stunController.currentTrack then
			self.stunController.currentTrack:Stop(0.25)
			self.stunController.currentTrack = nil
		end

		if damageInfo.eventType == "melee" then
			self.wasBlock = math.random() > 0.5 or self.agent:GetAttribute("CrowdControl")

			local now = os.clock()
			local onCooldown = self.heavyAttackCooldownUntil and now < self.heavyAttackCooldownUntil
			local isHeavyAttack = damageInfo.isHeavyAttack

			if onCooldown or isHeavyAttack then
				self.heavyAttackCooldownUntil = now + self.combatConfig.heavyStunCooldownSeconds
			end

			if onCooldown then
				isHeavyAttack = false
			end

			self.lastDamageResult = isHeavyAttack and "critical" or self.lastDamageResult

			if self.wasBlock then
				self.lastDamageResult = "blocked"
				self.stunController:triggerBlock()
			else
				self.stunController:triggerStun(isHeavyAttack)
			end

			self.spitController:attemptFromDamage(self.wasBlock, isHeavyAttack)
		end

		if not self.wasBlock then
			scoreTrackerController.updateReward(damageInfo.player, "damageDealt", damageInfo.damage)
		end

		self.crowdControlController:attemptTo()
	end

	if self.wasBlock then
		damageInfo.damage = 0
	else
		self:logDamage(damageInfo)
		self:computeTotalDamage()
	end

	return self.lastDamageResult
end

function healthController:init()
	self:preload()

	self.takeDamageFunction.OnInvoke = function(damageInfo: DamageInfo)
		return self:onDamageReceived(damageInfo)
	end
end

function healthController.new(parentInstance: any)
	local self = setmetatable({}, healthController)

	self.controller = parentInstance
	self.agent = self.controller.agent
	self.humanoid = self.controller.humanoid
	self.rootPart = self.controller.rootPart
	self.takeDamageFunction = self.agent.TakeDamage

	self.sounds = self.controller.sounds
	self.tracks = self.controller.tracks

	self.heavyAttackCooldownUntil = nil
	self.currentDamageInSuccession = 0

	self.sharedConfig = self.controller.config.shared
	self.combatConfig = self.controller.config.combat
	self.damageLog = {}
	self.connections = {}
	self.controllers = {}

	task.spawn(self.init, self)

	return self
end

function healthController:update(deltaTime)
	self.crowdControlController:update(deltaTime)

	if self.agent:GetAttribute("CrowdControl") then
		self.spitController:attemptFromCrowdSize()
	end
end

function healthController:destroy()
	setmetatable(self, nil)
end

return healthController
