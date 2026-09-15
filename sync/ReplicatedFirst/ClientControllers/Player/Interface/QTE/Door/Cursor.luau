local userInputService = game:GetService("UserInputService")

local doorConfig = require(script.Parent.Config)

local cursorHandler = {}

function cursorHandler.applyMouseInput(currentPosition: Vector2, containerSize: Vector2, inputDelta: Vector2?): Vector2
	local resolvedDelta = inputDelta or userInputService:GetMouseDelta()

	if resolvedDelta.Magnitude <= 0 then
		return currentPosition
	end

	local normalizedDelta = Vector2.new(resolvedDelta.X / containerSize.X, resolvedDelta.Y / containerSize.Y)
		* doorConfig.mouseSensitivity

	return currentPosition + normalizedDelta
end

function cursorHandler.applyDrift(currentPosition: Vector2, currentTime: number, deltaTime: number): Vector2
	local driftX = math.noise(currentTime * doorConfig.driftSpeed, 0.5) * doorConfig.driftIntensity * deltaTime
	local driftY = math.noise(0.5, currentTime * doorConfig.driftSpeed) * doorConfig.driftIntensity * deltaTime

	return currentPosition + Vector2.new(driftX, driftY)
end

function cursorHandler.clamp(currentPosition: Vector2): Vector2
	if currentPosition.Magnitude > doorConfig.maxOffset then
		return currentPosition.Unit * doorConfig.maxOffset
	end

	return currentPosition
end

function cursorHandler.computeVisualOffset(currentTime: number, jitterMultiplier: number?): Vector2
	local jitterScale = jitterMultiplier or 1
	local jitterOffset = Vector2.new(
		math.noise(currentTime * doorConfig.jitterSpeed, 1.7) * doorConfig.jitterIntensity * jitterScale,
		math.noise(3.1, currentTime * doorConfig.jitterSpeed) * doorConfig.jitterIntensity * jitterScale
	)

	local swayOffset = Vector2.new(
		math.noise(currentTime * doorConfig.swaySpeed, 7.3) * doorConfig.swayIntensity,
		math.noise(11.9, currentTime * doorConfig.swaySpeed) * doorConfig.swayIntensity
	)

	return jitterOffset + swayOffset
end

function cursorHandler.computeCircleCenter(circle: GuiObject, container: GuiObject): Vector2
	local circleAbsolutePosition = circle.AbsolutePosition
	local circleAbsoluteSize = circle.AbsoluteSize
	local containerAbsolutePosition = container.AbsolutePosition
	local containerAbsoluteSize = container.AbsoluteSize

	local centerX = (circleAbsolutePosition.X + circleAbsoluteSize.X * 0.5 - containerAbsolutePosition.X)
		/ containerAbsoluteSize.X
	local centerY = (circleAbsolutePosition.Y + circleAbsoluteSize.Y * 0.5 - containerAbsolutePosition.Y)
		/ containerAbsoluteSize.Y

	return Vector2.new(centerX, centerY)
end

return cursorHandler
