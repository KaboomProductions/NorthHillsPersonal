local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)
local hoverState = require(replicatedFirst.ClientControllers.Menu.ButtonController.HoverState)

local defaultTextColor = Color3.fromRGB(130, 130, 130)
local hoveredTextColor = Color3.fromRGB(190, 190, 190)
local selectedTextColor = Color3.fromRGB(255, 255, 255)
local colorLerpSpeed = 12

local categoryController = {}
categoryController.__index = categoryController
categoryController.__vars = {
	isHovered = false,
	targetTextColor = defaultTextColor,
}

export type CategoryControllerInfo = {
	button: TextButton,
	page: GuiObject,
	isSelected: () -> boolean,
	onSelected: (TextButton, GuiObject) -> (),
}

function categoryController:updateTargetTextColor()
	local stateValues = self.__vars

	if self.isSelected() then
		stateValues.targetTextColor = selectedTextColor
		return
	end

	if stateValues.isHovered then
		stateValues.targetTextColor = hoveredTextColor
		return
	end

	stateValues.targetTextColor = defaultTextColor
end

function categoryController:update(deltaTime: number)
	local button = self.button
	local targetTextColor = self.__vars.targetTextColor
	local lerpAlpha = math.min(colorLerpSpeed * deltaTime, 1)

	button.TextColor3 = button.TextColor3:Lerp(targetTextColor, lerpAlpha)
end

function categoryController:onHoverEntered()
	self.__vars.isHovered = true
	self:updateTargetTextColor()

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playUiHover()
	end
end

function categoryController:onHoverLeft()
	self.__vars.isHovered = false
	self:updateTargetTextColor()
end

function categoryController:onActivated()
	self.clickSound:Play()

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playUiClick()
	end

	self.onSelected(self.button, self.page)
end

function categoryController:connectHoverFeedback()
	self.hoverController = hoverState.new({
		button = self.button,
		onHoverEntered = function()
			self:onHoverEntered()
		end,
		onHoverLeft = function()
			self:onHoverLeft()
		end,
	})
end

function categoryController:connectSignals()
	local connections = self.connections

	connections.activated = self.button.Activated:Connect(function()
		self:onActivated()
	end)

	connections.update = runService.RenderStepped:Connect(function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function categoryController:preload()
	self.clickSound = workspace
		:WaitForChild("Audio")
		:WaitForChild("Effects")
		:WaitForChild("Menu")
		:WaitForChild("Click")
end

function categoryController:init()
	self:preload()
	if getmetatable(self) == nil then
		return
	end

	self:connectHoverFeedback()
	self:connectSignals()
	self:updateTargetTextColor()
end

function categoryController.new(controllerInfo: CategoryControllerInfo)
	local self = setmetatable({}, categoryController)

	self.button = controllerInfo.button
	self.page = controllerInfo.page
	self.isSelected = controllerInfo.isSelected
	self.onSelected = controllerInfo.onSelected
	self.connections = {}
	self.__vars = table.clone(categoryController.__vars)
	self.clickSound = nil
	self.hoverController = nil

	task.defer(function()
		if getmetatable(self) then
			self:init()
		end
	end)

	return self
end

function categoryController:destroy()
	local hoverController = self.hoverController
	if hoverController then
		hoverController:destroy()
		self.hoverController = nil
	end

	connectionUtilities.disconnectConnections(self.connections)
	table.clear(self.connections)
	table.clear(self)
	setmetatable(self, nil)
end

return categoryController
