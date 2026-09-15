local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local animationConfig = require(script.Config)
local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)
local guiUtilities = require(replicatedFirst.ClientUtilities.GuiUtils)
local hoverState = require(replicatedFirst.ClientControllers.Menu.ButtonController.HoverState)
local springModule = require(replicatedStorage.SharedClasses.Spring)

local settingButtonAnimator = {}
settingButtonAnimator.__index = settingButtonAnimator
settingButtonAnimator.__vars = {
	hasActiveState = false,
	isActive = false,
	shouldSlideRight = false,
	currentTransparency = animationConfig.defaultInactiveTransparency,
	currentOffset = animationConfig.rightOffset,
	targetOffset = animationConfig.rightOffset,
	isHovered = false,
	isWaveActive = false,
	inactiveTransparency = animationConfig.defaultInactiveTransparency,
}

export type SettingButtonAnimatorInfo = {
	scaleInstance: GuiObject,
	inputButton: GuiButton,
	gradientHost: GuiObject?,
	inactiveTransparency: number?,
}

local function getOrCreateUiScale(guiObject: GuiObject): UIScale
	local existingScale = guiObject:FindFirstChildOfClass("UIScale")
	if existingScale then
		return existingScale
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = guiObject

	return uiScale
end

function settingButtonAnimator:createGradient()
	local gradientHost = self.gradientHost
	if gradientHost == nil then
		return
	end

	local stateValues = self.__vars
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new(stateValues.inactiveTransparency)
	gradient.Offset = animationConfig.rightOffset
	gradient.Parent = gradientHost

	if gradientHost:IsA("ImageLabel") or gradientHost:IsA("ImageButton") then
		gradientHost.ImageTransparency = 0
	end

	self.gradient = gradient
end

function settingButtonAnimator:setScaleTarget(targetScale: number)
	self.scaleSpring.target = Vector2.new(targetScale, 0)
end

function settingButtonAnimator:onHoverEntered()
	self.__vars.isHovered = true
	self:setScaleTarget(animationConfig.hoverScale)
	if self.hoverSound then
		self.hoverSound:Play()
	end

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playUiHover()
	end
end

function settingButtonAnimator:onHoverLeft()
	self.__vars.isHovered = false
	self:setScaleTarget(animationConfig.baseScale)
end

function settingButtonAnimator:updateActiveGradient()
	local gradient = self.gradient
	if gradient == nil then
		return
	end

	local stateValues = self.__vars
	local isActive = stateValues.isActive
	local shouldSlideRight = stateValues.shouldSlideRight
	local targetTransparency = if isActive then animationConfig.activeTransparency else stateValues.inactiveTransparency
	local halfFeatherSize = animationConfig.featherSize / 2
	local leadingTransparency = if shouldSlideRight then targetTransparency else stateValues.currentTransparency
	local trailingTransparency = if shouldSlideRight then stateValues.currentTransparency else targetTransparency

	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, leadingTransparency),
		NumberSequenceKeypoint.new(math.max(0, 0.5 - halfFeatherSize), leadingTransparency),
		NumberSequenceKeypoint.new(math.min(1, 0.5 + halfFeatherSize), trailingTransparency),
		NumberSequenceKeypoint.new(1, trailingTransparency),
	})

	stateValues.currentOffset = if shouldSlideRight then animationConfig.leftOffset else animationConfig.rightOffset
	stateValues.targetOffset = if shouldSlideRight then animationConfig.rightOffset else animationConfig.leftOffset
	stateValues.currentTransparency = targetTransparency
	stateValues.isWaveActive = true
	gradient.Offset = stateValues.currentOffset
end

function settingButtonAnimator:setActive(isActive: boolean, shouldSlideRight: boolean)
	local stateValues = self.__vars
	stateValues.hasActiveState = true
	stateValues.isActive = isActive
	stateValues.shouldSlideRight = shouldSlideRight

	self:updateActiveGradient()
end

function settingButtonAnimator:update(deltaTime: number)
	local stateValues = self.__vars
	local gradient = self.gradient

	self.uiScale.Scale = self.scaleSpring:update(deltaTime).X
	if not stateValues.isWaveActive then
		return
	end

	if gradient == nil then
		stateValues.isWaveActive = false
		return
	end

	local lerpAlpha = 1 - animationConfig.waveLerpDecay ^ deltaTime
	stateValues.currentOffset = stateValues.currentOffset:Lerp(stateValues.targetOffset, lerpAlpha)
	gradient.Offset = stateValues.currentOffset

	if (stateValues.currentOffset - stateValues.targetOffset).Magnitude >= animationConfig.waveSettleDistance then
		return
	end

	stateValues.isWaveActive = false
	stateValues.currentOffset = stateValues.targetOffset
	gradient.Offset = stateValues.targetOffset
	gradient.Transparency = NumberSequence.new(stateValues.currentTransparency)
end

function settingButtonAnimator:connectHoverFeedback()
	self.hoverController = hoverState.new({
		button = self.inputButton,
		onHoverEntered = function()
			self:onHoverEntered()
		end,
		onHoverLeft = function()
			self:onHoverLeft()
		end,
	})
end

function settingButtonAnimator:connectPressFeedback()
	local inputButton = self.inputButton
	local connections = self.connections

	connections.inputBegan = inputButton.InputBegan:Connect(function(inputObject: InputObject)
		if not guiUtilities.isPointerInput(inputObject) then
			return
		end

		self:setScaleTarget(animationConfig.pressedScale)
	end)

	connections.inputEnded = inputButton.InputEnded:Connect(function(inputObject: InputObject)
		if not guiUtilities.isPointerInput(inputObject) then
			return
		end

		local targetScale = if self.__vars.isHovered then animationConfig.hoverScale else animationConfig.baseScale
		self:setScaleTarget(targetScale)
	end)
end

function settingButtonAnimator:connectUpdates()
	self.connections.update = runService.RenderStepped:Connect(function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function settingButtonAnimator:preload()
	self.hoverSound = workspace
		:WaitForChild("Audio")
		:WaitForChild("Effects")
		:WaitForChild("Menu")
		:WaitForChild("Hover")
	self.uiScale = getOrCreateUiScale(self.scaleInstance)
	self.scaleSpring = springModule.new(
		Vector2.new(animationConfig.baseScale, 0),
		animationConfig.springMass,
		animationConfig.springForce,
		animationConfig.springDamping,
		animationConfig.springSpeed
	)

	self:createGradient()
end

function settingButtonAnimator:init()
	self:preload()
	if getmetatable(self) == nil then
		return
	end

	if self.__vars.hasActiveState then
		self:updateActiveGradient()
	end
	self:connectHoverFeedback()
	self:connectPressFeedback()
	self:connectUpdates()
end

function settingButtonAnimator.new(animatorInfo: SettingButtonAnimatorInfo)
	local self = setmetatable({}, settingButtonAnimator)

	self.scaleInstance = animatorInfo.scaleInstance
	self.inputButton = animatorInfo.inputButton
	self.gradientHost = animatorInfo.gradientHost
	self.connections = {}
	self.__vars = table.clone(settingButtonAnimator.__vars)
	self.__vars.inactiveTransparency = animatorInfo.inactiveTransparency or animationConfig.defaultInactiveTransparency
	self.__vars.currentTransparency = self.__vars.inactiveTransparency

	self.gradient = nil
	self.hoverController = nil
	self.hoverSound = nil
	self.scaleSpring = nil
	self.uiScale = nil

	task.defer(function()
		if getmetatable(self) then
			self:init()
		end
	end)

	return self
end

function settingButtonAnimator:destroy()
	local hoverController = self.hoverController
	local gradient = self.gradient

	if hoverController then
		hoverController:destroy()
		self.hoverController = nil
	end

	connectionUtilities.disconnectConnections(self.connections)
	table.clear(self.connections)

	if gradient then
		gradient:Destroy()
		self.gradient = nil
	end

	table.clear(self)
	setmetatable(self, nil)
end

return settingButtonAnimator
