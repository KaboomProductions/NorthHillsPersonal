local doorConfig = require(script.Parent.Config)

--// Tier 1 (outer bars 1, 4): drain as progress drops from 1.0 to 0.5
--// Tier 2 (center bars 2, 3): drain as progress drops from 0.5 to 0.0
local tierMap = {
	[1] = 1,
	[2] = 2,
	[3] = 2,
	[4] = 1,
}

local gradientEpsilon = 0.001

local fillBarHandler = {}

function fillBarHandler.setupGradients(barContainer: GuiObject): ({ GuiObject }, { UIGradient })
	local fillBars = {}
	local fillBarGradients = {}

	for index = 1, doorConfig.fillSegments do
		local fillBar = barContainer:FindFirstChild("fillbar" .. index)
		fillBars[index] = fillBar

		if not fillBar then
			continue
		end

		local gradient = fillBar:FindFirstChildOfClass("UIGradient")
		if not gradient then
			gradient = Instance.new("UIGradient")
			gradient.Parent = fillBar
		end

		if index <= 2 then
			gradient.Rotation = 180
		else
			gradient.Rotation = 0
		end

		fillBarGradients[index] = gradient
	end

	return fillBars, fillBarGradients
end

function fillBarHandler.updateProgress(
	fillProgress: number,
	cursorDistance: number,
	deltaTime: number,
	hexagonThreshold: number?
): number
	local resolvedThreshold: number = hexagonThreshold or doorConfig.hexagonThreshold

	if cursorDistance <= resolvedThreshold then
		local fillAlpha = 1 - (cursorDistance / resolvedThreshold)
		local fillSpeed = doorConfig.minFillSpeed + (doorConfig.maxFillSpeed - doorConfig.minFillSpeed) * fillAlpha
		return math.min(fillProgress + fillSpeed * deltaTime, 1)
	end

	return math.max(fillProgress - doorConfig.drainSpeed * deltaTime, 0)
end

function fillBarHandler.smoothDisplayProgress(
	displayedProgress: number,
	targetProgress: number,
	deltaTime: number
): number
	local smoothAlpha = 1 - math.exp(-doorConfig.barSmoothSpeed * deltaTime)
	return displayedProgress + (targetProgress - displayedProgress) * smoothAlpha
end

function fillBarHandler.applyKickDrain(fillProgress: number, kickDistance: number): number
	local kickStrength = kickDistance / doorConfig.kickDistance
	return math.max(fillProgress - kickStrength * doorConfig.kickDrain, 0)
end

function fillBarHandler.renderGradients(fillBarGradients: { UIGradient }, displayedProgress: number)
	for index = 1, doorConfig.fillSegments do
		local gradient = fillBarGradients[index]
		if not gradient then
			continue
		end

		local tier = tierMap[index]
		local barFill

		if tier == 1 then
			barFill = math.clamp((displayedProgress - 0.5) / 0.5, 0, 1)
		else
			barFill = math.clamp(displayedProgress / 0.5, 0, 1)
		end

		local transparency
		if barFill >= 1 then
			transparency = NumberSequence.new(0)
		elseif barFill <= 0 then
			transparency = NumberSequence.new(1)
		else
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(math.clamp(barFill - gradientEpsilon, 0, 1), 0),
				NumberSequenceKeypoint.new(math.clamp(barFill + gradientEpsilon, 0, 1), 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end

		gradient.Transparency = transparency
	end
end

return fillBarHandler
