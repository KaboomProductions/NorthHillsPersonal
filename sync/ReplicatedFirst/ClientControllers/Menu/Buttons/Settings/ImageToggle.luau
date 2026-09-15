local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")

local settingButtonAnimator = require(script.Parent.Animation)
local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)

local transferSettingRemote = replicatedStorage.Communication.RemoteFunctions.TransferSetting

local player = players.LocalPlayer

local inactiveTransparency = 0.6

local imageToggleSettingController = {}
imageToggleSettingController.__index = imageToggleSettingController
imageToggleSettingController.__vars = {
	currentValue = false,
}

export type ImageToggleSettingDefinition = {
	settingType: string?,
	categoryId: string,
	default: boolean?,
	imageData: { [string]: string }?,
}

function imageToggleSettingController:getCurrentValue(): boolean
	local settingsFolder = player:WaitForChild("Settings", 5)
	local categoryFolder = settingsFolder and settingsFolder:WaitForChild(self.settingDefinition.categoryId, 5)
	local valueInstance = categoryFolder and categoryFolder:WaitForChild(self.frame.Name, 5)

	if valueInstance then
		return valueInstance.Value
	end

	return self.settingDefinition.default or false
end

function imageToggleSettingController:updateDisplay(isEnabled: boolean)
	local buttonsFrame = self.frame.Buttons
	local onFrame = buttonsFrame:FindFirstChild("On")
	local offFrame = buttonsFrame:FindFirstChild("Off")
	local buttonAnimators = self.buttonAnimators

	self.__vars.currentValue = isEnabled

	if onFrame and buttonAnimators[onFrame] then
		buttonAnimators[onFrame]:setActive(isEnabled, isEnabled)
	end

	if offFrame and buttonAnimators[offFrame] then
		buttonAnimators[offFrame]:setActive(not isEnabled, isEnabled)
	end
end

function imageToggleSettingController:handleChange(buttonFrame: Frame)
	local buttonsFrame = buttonFrame.Parent
	local onFrame = buttonsFrame:FindFirstChild("On")
	local offFrame = buttonsFrame:FindFirstChild("Off")
	local buttonAnimators = self.buttonAnimators

	self.clickSound:Play()

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playUiClick()
	end

	local requestedValue = buttonFrame.Name == "On"
	local confirmedValue = transferSettingRemote:InvokeServer(self.settingDefinition, requestedValue)

	if confirmedValue ~= nil then
		self.__vars.currentValue = confirmedValue
	end

	local shouldSlideRight = buttonFrame.Name == "On"

	if onFrame and buttonAnimators[onFrame] then
		buttonAnimators[onFrame]:setActive(self.__vars.currentValue, shouldSlideRight)
	end

	if offFrame and buttonAnimators[offFrame] then
		buttonAnimators[offFrame]:setActive(not self.__vars.currentValue, shouldSlideRight)
	end
end

function imageToggleSettingController:preload()
	self.clickSound = workspace
		:WaitForChild("Audio")
		:WaitForChild("Effects")
		:WaitForChild("Menu")
		:WaitForChild("Click")
end

function imageToggleSettingController:init()
	self:preload()
	if getmetatable(self) == nil then
		return
	end

	local buttonsFrame = self.frame:WaitForChild("Buttons", 3)
	local connections = self.connections
	local buttonAnimators = self.buttonAnimators
	local imagesByOption = self.settingDefinition.imageData

	for _, buttonFrame in buttonsFrame:GetChildren() do
		local actualButton = buttonFrame:FindFirstChild("Button") :: ImageButton?

		if not buttonFrame:IsA("Frame") or not actualButton then
			continue
		end

		if imagesByOption and imagesByOption[buttonFrame.Name] then
			actualButton.Image = imagesByOption[buttonFrame.Name]
		end

		buttonAnimators[buttonFrame] = settingButtonAnimator.new({
			scaleInstance = buttonFrame,
			inputButton = actualButton,
			gradientHost = buttonFrame:FindFirstChild("Border") :: GuiObject?,
			inactiveTransparency = inactiveTransparency,
		})

		connections[buttonFrame.Name] = actualButton.Activated:Connect(function()
			local requestedValue = buttonFrame.Name == "On"

			if self.__vars.currentValue == requestedValue then
				return
			end

			self:handleChange(buttonFrame)
		end)
	end

	self:updateDisplay(self:getCurrentValue())
end

function imageToggleSettingController.new(frame: Frame, settingDefinition: ImageToggleSettingDefinition)
	local self = setmetatable({}, imageToggleSettingController)

	self.frame = frame
	self.settingDefinition = settingDefinition
	self.buttonAnimators = {}
	self.connections = {}
	self.clickSound = nil
	self.__vars = table.clone(imageToggleSettingController.__vars)

	task.defer(function()
		if getmetatable(self) then
			self:init()
		end
	end)

	return self
end

function imageToggleSettingController:destroy()
	connectionUtilities.disconnectConnections(self.connections)

	for buttonFrame, animator in self.buttonAnimators do
		animator:destroy()
		self.buttonAnimators[buttonFrame] = nil
	end

	table.clear(self)
	setmetatable(self, nil)
end

return imageToggleSettingController
