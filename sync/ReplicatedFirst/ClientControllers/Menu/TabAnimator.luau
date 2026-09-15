local replicatedStorage = game:GetService("ReplicatedStorage")

local springModule = require(replicatedStorage.SharedClasses.Spring)
local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)

local tabConfig = {
	openYOffset = 0,
	closeTopYOffset = -1.3,
	closeBottomYOffset = 1.3,

	springMass = 15,
	springForce = 100,
	springDamping = 5,
	springSpeed = 3.5,

	hideThreshold = 0.05,

	closeButtonHoverPullDown = 0.005,
	closeButtonHoverStretch = 0.06,
	closeButtonPressedPullDown = 0.01,
	closeButtonPressedStretch = 0.14,
	closeButtonStretchSpeed = 20,
}

local tabAnimator = {}
tabAnimator.__index = tabAnimator

local function findCloseControl(tabFrame: Frame): (GuiButton?, GuiObject?)
	for _, controlName in { "CloseButton", "Close", "Exit" } do
		local closeControl = tabFrame:FindFirstChild(controlName, true)
		if closeControl == nil then
			continue
		end

		if closeControl:IsA("GuiButton") then
			return closeControl, closeControl
		end

		local nestedButton = closeControl:FindFirstChildWhichIsA("GuiButton", true)
		if nestedButton then
			local animatedControl = if closeControl:IsA("GuiObject") then closeControl else nestedButton
			return nestedButton, animatedControl
		end
	end

	return nil, nil
end

local function setCloseButtonTarget(tabState, pullDown: number, stretch: number)
	if not tabState.isOpen then
		return
	end

	tabState.closeButtonSpring.target = Vector2.new(pullDown, 0)
	tabState.closeButtonStretchTarget = stretch
end

local function resetCloseButton(tabState)
	tabState.closeButtonSpring.target = Vector2.zero
	tabState.closeButtonStretchTarget = 0
end

local function connectCloseButton(self, tabState)
	local closeButton = tabState.closeButton
	if closeButton == nil then
		return
	end

	local connections = tabState.connections
	connections.closeEntered = closeButton.MouseEnter:Connect(function()
		if not tabState.isOpen then
			return
		end

		self.hoverSound:Play()
		setCloseButtonTarget(
			tabState,
			tabConfig.closeButtonHoverPullDown,
			tabConfig.closeButtonHoverStretch
		)
	end)
	connections.closeLeft = closeButton.MouseLeave:Connect(function()
		resetCloseButton(tabState)
	end)
	connections.closePressed = closeButton.MouseButton1Down:Connect(function()
		setCloseButtonTarget(
			tabState,
			tabConfig.closeButtonPressedPullDown,
			tabConfig.closeButtonPressedStretch
		)
	end)
	connections.closeReleased = closeButton.MouseButton1Up:Connect(function()
		setCloseButtonTarget(
			tabState,
			tabConfig.closeButtonHoverPullDown,
			tabConfig.closeButtonHoverStretch
		)
	end)
	connections.closeActivated = closeButton.Activated:Connect(function()
		if not tabState.isOpen then
			return
		end

		self.clickSound:Play()
		self:closeTab(tabState.frame.Name)
	end)
end

local function applyTabOffset(tabState, yOffset: number)
	local basePosition = tabState.basePosition

	tabState.frame.Position =
		UDim2.new(basePosition.X.Scale, basePosition.X.Offset, basePosition.Y.Scale + yOffset, basePosition.Y.Offset)
end

function tabAnimator:registerTab(tabFrame: Frame)
	local closedOffset = Vector2.new(0, tabConfig.closeBottomYOffset)
	local spring = springModule.new(
		closedOffset,
		tabConfig.springMass,
		tabConfig.springForce,
		tabConfig.springDamping,
		tabConfig.springSpeed
	)
	spring.position = closedOffset
	spring.target = closedOffset
	spring.velocity = Vector2.zero

	local closeButton, closeControl = findCloseControl(tabFrame)
	local closeButtonSpring = springModule.new(
		Vector2.zero,
		tabConfig.springMass,
		tabConfig.springForce,
		tabConfig.springDamping,
		tabConfig.springSpeed
	)

	local tabState = {
		frame = tabFrame,
		basePosition = tabFrame.Position,
		spring = spring,
		isOpen = false,
		closeButton = closeButton,
		closeControl = closeControl,
		closeButtonBasePosition = closeControl and closeControl.Position,
		closeButtonBaseSize = closeControl and closeControl.Size,
		closeButtonSpring = closeButtonSpring,
		closeButtonStretch = 0,
		closeButtonStretchTarget = 0,
		connections = {},
	}

	tabFrame.Visible = false
	applyTabOffset(tabState, tabConfig.closeBottomYOffset)
	connectCloseButton(self, tabState)

	self.tabStates[tabFrame.Name] = tabState
end

function tabAnimator:closeTab(tabName: string)
	local tabState = self.tabStates[tabName]
	if not tabState or not tabState.isOpen then
		return
	end

	tabState.isOpen = false
	resetCloseButton(tabState)
	if self.activeTabName == tabName then
		self.activeTabName = nil
	end

	tabState.spring.target = Vector2.new(0, tabConfig.closeBottomYOffset)
end

function tabAnimator:openTab(tabName: string)
	local tabState = self.tabStates[tabName]
	if not tabState then
		return
	end

	if self.activeTabName and self.activeTabName ~= tabName then
		self:closeTab(self.activeTabName)
	end

	tabState.isOpen = true
	self.activeTabName = tabName

	tabState.spring.position = Vector2.new(0, tabConfig.closeTopYOffset)
	tabState.spring.target = Vector2.new(0, tabConfig.openYOffset)
	tabState.spring.velocity = Vector2.zero
	tabState.frame.Visible = true
end

function tabAnimator:toggleTab(tabName: string)
	local tabState = self.tabStates[tabName]
	if not tabState then
		return
	end

	if tabState.isOpen then
		self:closeTab(tabName)
		return
	end

	self:openTab(tabName)
end

function tabAnimator:update(deltaTime: number)
	for _, tabState in self.tabStates do
		local offset = tabState.spring:update(deltaTime)
		applyTabOffset(tabState, offset.Y)

		local closeControl = tabState.closeControl
		if closeControl then
			local pullDown = tabState.closeButtonSpring:update(deltaTime).X
			local stretchAlpha = 1 - math.exp(-tabConfig.closeButtonStretchSpeed * deltaTime)
			tabState.closeButtonStretch +=
				(tabState.closeButtonStretchTarget - tabState.closeButtonStretch) * stretchAlpha
			closeControl.Position = tabState.closeButtonBasePosition + UDim2.fromScale(0, pullDown)
			closeControl.Size = tabState.closeButtonBaseSize + UDim2.fromScale(0, tabState.closeButtonStretch)
		end

		if not tabState.isOpen and offset.Y >= tabConfig.closeBottomYOffset - tabConfig.hideThreshold then
			tabState.frame.Visible = false
		end
	end
end

function tabAnimator.new(tabsFolder: Frame)
	local self = setmetatable({}, tabAnimator)
	local menuSounds = workspace:WaitForChild("Audio"):WaitForChild("Effects"):WaitForChild("Menu")

	self.tabStates = {}
	self.activeTabName = nil
	self.hoverSound = menuSounds:WaitForChild("Hover")
	self.clickSound = menuSounds:WaitForChild("Click")

	for _, tabFrame in tabsFolder:GetChildren() do
		if not tabFrame:IsA("Frame") then
			continue
		end

		self:registerTab(tabFrame)
	end

	return self
end

function tabAnimator:destroy()
	for _, tabState in self.tabStates do
		tabState.frame.Visible = false
		tabState.frame.Position = tabState.basePosition
		connectionUtilities.disconnectConnections(tabState.connections)

		if tabState.closeControl then
			tabState.closeControl.Position = tabState.closeButtonBasePosition
			tabState.closeControl.Size = tabState.closeButtonBaseSize
		end
	end

	table.clear(self.tabStates)
	self.activeTabName = nil
	self.hoverSound = nil
	self.clickSound = nil
end

return tabAnimator
