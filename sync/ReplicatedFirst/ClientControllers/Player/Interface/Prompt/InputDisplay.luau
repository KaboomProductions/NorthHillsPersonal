local userInputService = game:GetService("UserInputService")

local controllerIconSize = UDim2.fromScale(0.8, 0.8)
local touchIconSize = UDim2.fromScale(0.65, 0.8)
local touchTapImage = "rbxasset://textures/ui/Controls/TouchTapIcon.png"

local promptInputDisplay = {}

export type InputDisplay = {
	container: CanvasGroup,
	inputImage: ImageLabel,
	keyLabel: TextLabel,
}

local function createContainer(keyLabel: TextLabel): CanvasGroup
	local container = Instance.new("CanvasGroup")
	container.Name = "InputDisplay"
	container.AnchorPoint = keyLabel.AnchorPoint
	container.BackgroundTransparency = 1
	container.Position = keyLabel.Position
	container.Size = keyLabel.Size
	container.ZIndex = keyLabel.ZIndex
	container.Parent = keyLabel.Parent

	return container
end

local function createInputImage(container: CanvasGroup, zIndex: number): ImageLabel
	local inputImage = Instance.new("ImageLabel")
	inputImage.Name = "InputImage"
	inputImage.AnchorPoint = Vector2.new(0.5, 0.5)
	inputImage.BackgroundTransparency = 1
	inputImage.Position = UDim2.fromScale(0.5, 0.5)
	inputImage.ScaleType = Enum.ScaleType.Fit
	inputImage.Size = controllerIconSize
	inputImage.Visible = false
	inputImage.ZIndex = zIndex
	inputImage.Parent = container

	return inputImage
end

function promptInputDisplay.create(keyLabel: TextLabel): InputDisplay
	local keyLabelZIndex = keyLabel.ZIndex
	local container = createContainer(keyLabel)

	keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	keyLabel.Position = UDim2.fromScale(0.5, 0.5)
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.Parent = container

	return {
		container = container,
		inputImage = createInputImage(container, keyLabelZIndex),
		keyLabel = keyLabel,
	}
end

function promptInputDisplay.update(
	display: InputDisplay,
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType
)
	local inputImage = display.inputImage
	local keyLabel = display.keyLabel
	local isUsingController = inputType == Enum.ProximityPromptInputType.Gamepad
	local isUsingTouch = inputType == Enum.ProximityPromptInputType.Touch

	if isUsingTouch then
		inputImage.Image = touchTapImage
		inputImage.Size = touchIconSize
		inputImage.Visible = true
		keyLabel.Visible = false
		return
	end

	if not isUsingController then
		keyLabel.Text = prompt.KeyboardKeyCode.Name
		keyLabel.Visible = true
		inputImage.Visible = false
		return
	end

	inputImage.Image = userInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
	inputImage.Size = controllerIconSize
	inputImage.Visible = inputImage.Image ~= ""
	keyLabel.Visible = not inputImage.Visible

	if keyLabel.Visible then
		keyLabel.Text = prompt.GamepadKeyCode.Name
	end
end

return promptInputDisplay
