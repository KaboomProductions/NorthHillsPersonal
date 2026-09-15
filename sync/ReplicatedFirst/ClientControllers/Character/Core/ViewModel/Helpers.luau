local replicatedStorage = game:GetService("ReplicatedStorage")

local attributeConstants = require(replicatedStorage.SharedAssets.Attributes)

local helpers = {}
helpers.characterAttributes = attributeConstants.character

function helpers.calculateFrameAlpha(alpha: number, deltaTime: number, frameRate: number): number
	return math.clamp(alpha * deltaTime * frameRate, 0, 1)
end

function helpers.isFirstPerson(character: Model): boolean
	return character:GetAttribute(helpers.characterAttributes.firstPerson) == true
end

local function isGripPartForTarget(part: BasePart?, targetInstance: Instance?): boolean
	if part == nil or targetInstance == nil then
		return false
	end

	return part == targetInstance or part:IsDescendantOf(targetInstance)
end

local function isSupportedGripJoint(descendant: Instance): boolean
	return descendant:IsA("Weld") or descendant:IsA("Motor6D")
end

function helpers.findGripJoint(character: Model, gripName: string, targetInstance: Instance?): (Weld | Motor6D)?
	local fallbackGripJoint = nil

	for _, descendant in ipairs(character:GetDescendants()) do
		if not isSupportedGripJoint(descendant) then
			continue
		end

		local joint = descendant :: Weld | Motor6D
		local isTargetJoint = isGripPartForTarget(joint.Part0, targetInstance)
			or isGripPartForTarget(joint.Part1, targetInstance)

		if descendant.Name == gripName then
			if
				isTargetJoint
				or targetInstance == nil
			then
				return joint
			end

			if fallbackGripJoint == nil and targetInstance == nil then
				fallbackGripJoint = joint
			end
		end

		if fallbackGripJoint == nil and isTargetJoint then
			fallbackGripJoint = joint
		end
	end

	return fallbackGripJoint
end

function helpers.isRecentMovement(lastMoveTime: number, recentMovementDurationSeconds: number): boolean
	return (time() - lastMoveTime) <= recentMovementDurationSeconds
end

function helpers.getRotationDifference(currentCFrame: CFrame, targetCFrame: CFrame): number
	local relativeCFrame = currentCFrame:ToObjectSpace(targetCFrame)
	local xRotation, yRotation, zRotation = relativeCFrame:ToEulerAnglesXYZ()

	return math.max(math.abs(xRotation), math.abs(yRotation), math.abs(zRotation))
end

function helpers.isCFrameNear(
	currentCFrame: CFrame,
	targetCFrame: CFrame,
	positionEpsilon: number,
	angleEpsilonRadians: number
): boolean
	local positionDifference = (currentCFrame.Position - targetCFrame.Position).Magnitude
	local rotationDifference =
		helpers.getRotationDifference(currentCFrame - currentCFrame.Position, targetCFrame - targetCFrame.Position)

	return positionDifference <= positionEpsilon and rotationDifference <= angleEpsilonRadians
end

return helpers
