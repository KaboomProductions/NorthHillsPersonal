local proximityPromptService = game:GetService("ProximityPromptService")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")

local guiAnimatorModule = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)
local promptInputDisplay = require(script.InputDisplay)

local player = players.LocalPlayer

local idleSize = UDim2.fromScale(0, 0)
local idleProgressSize = UDim2.fromScale(0.8, 0)
local idleTextSize = UDim2.fromScale(0.8, 0.8)
local idleInteractionSize = UDim2.fromScale(0.2, 0.2)
local idleShadowSize = UDim2.fromScale(1, 1)
local holdProgressSize = UDim2.fromScale(0.8, 0.9)
local holdTextSize = UDim2.fromScale(0.5, 0.5)
local holdShadowSize = UDim2.fromScale(1.1, 1.1)

local promptInputTypesByUserInputType = {
	[Enum.UserInputType.Keyboard] = Enum.ProximityPromptInputType.Keyboard,
	[Enum.UserInputType.MouseButton1] = Enum.ProximityPromptInputType.Keyboard,
	[Enum.UserInputType.MouseButton2] = Enum.ProximityPromptInputType.Keyboard,
	[Enum.UserInputType.MouseButton3] = Enum.ProximityPromptInputType.Keyboard,
	[Enum.UserInputType.MouseMovement] = Enum.ProximityPromptInputType.Keyboard,
	[Enum.UserInputType.MouseWheel] = Enum.ProximityPromptInputType.Keyboard,
	[Enum.UserInputType.Gamepad1] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Gamepad2] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Gamepad3] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Gamepad4] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Gamepad5] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Gamepad6] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Gamepad7] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Gamepad8] = Enum.ProximityPromptInputType.Gamepad,
	[Enum.UserInputType.Touch] = Enum.ProximityPromptInputType.Touch,
}

local promptController = {}
promptController.__index = promptController
promptController.__vars = {
	currentInputType = Enum.ProximityPromptInputType.Keyboard,
	idleSizePixels = 150,
	holdSizePixels = 200,
	transitionLerpSpeed = 12,
	progressResetSpeed = 6,
	shadowLerpSpeed = 4,
	destroyDelaySeconds = 0.5,

	springFrequency = 15,
	springDamping = 100,
	springMass = 3.5,
	springSpeed = 3.5,
	fadeTransparencySpeed = 20,
}

export type PromptSession = {
	prompt: ProximityPrompt,
	billboard: BillboardGui,
	button: TextButton,
	canvasGroup: CanvasGroup,
	progressBar: Frame,
	inputDisplay: promptInputDisplay.InputDisplay,
	triggeredShadow: ImageLabel,
	interactionIcon: ImageLabel,
	interactionIconSize: UDim2,
	animator: typeof(guiAnimatorModule.new(nil :: any)),
	connections: { [string]: RBXScriptConnection },
	isCleaned: boolean,
	isTriggered: boolean,
}

function promptController:createBillboard(prompt: ProximityPrompt, promptType: string?): PromptSession?
	local billboard = self.interactTemplate:Clone()
	billboard.Size = idleSize
	billboard.Parent = self.promptsFolder
	billboard.Adornee = prompt.Parent

	local button = billboard:FindFirstChild("Button") :: TextButton
	if not button then
		billboard:Destroy()
		return nil
	end

	local canvasGroup = button:FindFirstChildWhichIsA("CanvasGroup") :: CanvasGroup
	if not canvasGroup then
		billboard:Destroy()
		return nil
	end

	local progressBar = canvasGroup:FindFirstChild("Progress") :: Frame
	local keyLabel = canvasGroup:FindFirstChild("KeyText") :: TextLabel
	local triggeredShadow = canvasGroup:FindFirstChild("TriggeredShadows") :: ImageLabel
	local interactionFolder = canvasGroup:FindFirstChild("Interaction")
	local interactionIcon = (
		interactionFolder
		and (
			(promptType and interactionFolder:FindFirstChild(promptType))
			or interactionFolder:FindFirstChild("Interact")
		)
	) :: ImageLabel

	if not (progressBar and keyLabel and triggeredShadow and interactionIcon) then
		billboard:Destroy()
		return nil
	end

	return {
		prompt = prompt,
		billboard = billboard,
		button = button,
		canvasGroup = canvasGroup,
		progressBar = progressBar,
		inputDisplay = promptInputDisplay.create(keyLabel),
		triggeredShadow = triggeredShadow,
		interactionIcon = interactionIcon,
		interactionIconSize = interactionIcon.Size,
		animator = nil :: any,
		connections = {},
		isCleaned = false,
		isTriggered = false,
	}
end

function promptController:setupAnimator(session: PromptSession)
	local stateValues = self.__vars
	local animator = guiAnimatorModule.new(session.billboard :: any)
	local progressBar = session.progressBar
	local inputDisplayContainer = session.inputDisplay.container
	local triggeredShadow = session.triggeredShadow
	local interactionIcon = session.interactionIcon
	local transitionSpeed = stateValues.transitionLerpSpeed

	animator:addSpring(
		"billboardSpring",
		Vector2.zero,
		stateValues.springFrequency,
		stateValues.springDamping,
		stateValues.springMass,
		stateValues.springSpeed
	)
	animator:addSizeSpringTrack("billboardSize", session.billboard :: any, "Size", "billboardSpring", true)

	animator:addSizeLerpTrack(
		"progressReset",
		progressBar,
		"Size",
		idleProgressSize,
		idleProgressSize,
		stateValues.progressResetSpeed
	)

	animator:addTimedLerpTrack("progressFill", function(easedAlpha: number)
		progressBar.Size = idleProgressSize:Lerp(holdProgressSize, easedAlpha)
	end, 1, "quad", "in")
	animator:pauseTrack("progressFill")

	animator:addSizeLerpTrack(
		"inputDisplaySize",
		inputDisplayContainer,
		"Size",
		idleTextSize,
		idleTextSize,
		transitionSpeed
	)
	animator:addSizeLerpTrack(
		"shadowSize",
		triggeredShadow,
		"Size",
		idleShadowSize,
		idleShadowSize,
		stateValues.shadowLerpSpeed
	)
	animator:addSizeLerpTrack(
		"interactionSize",
		interactionIcon,
		"Size",
		idleInteractionSize,
		idleInteractionSize,
		transitionSpeed
	)

	animator:addNumberLerpTrack("inputDisplayTransparency", function(transparency: number)
		inputDisplayContainer.GroupTransparency = transparency
	end, 0, 0, transitionSpeed)

	animator:addNumberLerpTrack("interactionTransparency", function(transparency: number)
		interactionIcon.ImageTransparency = transparency
	end, 1, 1, transitionSpeed)

	local canvasGroup = session.canvasGroup
	canvasGroup.GroupTransparency = 1
	animator:addNumberLerpTrack("fadeTransparency", function(transparency: number)
		canvasGroup.GroupTransparency = transparency
	end, 1, 0, stateValues.fadeTransparencySpeed)

	session.animator = animator
end

function promptController:applyIdleState(session: PromptSession)
	local stateValues = self.__vars
	local animator = session.animator
	local idlePixels = stateValues.idleSizePixels

	animator:setSpring("billboardSpring", Vector2.new(idlePixels, idlePixels))

	animator:pauseTrack("progressFill")
	animator:snapSizeLerp("progressReset", session.progressBar.Size)
	animator:setSizeLerpTarget("progressReset", idleProgressSize)
	animator:resumeTrack("progressReset")

	animator:setSizeLerpTarget("inputDisplaySize", idleTextSize)
	animator:setSizeLerpTarget("shadowSize", idleShadowSize)
	animator:setSizeLerpTarget("interactionSize", idleInteractionSize)
	animator:setNumberLerpTarget("inputDisplayTransparency", 0)
	animator:setNumberLerpTarget("interactionTransparency", 1)
end

function promptController:applyHoldState(session: PromptSession)
	local stateValues = self.__vars
	local animator = session.animator
	local holdPixels = stateValues.holdSizePixels

	animator:setSpring("billboardSpring", Vector2.new(holdPixels, holdPixels))

	animator:pauseTrack("progressReset")
	animator:restartTimedLerp("progressFill", session.prompt.HoldDuration, "quad", "in")
	animator:resumeTrack("progressFill")

	animator:setSizeLerpTarget("inputDisplaySize", holdTextSize)
	animator:setSizeLerpTarget("shadowSize", holdShadowSize)
	animator:setSizeLerpTarget("interactionSize", session.interactionIconSize)
	animator:setNumberLerpTarget("inputDisplayTransparency", 1)
	animator:setNumberLerpTarget("interactionTransparency", 0)
end

function promptController:cleanupSession(session: PromptSession)
	if session.isCleaned then
		return
	end

	session.isCleaned = true
	local stateValues = self.__vars
	local animator = session.animator
	local billboard = session.billboard

	animator:configureSpring("billboardSpring", nil, 1, nil, nil)
	animator:setSpring("billboardSpring", Vector2.zero)
	animator:setNumberLerpTarget("fadeTransparency", 1)

	for connectionName, connection in session.connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
		session.connections[connectionName] = nil
	end

	task.delay(stateValues.destroyDelaySeconds, function()
		if self.sessions[session.prompt] == session then
			self.sessions[session.prompt] = nil
		end

		if animator then
			animator:destroy()
		end

		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)
end

function promptController:bindClickablePrompt(
	session: PromptSession,
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType
)
	if not (inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt) then
		return
	end

	local isButtonDown = false
	local button = session.button

	session.connections.buttonInputBegan = button.InputBegan:Connect(function(input: InputObject)
		local userInputType = input.UserInputType
		if
			(userInputType == Enum.UserInputType.Touch or userInputType == Enum.UserInputType.MouseButton1)
			and input.UserInputState ~= Enum.UserInputState.Change
		then
			prompt:InputHoldBegin()
			isButtonDown = true
		end
	end)

	session.connections.buttonInputEnded = button.InputEnded:Connect(function(input: InputObject)
		local userInputType = input.UserInputType
		if
			(userInputType == Enum.UserInputType.Touch or userInputType == Enum.UserInputType.MouseButton1)
			and isButtonDown
		then
			isButtonDown = false
			prompt:InputHoldEnd()
		end
	end)
end

function promptController:onPromptShown(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style == Enum.ProximityPromptStyle.Default then
		return
	end

	local existingSession = self.sessions[prompt]
	if existingSession then
		self:cleanupSession(existingSession)
	end

	local promptType = prompt:GetAttribute("PromptType")
	local session = self:createBillboard(prompt, promptType)
	if not session then
		return
	end

	self:setupAnimator(session)
	self.sessions[prompt] = session
	promptInputDisplay.update(session.inputDisplay, prompt, self.__vars.currentInputType)

	self:bindClickablePrompt(session, prompt, inputType)

	session.connections.holdBegan = prompt.PromptButtonHoldBegan:Connect(function()
		self:applyHoldState(session)
	end)

	session.connections.holdEnded = prompt.PromptButtonHoldEnded:Connect(function()
		self:applyIdleState(session)
	end)

	session.connections.triggered = prompt.Triggered:Connect(function()
		session.isTriggered = true
		local animator = session.animator
		animator:setSpring("billboardSpring", Vector2.zero)
		animator:setNumberLerpTarget("fadeTransparency", 1)
	end)

	session.connections.triggerEnded = prompt.TriggerEnded:Connect(function()
		session.isTriggered = false
		local animator = session.animator

		animator:snapNumberLerp("fadeTransparency", 1)

		animator:setNumberLerpTarget("fadeTransparency", 0)
		self:applyIdleState(session)
	end)

	session.connections.hidden = prompt.PromptHidden:Connect(function()
		self:cleanupSession(session)
	end)

	self:applyIdleState(session)
end

function promptController:updateInputDisplays(inputType: Enum.ProximityPromptInputType)
	for _, session in self.sessions do
		promptInputDisplay.update(session.inputDisplay, session.prompt, inputType)
	end
end

function promptController:onLastInputTypeChanged(userInputType: Enum.UserInputType)
	local inputType = promptInputTypesByUserInputType[userInputType]
	if not inputType then
		return
	end

	self.__vars.currentInputType = inputType
	self:updateInputDisplays(inputType)
end

function promptController:onGamepadConnectionChanged()
	if self.__vars.currentInputType ~= Enum.ProximityPromptInputType.Gamepad then
		return
	end

	self:updateInputDisplays(Enum.ProximityPromptInputType.Gamepad)
end

function promptController:updateSessions(deltaTime: number)
	for _, session in self.sessions do
		session.animator:applyTracks(deltaTime)
	end
end

function promptController:preload()
	local playerGui = player:WaitForChild("PlayerGui")
	local interface = playerGui:WaitForChild("Interface")
	local sharedAssets = replicatedStorage:WaitForChild("SharedAssets")
	local effects = sharedAssets:WaitForChild("Effects")
	local interfaceFolder = effects:WaitForChild("Interface")

	self.promptsFolder = interface:WaitForChild("Prompts")
	self.interactTemplate = interfaceFolder:WaitForChild("Interact")
end

function promptController:init()
	self:preload()
	self:onLastInputTypeChanged(userInputService:GetLastInputType())

	self.connections.promptShown = proximityPromptService.PromptShown:Connect(function(prompt, inputType)
		self:onPromptShown(prompt, inputType)
	end)

	self.connections.renderStep = runService.RenderStepped:Connect(function(deltaTime: number)
		self:updateSessions(deltaTime)
	end)

	self.connections.lastInputTypeChanged = userInputService.LastInputTypeChanged:Connect(function(userInputType: Enum.UserInputType)
		self:onLastInputTypeChanged(userInputType)
	end)

	self.connections.gamepadConnected = userInputService.GamepadConnected:Connect(function()
		self:onGamepadConnectionChanged()
	end)

	self.connections.gamepadDisconnected = userInputService.GamepadDisconnected:Connect(function()
		self:onGamepadConnectionChanged()
	end)
end

function promptController.new()
	local self = setmetatable({}, promptController)
	self.__vars = table.clone(promptController.__vars)

	self.connections = {}
	self.sessions = {}
	self.promptsFolder = nil
	self.interactTemplate = nil

	task.defer(self.init, self)

	return self
end

function promptController:destroy()
	for _, session in self.sessions do
		self:cleanupSession(session)
	end

	for _, connection in self.connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	table.clear(self.connections)
	table.clear(self.sessions)
	table.clear(self)
	setmetatable(self, nil)
end

return promptController
