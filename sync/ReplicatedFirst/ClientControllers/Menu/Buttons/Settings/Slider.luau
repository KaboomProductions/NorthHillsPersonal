local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")

local springModule = require(replicatedStorage.SharedClasses.Spring)
local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)

local transferSettingRemote = replicatedStorage.Communication.RemoteFunctions.TransferSetting

local minimumThumbPosition = 0.025
local maximumThumbPosition = 0.955
local gamepadStepPercent = 5
local hapticIntervalPercent = 5
local hoverThumbScaleMultiplier = 1.12
local hoverTextBrightness = 0.45
local hoverLerpSpeed = 18

local springMass = 15
local springForce = 150
local springDamping = 4.5
local springSpeed = 7

local sliderSettingController = {}
sliderSettingController.__index = sliderSettingController
sliderSettingController.__vars = {
	isDragging = false,
	currentValue = 100,
	lastHapticInterval = 20,
	thumbYScale = 0.5,
}

local sliderControllers = {}
local activeSliderController = nil
local hoverTextColor = Color3.new(1, 1, 1)

export type SliderSettingDefinition = {
	settingType: string,
	categoryId: string,
	settingName: string,
	default: number?,
}

local function isPointWithinGuiObject(point: Vector2, guiObject: GuiObject): boolean
	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize

	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

local function findCursorSlider(): typeof(sliderSettingController)?
	local cursorY = userInputService:GetMouseLocation().Y
	local closestSlider = nil
	local closestDistance = math.huge

	for sliderController in sliderControllers do
		if not sliderController:isCursorOverSlider() then
			continue
		end

		local barFrame = sliderController.barFrame
		local barCenterY = barFrame.AbsolutePosition.Y + barFrame.AbsoluteSize.Y * 0.5
		local distance = math.abs(cursorY - barCenterY)
		if distance < closestDistance then
			closestSlider = sliderController
			closestDistance = distance
		end
	end

	return closestSlider
end

local function getOrCreateThumbScale(sliderThumb: GuiObject): UIScale
	local existingScale = sliderThumb:FindFirstChildOfClass("UIScale")
	if existingScale then
		return existingScale
	end

	local thumbScale = Instance.new("UIScale")
	thumbScale.Parent = sliderThumb
	return thumbScale
end

function sliderSettingController:calculateThumbPosition(settingPercent: number): number
	local normalizedAlpha = math.clamp(settingPercent / 100, 0, 1)
	return minimumThumbPosition + normalizedAlpha * (maximumThumbPosition - minimumThumbPosition)
end

function sliderSettingController:updateDisplay(settingPercent: number)
	self.__vars.currentValue = settingPercent
	self.thumbSpring.target = Vector2.new(self:calculateThumbPosition(settingPercent), 0)
	self.amountLabel.Text = tostring(math.round(settingPercent)) .. "%"
end

function sliderSettingController:playValueHaptic(settingPercent: number)
	local hapticInterval = math.floor(settingPercent / hapticIntervalPercent)
	if hapticInterval == self.__vars.lastHapticInterval then
		return
	end

	self.__vars.lastHapticInterval = hapticInterval
	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics == nil then
		return
	end

	if settingPercent <= 0 or settingPercent >= 100 then
		activeHaptics:playSliderBoundary()
		return
	end

	activeHaptics:playSliderStep(settingPercent / 100)
end

function sliderSettingController:updateFromUserInput(settingPercent: number)
	local clampedPercent = math.clamp(settingPercent, 0, 100)
	self:updateDisplay(clampedPercent)
	self:playValueHaptic(clampedPercent)
end

function sliderSettingController:updateFromMousePosition(mousePositionX: number)
	local barAbsoluteX = self.barFrame.AbsolutePosition.X
	local barAbsoluteWidth = self.barFrame.AbsoluteSize.X

	local normalizedAlpha = math.clamp((mousePositionX - barAbsoluteX) / barAbsoluteWidth, 0, 1)
	self:updateFromUserInput(normalizedAlpha * 100)
end

function sliderSettingController:isCursorOverSlider(): boolean
	local cursorPosition = userInputService:GetMouseLocation()
	local ancestor: Instance? = self.frame

	while ancestor and ancestor:IsA("GuiObject") do
		if not ancestor.Visible or (ancestor.ClipsDescendants and not isPointWithinGuiObject(cursorPosition, ancestor)) then
			return false
		end

		ancestor = ancestor.Parent
	end

	return isPointWithinGuiObject(cursorPosition, self.frame)
end

function sliderSettingController:confirmCurrentValue()
	local confirmedValue = transferSettingRemote:InvokeServer(self.settingDefinition, self.__vars.currentValue / 100)

	if confirmedValue ~= nil then
		self:updateDisplay(confirmedValue * 100)
	end
end

function sliderSettingController:endDrag()
	if not self.__vars.isDragging then
		return
	end

	self.__vars.isDragging = false
	if activeSliderController == self then
		activeSliderController = nil
	end

	connectionUtilities.disconnectConnection(self.connections.dragChanged)
	connectionUtilities.disconnectConnection(self.connections.dragEnded)
	self.connections.dragChanged = nil
	self.connections.dragEnded = nil

	self:confirmCurrentValue()
end

function sliderSettingController:startDrag()
	if self.__vars.isDragging or (activeSliderController and activeSliderController ~= self) then
		return
	end

	activeSliderController = self
	self.__vars.isDragging = true

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playUiClick()
	end

	self.connections.dragChanged = userInputService.InputChanged:Connect(function(inputObject: InputObject)
		local inputType = inputObject.UserInputType
		if inputType ~= Enum.UserInputType.MouseMovement and inputType ~= Enum.UserInputType.Touch then
			return
		end

		self:updateFromMousePosition(inputObject.Position.X)
	end)

	self.connections.dragEnded = userInputService.InputEnded:Connect(function(inputObject: InputObject)
		local inputType = inputObject.UserInputType
		local isGamepadConfirm = inputObject.KeyCode == Enum.KeyCode.ButtonA
		if inputType ~= Enum.UserInputType.MouseButton1
			and inputType ~= Enum.UserInputType.Touch
			and not isGamepadConfirm
		then
			return
		end

		self:endDrag()
	end)
end

function sliderSettingController:init()
	local barFrame = self.frame:WaitForChild("Bar", 3) :: Frame
	local sliderThumb = self.frame:WaitForChild("Slider", 3) :: ImageLabel
	local amountLabel = self.frame:WaitForChild("Amount", 3) :: TextLabel

	self.barFrame = barFrame
	self.sliderThumb = sliderThumb
	self.amountLabel = amountLabel
	self.thumbScale = getOrCreateThumbScale(sliderThumb)
	self.thumbBaseScale = self.thumbScale.Scale
	self.amountBaseColor = amountLabel.TextColor3
	self.amountHoverColor = self.amountBaseColor:Lerp(hoverTextColor, hoverTextBrightness)
	self.__vars.thumbYScale = sliderThumb.Position.Y.Scale

	local initialValue = self.settingDefinition.default or 100
	local initialThumbX = self:calculateThumbPosition(initialValue)
	self.thumbSpring =
		springModule.new(Vector2.new(initialThumbX, 0), springMass, springForce, springDamping, springSpeed)

	self.__vars.currentValue = initialValue
	self.__vars.lastHapticInterval = math.floor(initialValue / hapticIntervalPercent)
	self.amountLabel.Text = tostring(math.round(initialValue)) .. "%"
	self.sliderThumb.Position = UDim2.fromScale(initialThumbX, self.__vars.thumbYScale)
	sliderControllers[self] = true

	self.connections.update = runService.RenderStepped:Connect(function(deltaTime: number)
		if self.__vars.isDragging and userInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			self:updateFromMousePosition(userInputService:GetMouseLocation().X)
		end

		local springX = math.clamp(self.thumbSpring:update(deltaTime).X, minimumThumbPosition, maximumThumbPosition)
		self.sliderThumb.Position = UDim2.fromScale(springX, self.__vars.thumbYScale)

		local hoveredSlider = activeSliderController or findCursorSlider()
		local isHovered = hoveredSlider == self
		local hoverAlpha = 1 - math.exp(-hoverLerpSpeed * deltaTime)
		local targetScale = if isHovered
			then self.thumbBaseScale * hoverThumbScaleMultiplier
			else self.thumbBaseScale
		local targetTextColor = if isHovered then self.amountHoverColor else self.amountBaseColor
		self.thumbScale.Scale += (targetScale - self.thumbScale.Scale) * hoverAlpha
		self.amountLabel.TextColor3 = self.amountLabel.TextColor3:Lerp(targetTextColor, hoverAlpha)
	end)

	self.connections.gamepadInput = userInputService.InputBegan:Connect(function(inputObject: InputObject)
		if userInputService.PreferredInput ~= Enum.PreferredInput.Gamepad or findCursorSlider() ~= self then
			return
		end
		if activeSliderController and activeSliderController ~= self then
			return
		end

		local keyCode = inputObject.KeyCode
		if keyCode == Enum.KeyCode.ButtonA then
			self:startDrag()
			if activeSliderController == self then
				self:updateFromMousePosition(userInputService:GetMouseLocation().X)
			end
			return
		end

		if keyCode ~= Enum.KeyCode.DPadLeft and keyCode ~= Enum.KeyCode.DPadRight then
			return
		end

		local direction = if keyCode == Enum.KeyCode.DPadLeft then -1 else 1
		self:updateFromUserInput(self.__vars.currentValue + direction * gamepadStepPercent)
		self:confirmCurrentValue()
	end)

	self.connections.barInput = barFrame.InputBegan:Connect(function(inputObject: InputObject)
		local inputType = inputObject.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end

		self:startDrag()
		if activeSliderController == self then
			self:updateFromMousePosition(inputObject.Position.X)
		end
	end)

	self.connections.thumbInput = sliderThumb.InputBegan:Connect(function(inputObject: InputObject)
		local inputType = inputObject.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end

		self:startDrag()
	end)
end

function sliderSettingController.new(frame: Frame, settingDefinition: SliderSettingDefinition)
	local self = setmetatable({}, sliderSettingController)

	self.frame = frame
	self.settingDefinition = settingDefinition
	self.connections = {}
	self.__vars = table.clone(sliderSettingController.__vars)
	self.barFrame = nil
	self.sliderThumb = nil
	self.amountLabel = nil
	self.thumbScale = nil
	self.thumbBaseScale = nil
	self.amountBaseColor = nil
	self.amountHoverColor = nil
	self.thumbSpring = nil

	task.defer(function()
		if getmetatable(self) then
			self:init()
		end
	end)

	return self
end

function sliderSettingController:destroy()
	sliderControllers[self] = nil
	if activeSliderController == self then
		activeSliderController = nil
	end
	if self.thumbScale then
		self.thumbScale.Scale = self.thumbBaseScale
	end
	if self.amountLabel then
		self.amountLabel.TextColor3 = self.amountBaseColor
	end

	connectionUtilities.disconnectConnections(self.connections)
	table.clear(self)
	setmetatable(self, nil)
end

return sliderSettingController
