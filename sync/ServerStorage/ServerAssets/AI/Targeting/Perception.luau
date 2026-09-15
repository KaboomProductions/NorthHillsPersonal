local perceptionController = {}

function perceptionController.isTargetVisible(self, target, range: number?): boolean
	if not target then
		return false
	end

	local effectiveRange = range or 500
	local originPart = self.rootPart
	local targetPart = target.root

	local direction = targetPart.Position - originPart.Position
	if vector.magnitude(direction) > effectiveRange then
		return false
	end

	local raycastResult = workspace:Raycast(originPart.Position, direction, self.raycastParams)
	return raycastResult ~= nil and raycastResult.Instance:IsDescendantOf(target.agent)
end

function perceptionController.isTargetInFieldOfView(self, target, fieldOfView: number?): boolean
	if not target then
		return false
	end

	if not fieldOfView then
		return true
	end

	local originPart = self.behavior.headBone or self.behavior.head
	local targetPart = target.root

	if not originPart then
		return true
	end

	local offset = targetPart.Position - originPart.WorldPosition
	local distanceToTarget = vector.magnitude(offset)

	if distanceToTarget <= 0.01 then
		return true
	end

	local directionToTarget = offset / distanceToTarget
	local lookVector = originPart.WorldCFrame.LookVector
	local dot = vector.dot(directionToTarget, lookVector)
	local fovCosThreshold = math.cos(math.rad(fieldOfView / 2))

	return dot >= fovCosThreshold
end

function perceptionController.isTargetTurnedAway(self, target): boolean
	if not target then
		return false
	end

	local originPart = self.rootPart
	local targetPart = target.root

	local directionToTarget = (targetPart.Position - originPart.Position).Unit
	local dotProduct = targetPart.CFrame.LookVector:Dot(directionToTarget)

	return dotProduct > 0.0
end

return perceptionController
