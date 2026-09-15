local mathUtilities = {}

mathUtilities.axisMap = {
	[1] = "X",
	[2] = "Y",
	[3] = "Z",
}

function mathUtilities.lerp(currentValue: any, targetValue: any, alpha: number): any
	local clampedAlpha = math.clamp(alpha, 0, 1)
	return currentValue + (targetValue - currentValue) * clampedAlpha
end

function mathUtilities.exponentialLerp(
	currentValue: number,
	targetValue: number,
	speed: number,
	deltaTime: number
): number
	local alpha = 1 - math.exp(-speed * deltaTime)
	return mathUtilities.lerp(currentValue, targetValue, alpha)
end

function mathUtilities.normalizeAngle(angleRadians: number): number
	return (angleRadians + math.pi) % (2 * math.pi) - math.pi
end

function mathUtilities.planarDistance(positionA: Vector3, positionB: Vector3): number
	local deltaX = positionA.X - positionB.X
	local deltaZ = positionA.Z - positionB.Z

	return math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
end

function mathUtilities.remapClamped(
	value: number,
	inputMinimum: number,
	inputMaximum: number,
	outputMinimum: number,
	outputMaximum: number
): number
	if inputMaximum == inputMinimum then
		return outputMinimum
	end

	local normalizedAlpha = (value - inputMinimum) / (inputMaximum - inputMinimum)
	local clampedAlpha = math.clamp(normalizedAlpha, 0, 1)

	return outputMinimum + (outputMaximum - outputMinimum) * clampedAlpha
end

function mathUtilities.exponentialAlpha(speed: number, deltaTime: number): number
	return 1 - math.exp(-speed * deltaTime)
end

function mathUtilities.getLongestAxis(targetVector: Vector3): number
	local absoluteValues = {
		math.abs(targetVector.X),
		math.abs(targetVector.Y),
		math.abs(targetVector.Z),
	}

	local longestIndex = 1
	local longestValue = absoluteValues[1]

	for index = 2, 3 do
		if absoluteValues[index] > longestValue then
			longestIndex = index
			longestValue = absoluteValues[index]
		end
	end

	return longestIndex
end

function mathUtilities.getCircularOffset(radiusStuds: number): Vector3
	radiusStuds = radiusStuds or 30

	local angleRadians = math.random() * math.pi * 2
	return Vector3.new(math.sin(angleRadians) * radiusStuds, 0, math.cos(angleRadians) * radiusStuds)
end

function mathUtilities.getCameraShake(intensity: number, deltaTime: number): CFrame
	intensity = intensity or 1
	local frameScale = deltaTime * 60
	return CFrame.Angles(
		(math.random() - 0.5) * intensity * frameScale,
		(math.random() - 0.5) * intensity * frameScale,
		(math.random() - 0.5) * intensity * frameScale
	)
end

function mathUtilities.findOrbitPath(origin: Vector3, target: Vector3, tolerance: number, orbitDirection: number)
	local offset = origin - target
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = vector.magnitude(flat)

	local directionFrom = flat.Unit
	local tangent = Vector3.new(-directionFrom.Z, 0, directionFrom.X) * orbitDirection
	local correctionOffset = -directionFrom * (distance - tolerance) * 0.15
	local moveDirection = (tangent + correctionOffset).Unit

	return origin + moveDirection * 12
end

function mathUtilities.angleToBehindTarget(origin: Vector3, target: Vector3, targetLookVector: Vector3): number
	local offset = origin - target
	local flat = Vector3.new(offset.X, 0, offset.Z)

	if vector.magnitude(flat) == 0 then
		return 0
	end

	local directionFrom = flat.Unit
	local flatLook = Vector3.new(targetLookVector.X, 0, targetLookVector.Z)

	if vector.magnitude(flatLook) == 0 then
		return 0
	end

	local behindDir = -flatLook.Unit
	local currentAngle = math.atan2(directionFrom.Z, directionFrom.X)
	local behindAngle = math.atan2(behindDir.Z, behindDir.X)

	return math.atan2(math.sin(behindAngle - currentAngle), math.cos(behindAngle - currentAngle))
end

function mathUtilities.convertToUSD(value)
	local isNegative = value < 0
	value = math.abs(value)

	local dollars = value // 100
	local remainingCents = value % 100

	local dollarString = tostring(dollars)
	local newFormat = dollarString:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	newFormat = newFormat:gsub("^,", "")

	local result = string.format("%s.%02d", newFormat, remainingCents)
	return isNegative and ("-" .. result) or result
end

return mathUtilities
