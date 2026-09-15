local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")

local settingButtonAnimator = require(script.Parent.Animation)
local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)

local transferSettingRemote = replicatedStorage.Communication.RemoteFunctions.TransferSetting

local player = players.LocalPlayer

local inactiveTransparency = 0.7

local toggleSettingController = {}
toggleSettingController.__index = toggleSettingController
toggleSettingController.__vars = {
	currentValue = false,
}

type SettingValue = boolean | number | string

export type ToggleOption = {
	name: string,
	value: SettingValue,
}

export type ToggleSettingDefinition = {
	settingType: string,
	categoryId: string,
	default: SettingValue?,
	options: { ToggleOption }?,
}

local defaultOptions: { ToggleOption } = {
	{ name = "On", value = true },
	{ name = "Off", value = false },
}

function toggleSettingController:getOptions(): { ToggleOption }
	return self.settingDefinition.options or defaultOptions
end

function toggleSettingController:getOptionForSlot(slotName: string): ToggleOption?
	local options = self:getOptions()

	if slotName == "On" then
		return options[1]
	end

	if slotName == "Off" then
		return options[2]
	end

	return nil
end

function toggleSettingController:getCurrentValue(): SettingValue
	local settingsFolder = player:WaitForChild("Settings", 5)
	local categoryFolder = settingsFolder and settingsFolder:WaitForChild(self.settingDefinition.categoryId, 5)
	local valueInstance = categoryFolder and categoryFolder:WaitForChild(self.frame.Name, 5)

	if valueInstance then
		return valueInstance.Value
	end

	return self.settingDefinition.default or false
end

function toggleSettingController:updateDisplay(settingValue: SettingValue)
	local buttonsFrame = self.frame.Buttons
	local buttonAnimators = self.buttonAnimators
	local onOption = self:getOptionForSlot("On")
	local shouldSlideRight = onOption ~= nil and settingValue == onOption.value

	self.__vars.currentValue = settingValue

	for _, slotName in { "On", "Off" } do
		local button = buttonsFrame:FindFirstChild(slotName) :: ImageButton?
		local option = self:getOptionForSlot(slotName)
		local animator = button and buttonAnimators[button]

		if animator and option then
			animator:setActive(option.value == settingValue, shouldSlideRight)
		end
	end
end

function toggleSettingController:applyLabels()
	local buttonsFrame = self.frame.Buttons

	for _, slotName in { "On", "Off" } do
		local button = buttonsFrame:FindFirstChild(slotName) :: ImageButton?
		local option = self:getOptionForSlot(slotName)

		if not button or not option then
			continue
		end

		local label = button:FindFirstChildWhichIsA("TextLabel") or (button:IsA("TextButton") and button)

		if label then
			label.Text = string.upper(option.name)
		end
	end
end

function toggleSettingController:handleChange(button: ImageButton)
	local buttonsFrame = button.Parent
	local buttonAnimators = self.buttonAnimators
	local selectedOption = self:getOptionForSlot(button.Name)
	if not selectedOption then
		return
	end

	self.clickSound:Play()

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playUiClick()
	end

	local confirmedValue = transferSettingRemote:InvokeServer(self.settingDefinition, selectedOption.value)

	if confirmedValue ~= nil then
		self.__vars.currentValue = confirmedValue
	end

	local shouldSlideRight = button.Name == "On"

	for _, slotName in { "On", "Off" } do
		local optionButton = buttonsFrame:FindFirstChild(slotName) :: ImageButton?
		local option = self:getOptionForSlot(slotName)
		local animator = optionButton and buttonAnimators[optionButton]

		if animator and option then
			animator:setActive(option.value == self.__vars.currentValue, shouldSlideRight)
		end
	end
end

function toggleSettingController:preload()
	self.clickSound = workspace
		:WaitForChild("Audio")
		:WaitForChild("Effects")
		:WaitForChild("Menu")
		:WaitForChild("Click")
end

function toggleSettingController:init()
	self:preload()
	if getmetatable(self) == nil then
		return
	end

	local buttonsFrame = self.frame:WaitForChild("Buttons", 3)
	local connections = self.connections
	local buttonAnimators = self.buttonAnimators

	self:applyLabels()

	for _, button in buttonsFrame:GetChildren() do
		if not button:IsA("ImageButton") then
			continue
		end

		buttonAnimators[button] = settingButtonAnimator.new({
			scaleInstance = button,
			inputButton = button,
			gradientHost = button,
			inactiveTransparency = inactiveTransparency,
		})

		connections[button.Name] = button.Activated:Connect(function()
			local option = self:getOptionForSlot(button.Name)
			if not option then
				return
			end

			if self.__vars.currentValue == option.value then
				return
			end

			self:handleChange(button)
		end)
	end

	self:updateDisplay(self:getCurrentValue())
end

function toggleSettingController.new(frame: Frame, settingDefinition: ToggleSettingDefinition)
	local self = setmetatable({}, toggleSettingController)

	self.frame = frame
	self.settingDefinition = settingDefinition
	self.buttonAnimators = {}
	self.connections = {}
	self.clickSound = nil
	self.__vars = table.clone(toggleSettingController.__vars)

	task.defer(function()
		if getmetatable(self) then
			self:init()
		end
	end)

	return self
end

function toggleSettingController:destroy()
	connectionUtilities.disconnectConnections(self.connections)

	for button, animator in self.buttonAnimators do
		animator:destroy()
		self.buttonAnimators[button] = nil
	end

	table.clear(self)
	setmetatable(self, nil)
end

return toggleSettingController
