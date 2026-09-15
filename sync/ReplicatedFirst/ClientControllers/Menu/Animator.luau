local replicatedStorage = game:GetService("ReplicatedStorage")

local springModule = require(replicatedStorage.SharedClasses.Spring)

local animationConfig = {
	hoverOffset = Vector2.new(0.05, 0),
	pressedOffset = Vector2.new(0.05, 0.1),
	enterOffset = Vector2.zero,
	enterDelaySeconds = 0.06,

	springMass = 15,
	springForce = 150,
	springDamping = 4,
	springSpeed = 4.3,

	waveDurationSeconds = 0.6,
}

local highlightConfig = {
	baseColorComponent = 225 / 255,
	hoveredColorBoost = 30 / 255,
	maximumStrokeThickness = 0.015,
	minimumStrokeThickness = 0.01,
	minimumWidthScale = 0.6,
	widthScaleRange = 0.4,
}

local defaultTextColor = Color3.fromRGB(225, 225, 225)
local hoveredHighlightTarget = Vector2.new(1, 0)
local gradientRestOffset = Vector2.new(1, 0)
local gradientStartOffset = Vector2.new(-1, 0)

local highlightGradientColor = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
	ColorSequenceKeypoint.new(0.3, Color3.new(0, 0, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.8, Color3.new(0, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
})

local menuAnimator = {}
menuAnimator.__index = menuAnimator

local function createOffsetSpring(startOffset: Vector2)
	local offsetSpring = springModule.new(
		startOffset,
		animationConfig.springMass,
		animationConfig.springForce,
		animationConfig.springDamping,
		animationConfig.springSpeed
	)
	offsetSpring.position = startOffset
	offsetSpring.target = startOffset
	offsetSpring.velocity = Vector2.zero

	return offsetSpring
end

local function applyButtonPosition(buttonState, offset: Vector2)
	local basePosition = buttonState.basePosition

	buttonState.button.Position = UDim2.new(
		basePosition.X.Scale + offset.X,
		basePosition.X.Offset,
		basePosition.Y.Scale + offset.Y,
		basePosition.Y.Offset
	)
end

local function applyHighlight(buttonState, factor: number)
	local clampedFactor = math.clamp(factor, 0, 1)
	local colorComponent = highlightConfig.baseColorComponent + highlightConfig.hoveredColorBoost * clampedFactor
	local textColor = Color3.new(colorComponent, colorComponent, colorComponent)
	buttonState.button.TextColor3 = textColor

	local stroke = buttonState.stroke
	if stroke then
		local rawThickness = clampedFactor * highlightConfig.maximumStrokeThickness
		stroke.Thickness = if rawThickness < highlightConfig.minimumStrokeThickness then 0 else rawThickness
		stroke.Color = textColor
	end

	local highlight = buttonState.highlight
	if not highlight then
		return
	end

	local baseSize = buttonState.baseHighlightSize
	local widthScale = highlightConfig.minimumWidthScale + highlightConfig.widthScaleRange * clampedFactor
	highlight.Size = UDim2.new(baseSize.X.Scale * widthScale, baseSize.X.Offset, baseSize.Y.Scale, baseSize.Y.Offset)
	highlight.ImageTransparency = 1 - clampedFactor
end

function menuAnimator:applyButtonDefaults(buttonState)
	local actualButton = buttonState.button
	local highlight = buttonState.highlight
	local stroke = buttonState.stroke

	actualButton.TextColor3 = defaultTextColor

	if highlight then
		local baseSize = buttonState.baseHighlightSize
		highlight.ImageTransparency = 1
		highlight.Size =
			UDim2.new(baseSize.X.Scale * highlightConfig.minimumWidthScale, 0, baseSize.Y.Scale, baseSize.Y.Offset)
	end

	if stroke then
		stroke.Thickness = 0
		stroke.Color = defaultTextColor
	end
end

function menuAnimator:updateButtonTarget(actualButton: TextButton)
	local buttonState = self.buttonStates[actualButton]
	if not buttonState then
		return
	end

	local targetOffset = Vector2.zero
	if buttonState.isPressed then
		targetOffset = animationConfig.pressedOffset
	elseif buttonState.isHovered then
		targetOffset = animationConfig.hoverOffset
	end

	buttonState.positionSpring.target = targetOffset
	buttonState.highlightSpring.target = if buttonState.isHovered then hoveredHighlightTarget else Vector2.zero
end

function menuAnimator:registerButton(buttonFrame: Frame, actualButton: TextButton, animationIndex: number)
	local highlight = buttonFrame:FindFirstChild("Highlight") :: ImageLabel?
	local stroke = actualButton:FindFirstChildOfClass("UIStroke") :: UIStroke?
	local gradient = highlight and highlight:FindFirstChildOfClass("UIGradient") :: UIGradient?

	if gradient then
		gradient.Color = highlightGradientColor
		gradient.Offset = gradientRestOffset
	end

	local buttonState = {
		button = actualButton,
		buttonFrame = buttonFrame,
		basePosition = actualButton.Position,
		positionSpring = createOffsetSpring(animationConfig.enterOffset),
		highlightSpring = createOffsetSpring(Vector2.zero),
		highlight = highlight,
		baseHighlightSize = highlight and highlight.Size or UDim2.fromScale(1, 1),
		stroke = stroke,
		gradient = gradient,
		isHovered = false,
		isPressed = false,
		isWaveActive = false,
		waveProgress = 0,
	}

	self.buttonStates[actualButton] = buttonState

	self:applyButtonDefaults(buttonState)
	applyButtonPosition(buttonState, animationConfig.enterOffset)

	task.delay((animationIndex - 1) * animationConfig.enterDelaySeconds, function()
		if self.buttonStates[actualButton] == nil then
			return
		end

		self:updateButtonTarget(actualButton)
	end)
end

function menuAnimator:setupButtons(buttonFrames: { Instance })
	local animationIndex = 0

	for _, buttonFrame in buttonFrames do
		if not buttonFrame:IsA("Frame") then
			continue
		end

		local actualButton = buttonFrame:FindFirstChildOfClass("TextButton")
		if not actualButton then
			continue
		end

		animationIndex += 1
		self:registerButton(buttonFrame, actualButton, animationIndex)
	end
end

function menuAnimator:setHovered(actualButton: TextButton, isHovered: boolean)
	local buttonState = self.buttonStates[actualButton]
	if not buttonState then
		return
	end

	buttonState.isHovered = isHovered
	if not isHovered then
		buttonState.isPressed = false
	end

	self:updateButtonTarget(actualButton)
end

function menuAnimator:setPressed(actualButton: TextButton, isPressed: boolean)
	local buttonState = self.buttonStates[actualButton]
	if not buttonState then
		return
	end

	buttonState.isPressed = isPressed
	self:updateButtonTarget(actualButton)
end

function menuAnimator:triggerWave(actualButton: TextButton)
	local buttonState = self.buttonStates[actualButton]
	if not buttonState then
		return
	end

	buttonState.isWaveActive = true
	buttonState.waveProgress = 0

	if buttonState.gradient then
		buttonState.gradient.Offset = gradientStartOffset
	end
end

function menuAnimator:resetButton(actualButton: TextButton)
	local buttonState = self.buttonStates[actualButton]
	if not buttonState then
		return
	end

	buttonState.isHovered = false
	buttonState.isPressed = false
	self:updateButtonTarget(actualButton)
end

function menuAnimator:updateWave(buttonState, deltaTime: number)
	if not buttonState.isWaveActive then
		return
	end

	buttonState.waveProgress = math.min(buttonState.waveProgress + deltaTime / animationConfig.waveDurationSeconds, 1)

	local easedProgress = 1 - (1 - buttonState.waveProgress) ^ 3
	local gradient = buttonState.gradient
	if gradient then
		gradient.Offset = Vector2.new(-1 + easedProgress * 2, 0)
	end

	if buttonState.waveProgress < 1 then
		return
	end

	buttonState.isWaveActive = false
	if gradient then
		gradient.Offset = gradientRestOffset
	end
end

function menuAnimator:update(deltaTime: number)
	for _, buttonState in self.buttonStates do
		applyButtonPosition(buttonState, buttonState.positionSpring:update(deltaTime))
		applyHighlight(buttonState, buttonState.highlightSpring:update(deltaTime).X)
		self:updateWave(buttonState, deltaTime)
	end
end

function menuAnimator.new(buttonFrames: { Instance })
	local self = setmetatable({}, menuAnimator)

	self.buttonStates = {}

	self:setupButtons(buttonFrames)

	return self
end

function menuAnimator:destroy()
	for _, buttonState in self.buttonStates do
		buttonState.button.Position = buttonState.basePosition
		self:applyButtonDefaults(buttonState)

		if buttonState.gradient then
			buttonState.gradient.Offset = gradientRestOffset
		end
	end

	table.clear(self.buttonStates)
end

return menuAnimator
