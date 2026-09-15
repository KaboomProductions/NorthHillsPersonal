local replicatedStorage = game:GetService("ReplicatedStorage")

local bucketUtilities = require(replicatedStorage.SharedUtilities.BucketUtils)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

type booleanRequestTable = bucketUtilities.booleanRequestTable
type numberModifierTable = bucketUtilities.numberModifierTable

local speedController = {}
speedController.__index = speedController
speedController.__vars = {
	lerpSpeed = 8,
	snapThreshold = 0.1,
}

function speedController:getTargetSpeed(): number
	if bucketUtilities.hasEnabledRequest(self.movementLocks) then
		return 0
	end

	return bucketUtilities.getTotalModifier(self.walkSpeedConfig.walk, self.speedModifiers)
end

function speedController:setModifier(source: string, value: number?)
	self.speedModifiers[source] = value
end

function speedController:setLock(source: string, isLocked: boolean?)
	self.movementLocks[source] = isLocked
end

function speedController:getLock(source: string): boolean?
	return self.movementLocks[source]
end

function speedController:clearModifier(source: string)
	self.speedModifiers[source] = nil
end

function speedController:clearLock(source: string)
	self.movementLocks[source] = nil
end

function speedController:clearAll()
	table.clear(self.speedModifiers)
	table.clear(self.movementLocks)
end

function speedController:isLocked(): boolean
	return bucketUtilities.hasEnabledRequest(self.movementLocks)
end

function speedController:update(deltaTime: number)
	if self:isLocked() then
		return
	end

	local humanoid = self.humanoid
	local targetSpeed = self:getTargetSpeed()
	local currentSpeed = humanoid.WalkSpeed

	if math.abs(currentSpeed - targetSpeed) < self.__vars.snapThreshold then
		humanoid.WalkSpeed = targetSpeed
		return
	end

	humanoid.WalkSpeed = mathUtilities.lerp(currentSpeed, targetSpeed, self.__vars.lerpSpeed * deltaTime)
end

function speedController.new(ai)
	local self = setmetatable({}, speedController)

	self.humanoid = ai.humanoid
	self.walkSpeedConfig = ai.walkSpeedConfig

	self.speedModifiers = {} :: numberModifierTable
	self.movementLocks = {} :: booleanRequestTable

	return self
end

function speedController:destroy()
	setmetatable(self, nil)
end

return speedController
