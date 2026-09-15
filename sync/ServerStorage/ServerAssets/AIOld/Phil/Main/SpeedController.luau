local replicatedStorage = game:GetService("ReplicatedStorage")

local bucketUtilities = require(replicatedStorage.SharedUtilities.BucketUtils)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

type booleanRequestTable = bucketUtilities.booleanRequestTable
type numberModifierTable = bucketUtilities.numberModifierTable

local speedController = {}
speedController.__index = speedController

function speedController:getTargetSpeed(): number
	if bucketUtilities.hasEnabledRequest(self.movementLocks) then
		return 0
	end

	return bucketUtilities.getTotalModifier(self.baseWalkSpeed, self.speedModifiers)
end

function speedController:setModifier(source: string, value: number?)
	self.speedModifiers[source] = value
end

function speedController:setLock(source: string, isLocked: boolean?)
	self.movementLocks[source] = isLocked
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

	if math.abs(currentSpeed - targetSpeed) < 0.01 then
		humanoid.WalkSpeed = targetSpeed
		return
	end

	humanoid.WalkSpeed = mathUtilities.lerp(currentSpeed, targetSpeed, self.lerpSpeed * deltaTime)
end

function speedController.new(controller: { humanoid: Humanoid, config: any, [string]: any })
	local self = setmetatable({}, speedController)

	local sharedConfig = controller.config.shared

	self.humanoid = controller.humanoid
	self.baseWalkSpeed = sharedConfig.walkSpeeds.idle
	self.lerpSpeed = sharedConfig.speedLerpRate

	self.speedModifiers = {} :: numberModifierTable
	self.movementLocks = {} :: booleanRequestTable

	return self
end

return speedController
