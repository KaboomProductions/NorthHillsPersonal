local replicatedStorage = game:GetService("ReplicatedStorage")

local guiAnimatorModule = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)

local controllerConfig = {
	scaleLerpSpeed = 18,
	hoverScale = 1.01,
	clickScaleLerpSpeed = 28,
	clickScale = 0.99,

	closeButtonSpringFrequency = 15,
	closeButtonSpringDamping = 100,
	closeButtonSpringMass = 4,
	closeButtonSpringSpeed = 5,
	closeButtonHoverPullDown = 0.005,
	closeButtonHoverStretch = 0.06,
	closeButtonClickPullDown = 0.01,
	closeButtonClickStretch = 0.14,
	closeButtonStretchSpeed = 20,
}

local mainPageController = {}
mainPageController.__index = mainPageController

local function scaleTrackKey(button: GuiButton): string
	return "scale_" .. button.Name
end

local function getOrCreateScale(button: GuiButton): UIScale
	local existingScale = button:FindFirstChildOfClass("UIScale")
	if existingScale then
		return existingScale
	end

	local newScale = Instance.new("UIScale")
	newScale.Scale = 1
	newScale.Parent = button
	return newScale
end

function mainPageController.new(context, callbacks: {
	isShopOpen: () -> boolean,
	onCloseRequested: () -> (),
	onOptionCloseRequested: () -> (),
	onOptionButtonActivated: (string) -> (),
})
	local self = setmetatable({}, mainPageController)
	self.context = context
	self.callbacks = callbacks
	self.animator = guiAnimatorModule.new(context.optionsFrame)
	self.connections = {}
	self.buttonOptionIds = {}
	self.closeButtonBases = {}
	self.activeCloseButton = context.mainPage.closeButton

	self:setupCloseButtons()
	self:setupOptionButtons()

	return self
end

function mainPageController:setButtonOptionIds(buttonOptionIds: {[ImageButton]: string})
	self.buttonOptionIds = buttonOptionIds
end

function mainPageController:isInteractive(): boolean
	return self.callbacks.isShopOpen()
end

function mainPageController:setActiveCloseButton(button: TextButton)
	if self.activeCloseButton == button then
		return
	end

	if self.activeCloseButton then
		local oldBase = self.closeButtonBases[self.activeCloseButton]
		if oldBase then
			self.activeCloseButton.Position = oldBase.position
			self.activeCloseButton.Size = oldBase.size
		end
	end

	self.activeCloseButton = button
	self.animator:snapSpring("bookmarkPull", Vector2.zero)
	self.animator:snapNumberLerp("bookmarkStretch", 0)
end

function mainPageController:setSubpageOpen(isSubpageOpen: boolean)
	local button = isSubpageOpen and self.context.buyPage.tabsCloseButton or self.context.mainPage.closeButton
	self:setActiveCloseButton(button)
end

function mainPageController:setupCloseButtons()
	local mainCloseButton = self.context.mainPage.closeButton
	local tabsCloseButton = self.context.buyPage.tabsCloseButton

	for _, button in ipairs({ mainCloseButton, tabsCloseButton }) do
		self.closeButtonBases[button] = {
			position = self.animator.uiCache:get(button, "Position"),
			size = self.animator.uiCache:get(button, "Size"),
		}
	end

	self.animator:addScalarSpring(
		"bookmarkPull",
		0,
		controllerConfig.closeButtonSpringFrequency,
		controllerConfig.closeButtonSpringDamping,
		controllerConfig.closeButtonSpringMass,
		controllerConfig.closeButtonSpringSpeed
	)

	self.animator:addNumberSpringTrack("bookmarkPullTrack", function(yScale)
		local activeCloseButton = self.activeCloseButton
		if activeCloseButton == nil then
			return
		end

		local base = self.closeButtonBases[activeCloseButton]
		if base == nil then
			return
		end

		activeCloseButton.Position = base.position + UDim2.fromScale(0, yScale)
	end, "bookmarkPull", 0)

	self.animator:addNumberLerpTrack("bookmarkStretch", function(stretch)
		local activeCloseButton = self.activeCloseButton
		if activeCloseButton == nil then
			return
		end

		local base = self.closeButtonBases[activeCloseButton]
		if base == nil then
			return
		end

		activeCloseButton.Size = base.size + UDim2.fromScale(0, stretch)
	end, 0, 0, controllerConfig.closeButtonStretchSpeed)

	for _, button in ipairs({ mainCloseButton, tabsCloseButton }) do
		table.insert(self.connections, button.MouseEnter:Connect(function()
			if not self:isInteractive() or self.activeCloseButton ~= button then
				return
			end

			self.animator:setSpring("bookmarkPull", Vector2.new(controllerConfig.closeButtonHoverPullDown, 0))
			self.animator:setNumberLerpTarget("bookmarkStretch", controllerConfig.closeButtonHoverStretch)
		end))

		table.insert(self.connections, button.MouseLeave:Connect(function()
			if not self:isInteractive() or self.activeCloseButton ~= button then
				return
			end

			self.animator:setSpring("bookmarkPull", Vector2.zero)
			self.animator:setNumberLerpTarget("bookmarkStretch", 0)
		end))

		table.insert(self.connections, button.MouseButton1Down:Connect(function()
			if not self:isInteractive() or self.activeCloseButton ~= button then
				return
			end

			self.animator:setSpring("bookmarkPull", Vector2.new(controllerConfig.closeButtonClickPullDown, 0))
			self.animator:setNumberLerpTarget("bookmarkStretch", controllerConfig.closeButtonClickStretch)
		end))

		table.insert(self.connections, button.MouseButton1Up:Connect(function()
			if not self:isInteractive() or self.activeCloseButton ~= button then
				return
			end

			self.animator:setSpring("bookmarkPull", Vector2.new(controllerConfig.closeButtonHoverPullDown, 0))
			self.animator:setNumberLerpTarget("bookmarkStretch", controllerConfig.closeButtonHoverStretch)
		end))
	end

	table.insert(self.connections, mainCloseButton.Activated:Connect(function()
		if not self:isInteractive() then
			return
		end

		self.callbacks.onCloseRequested()
	end))

	table.insert(self.connections, tabsCloseButton.Activated:Connect(function()
		if not self:isInteractive() then
			return
		end

		self.callbacks.onOptionCloseRequested()
	end))
end

function mainPageController:setupOptionButtons()
	for _, button in ipairs(self.context.mainPage.optionButtons) do
		local uiScale = getOrCreateScale(button)
		local trackName = scaleTrackKey(button)

		self.animator:addNumberLerpTrack(trackName, function(scale)
			uiScale.Scale = scale
		end, 1, 1, controllerConfig.scaleLerpSpeed)

		table.insert(self.connections, button.MouseEnter:Connect(function()
			if not self:isInteractive() then
				return
			end

			self.animator:setNumberLerpTarget(trackName, controllerConfig.hoverScale)
		end))

		table.insert(self.connections, button.MouseLeave:Connect(function()
			if not self:isInteractive() then
				return
			end

			self.animator:setNumberLerpTarget(trackName, 1)
		end))

		table.insert(self.connections, button.MouseButton1Down:Connect(function()
			if not self:isInteractive() then
				return
			end

			self.animator:setNumberLerpTarget(trackName, controllerConfig.clickScale, controllerConfig.clickScaleLerpSpeed)
		end))

		table.insert(self.connections, button.MouseButton1Up:Connect(function()
			if not self:isInteractive() then
				return
			end

			self.animator:setNumberLerpTarget(trackName, controllerConfig.hoverScale, controllerConfig.scaleLerpSpeed)
		end))

		table.insert(self.connections, button.Activated:Connect(function()
			if not self:isInteractive() then
				return
			end

			local optionId = self.buttonOptionIds[button]
			if optionId ~= nil then
				self.callbacks.onOptionButtonActivated(optionId)
			end
		end))
	end
end

function mainPageController:resetOptionButtons()
	for _, button in ipairs(self.context.mainPage.optionButtons) do
		self.animator:snapNumberLerp(scaleTrackKey(button), 1)
	end
end

function mainPageController:update(deltaTime: number)
	self.animator:applyTracks(deltaTime)
end

function mainPageController:destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
	self.animator:destroy()

	setmetatable(self, nil)
end

return mainPageController
