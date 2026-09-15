local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedUtilities = replicatedStorage.SharedUtilities
local mathUtilities = require(sharedUtilities.MathUtils)

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local stalkingController = inheriter.extend("Stalking")
stalkingController.__vars = {
	maxTargetStareTime = 1.5,
	stareDecayRate = 2,

	rerollAngle = 60,

	circleClosingInterval = 5,
	circleClosingStep = 2,

	attemptToStandoffRange = 12.5,
	instantChaseRange = 25,

	aggroGainRateNear = 30,
	aggroGainRateFar = 8,
	aggroDecayRate = 15,
}

function stalkingController:enter()
	self.speed:clearAll()
	self.speed:setLock("Stalking", true)
end

function stalkingController:exit()
	self.behavior:toggleIKControl()
	self.behavior:toggleAlignOrientation()
	self.ai:recordActionFlag("Sneaking", nil)
	self.speed:clearLock("Stalking")
end

function stalkingController.new(ai)
	local self = inheriter.new(ai, stalkingController)

	self.currentRange = self.rangeConfig.circling.max
	self.orbitDirection = 1
	self.stareTimer = 0
	self.aggroTimer = 0
	self.lastCloseAttempt = 0
	self.instantStareRange = self.currentRange / 1.5
	self.backpedalRange = self.currentRange / 1.2

	return self
end

function stalkingController:getStareTime(distance)
	return math.clamp((distance - self.instantStareRange) / (self.rangeConfig.stalk - self.instantStareRange), 0, 1)
		* self.__vars.maxTargetStareTime
end

function stalkingController:updateAggro(deltaTime: number)
	if self.isEyeContact and self.currentTarget then
		local nearRange = self.__vars.instantChaseRange
		local proximity = 1
			- math.clamp((self.currentTarget.distance - nearRange) / (self.rangeConfig.chase - nearRange), 0, 1)
		local gainRate = self.__vars.aggroGainRateFar
			+ (self.__vars.aggroGainRateNear - self.__vars.aggroGainRateFar) * proximity

		self.aggroTimer = math.min(100, self.aggroTimer + gainRate * deltaTime)
	else
		self.aggroTimer = math.max(0, self.aggroTimer - self.__vars.aggroDecayRate * deltaTime)
	end
end

function stalkingController:update(deltaTime: number)
	local now = os.clock()
	local newTarget = self.targeting:getNearestTarget({
		range = self.rangeConfig.stalk,
	})

	if not self.currentTarget then
		self.currentTarget = newTarget
	end

	self.currentTarget = (
		newTarget ~= self.currentTarget and self.perception.isTargetInFieldOfView(self, newTarget, 90)
	)
			and newTarget
		or self.currentTarget

	self.isVisible = self.perception.isTargetVisible(self.targeting, self.currentTarget)
	self.isTurnedAway = self.perception.isTargetTurnedAway(self.targeting, self.currentTarget)
	self.isEyeContact = (not self.isTurnedAway and self.isVisible) and true or false

	self:updateAggro(deltaTime)

	if self.isEyeContact then
		self.stareTimer = self.stareTimer + deltaTime

		if self.isStaring or self.stareTimer >= self:getStareTime(self.currentTarget.distance) then
			self.isStaring = true
		end
	else
		self.stareTimer = math.max(0, self.stareTimer - self.__vars.stareDecayRate * deltaTime)

		if self.isStaring then
			self.isStaring = false
			self.orbitDirection = self.orbitDirection * -1
		end
	end

	if now - self.lastCloseAttempt >= self.__vars.circleClosingInterval then
		self.lastCloseAttempt = now
		self.currentRange = math.max(self.rangeConfig.circling.min, self.currentRange - self.__vars.circleClosingStep)
		self.instantStareRange = self.currentRange / 1.5
		self.backpedalRange = self.currentRange / 1.2
	end

	if self.currentTarget then
		if self.lastNonContactRange and self.isStaring then
			if self.lastNonContactRange > self.__vars.instantChaseRange then
				if self.aggroTimer >= 100 then
					self.ai:setState("Chasing")
					return
				end
			elseif
				self.lastNonContactRange > self.__vars.attemptToStandoffRange
				and self.lastNonContactRange <= self.__vars.instantChaseRange
			then
				self.ai:setState("Chasing")
				return
			elseif self.lastNonContactRange <= self.__vars.attemptToStandoffRange then
				print("standoff")
			end
		else
			self.lastNonContactRange = self.currentTarget.distance
		end

		if not self.isStaring then
			local isSneaking = self.currentRange <= self.rangeConfig.circling.min
			local angleToBehind = mathUtilities.angleToBehindTarget(
				self.rootPart.Position,
				self.currentTarget.root.Position,
				self.currentTarget.root.CFrame.LookVector
			)

			if math.abs(angleToBehind) > math.rad(self.__vars.rerollAngle) then
				self.orbitDirection = angleToBehind > 0 and 1 or -1
			end

			self.ai:traverseTo(
				not isSneaking
						and mathUtilities.findOrbitPath(
							self.rootPart.Position,
							self.currentTarget.root.Position,
							self.currentRange,
							self.orbitDirection
						)
					or self.currentTarget.root.Position
			)

			self.humanoid.WalkSpeed = isSneaking and self.walkSpeedConfig.sneak or self.walkSpeedConfig.walk

			self.ai:recordActionFlag("Sneaking", isSneaking)
		else
			local awayFromTarget = self.rootPart.Position - self.currentTarget.root.Position
			local backupDirection = vector.magnitude(awayFromTarget) > 0.01 and awayFromTarget.Unit
				or self.rootPart.CFrame.LookVector

			self.ai:traverseTo(self.currentTarget.root.Position + backupDirection * self.currentRange)

			self.humanoid.WalkSpeed = self.currentTarget.distance <= self.backpedalRange and self.walkSpeedConfig.run
				or self.walkSpeedConfig.walk

			self.ai:recordActionFlag("Sneaking", false)
		end

		self.behavior:toggleAlignOrientation(self.currentTarget.root, self.isStaring)
		self.behavior:toggleIKControl(self.currentTarget.root, true)

		return
	end

	self.ai:setState("Wandering")
end

return stalkingController
