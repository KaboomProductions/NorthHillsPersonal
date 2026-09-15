local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)
local guiUtilities = require(replicatedFirst.ClientUtilities.GuiUtils)
local hoverState = require(script.HoverState)

local buttonController = {}
buttonController.__index = buttonController

type MenuController = {
	toggleTab: (self: MenuController, tabName: string) -> (),
	exitMenu: (self: MenuController) -> (),
}

type MenuAnimator = {
	setHovered: (self: MenuAnimator, button: TextButton, isHovered: boolean) -> (),
	setPressed: (self: MenuAnimator, button: TextButton, isPressed: boolean) -> (),
	triggerWave: (self: MenuAnimator, button: TextButton) -> (),
	resetButton: (self: MenuAnimator, button: TextButton) -> (),
}

export type ButtonControllerInfo = {
	menuController: MenuController,
	buttonFrame: Frame,
	button: TextButton,
	animator: MenuAnimator,
}

function buttonController:activate() end

function buttonController:onHoverEntered()
	local button = self.button

	self.animator:setHovered(button, true)
	self.hoverSound:Play()

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playUiHover()
	end
end

function buttonController:onHoverLeft()
	self.animator:setHovered(self.button, false)
end

function buttonController:connectHoverFeedback()
	self.hoverState = hoverState.new({
		button = self.button,
		onHoverEntered = function()
			self:onHoverEntered()
		end,
		onHoverLeft = function()
			self:onHoverLeft()
		end,
	})
end

function buttonController:connectPressFeedback()
	local button = self.button
	local animator = self.animator
	local connections = self.connections

	connections.inputBegan = button.InputBegan:Connect(function(inputObject: InputObject)
		if not guiUtilities.isPointerInput(inputObject) then
			return
		end

		animator:setPressed(button, true)
	end)

	connections.inputEnded = button.InputEnded:Connect(function(inputObject: InputObject)
		if not guiUtilities.isPointerInput(inputObject) then
			return
		end

		animator:setPressed(button, false)
	end)
end

function buttonController:connectActivation()
	local button = self.button
	local animator = self.animator

	self.connections.activated = button.Activated:Connect(function()
		self.clickSound:Play()

		local activeHaptics = haptics.getActiveHaptics()
		if activeHaptics then
			activeHaptics:playUiClick()
		end

		animator:triggerWave(button)
		self:activate()
	end)
end

function buttonController:preload()
	local menuSounds = workspace:WaitForChild("Audio"):WaitForChild("Effects"):WaitForChild("Menu")

	self.hoverSound = menuSounds:WaitForChild("Hover")
	self.clickSound = menuSounds:WaitForChild("Click")
end

function buttonController:init()
	buttonController.preload(self)
	if getmetatable(self) == nil then
		return
	end

	self:connectHoverFeedback()
	self:connectPressFeedback()
	self:connectActivation()
end

function buttonController.new(controllerInfo: ButtonControllerInfo)
	local self = setmetatable({}, buttonController)

	self.menuController = controllerInfo.menuController
	self.buttonFrame = controllerInfo.buttonFrame
	self.button = controllerInfo.button
	self.animator = controllerInfo.animator
	self.connections = {}
	self.hoverState = nil
	self.hoverSound = nil
	self.clickSound = nil

	task.defer(function()
		if getmetatable(self) then
			buttonController.init(self)
		end
	end)

	return self
end

function buttonController:destroy()
	local animator = self.animator
	local hoverController = self.hoverState

	if animator then
		animator:resetButton(self.button)
	end

	if hoverController then
		hoverController:destroy()
		self.hoverState = nil
	end

	connectionUtilities.disconnectConnections(self.connections)
	table.clear(self.connections)
	table.clear(self)
	setmetatable(self, nil)
end

return buttonController
