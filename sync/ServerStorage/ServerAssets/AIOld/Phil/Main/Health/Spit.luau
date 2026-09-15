local spitController = {}
spitController.__index = spitController

function spitController:shouldSpit(wasBlocked: boolean): boolean
	if wasBlocked then
		self.blockStreak = (self.blockStreak or 0) + 1
	else
		self.blockStreak = 0
	end

	local combatConfig = self.healthController.combatConfig
	local sharedConfig = self.healthController.sharedConfig

	if self.blockStreak >= combatConfig.spitBlockStreakThreshold then
		return true
	end

	local targetsInRange = self.mainController.targeting:getAllTargetsInRange({
		range = sharedConfig.ranges.run,
		canRaycast = false,
	})

	if #targetsInRange >= combatConfig.spitCrowdSizeThreshold then
		return true
	end

	return false
end

function spitController:selectTarget()
	local sharedConfig = self.healthController.sharedConfig

	local spitRange = sharedConfig.ranges.spit or sharedConfig.ranges.run
	local meleeRange = sharedConfig.ranges.push or sharedConfig.ranges.attack
	meleeRange = meleeRange * 2

	local pool = {}
	local candidates = self.mainController.targeting:getAllTargetsInRange({
		range = spitRange,
		canRaycast = true,
	})

	for _, target in candidates do
		local distance = vector.magnitude(target.root.Position - self.mainController.rootPart.Position)

		if distance > meleeRange then
			table.insert(pool, target)
		end
	end

	if #pool == 0 then
		return nil
	end

	local now = os.clock()
	local bestTarget, bestScore = nil, -math.huge

	for _, target in pool do
		local lastSpit = self.spitHistory[target.agent] or -math.huge
		local score = now - lastSpit

		if score > bestScore then
			bestScore = score
			bestTarget = target
		end
	end

	return bestTarget
end

function spitController:reset()
	self.blockStreak = 0
end

function spitController.new(healthController)
	local self = setmetatable({}, spitController)

	self.healthController = healthController
	self.mainController = self.healthController.controller
	self.cooldownUntil = 0
	self.blockStreak = 0
	self.spitHistory = {}

	return self
end

function spitController:attemptFromDamage(wasBlocked: boolean, isHeavyAttack: boolean): boolean
	if isHeavyAttack then
		return false
	end

	if wasBlocked then
		self.blockStreak = (self.blockStreak or 0) + 1
	else
		self.blockStreak = 0
	end

	if self.blockStreak < self.healthController.combatConfig.spitBlockStreakThreshold then
		return false
	end

	return self:attempt()
end

function spitController:attemptFromCrowdSize(): boolean
	local sharedConfig = self.healthController.sharedConfig
	local combatConfig = self.healthController.combatConfig

	local targetsInRange = self.mainController.targeting:getAllTargetsInRange({
		range = sharedConfig.ranges.run,
		canRaycast = false,
	})

	if #targetsInRange < combatConfig.spitCrowdSizeThreshold then
		return false
	end

	return self:attempt()
end

function spitController:attempt(): boolean
	local now = os.clock()

	if not self:canAttempt(now) then
		return false
	end

	local target = self:selectTarget()
	if not target then
		return false
	end

	self.blockStreak = 0
	self.cooldownUntil = now + self.healthController.combatConfig.spitCooldownSeconds
	self:fire(target)

	return true
end

function spitController:canAttempt(now: number): boolean
	return now >= self.cooldownUntil and self.mainController:getFlag("hasEnteredCrowdControl")
end

function spitController:fire(target)
	self.currentTarget = target
	self.spitHistory[target.agent] = os.clock()

	self.mainController.stateMachine:change(self.mainController.states.Spitting)
end

return spitController
