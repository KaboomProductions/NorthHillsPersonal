local guiService = game:GetService("GuiService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")

local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)

local hoverState = {}
hoverState.__index = hoverState
hoverState.__vars = {
	isHovered = false,
	isPointerHovering = false,
}

export type HoverStateInfo = {
	button: GuiButton,
	onHoverEntered: () -> (),
	onHoverLeft: () -> (),
}

function hoverState:isHoveredByActiveInput(): boolean
	local stateValues = self.__vars

	if userInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		return guiService.SelectedObject == self.button
	end

	return stateValues.isPointerHovering
end

function hoverState:updateHoverState()
	local stateValues = self.__vars
	local isHovered = self:isHoveredByActiveInput()
	if stateValues.isHovered == isHovered then
		return
	end

	stateValues.isHovered = isHovered
	if isHovered then
		self.onHoverEntered()
		return
	end

	self.onHoverLeft()
end

function hoverState:onPointerEntered()
	self.__vars.isPointerHovering = true
	self:updateHoverState()
end

function hoverState:onPointerLeft()
	self.__vars.isPointerHovering = false
	self:updateHoverState()
end

function hoverState:connectInputSignals()
	local button = self.button
	local connections = self.connections

	connections.pointerEntered = button.MouseEnter:Connect(function()
		self:onPointerEntered()
	end)

	connections.pointerLeft = button.MouseLeave:Connect(function()
		self:onPointerLeft()
	end)

	connections.selectedObjectChanged = guiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		self:updateHoverState()
	end)

	connections.preferredInputChanged = userInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		self:updateHoverState()
	end)
end

function hoverState:init()
	self:connectInputSignals()
	self:updateHoverState()
end

function hoverState.new(hoverStateInfo: HoverStateInfo)
	local self = setmetatable({}, hoverState)

	self.button = hoverStateInfo.button
	self.onHoverEntered = hoverStateInfo.onHoverEntered
	self.onHoverLeft = hoverStateInfo.onHoverLeft
	self.connections = {}
	self.__vars = table.clone(hoverState.__vars)

	self:init()

	return self
end

function hoverState:destroy()
	connectionUtilities.disconnectConnections(self.connections)
	table.clear(self.connections)
	table.clear(self)
	setmetatable(self, nil)
end

return hoverState
