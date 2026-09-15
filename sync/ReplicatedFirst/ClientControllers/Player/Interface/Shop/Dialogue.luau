local replicatedStorage = game:GetService("ReplicatedStorage")

local guiAnimatorModule = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)

local dialogueConfig = {
	typeCharsPerSecond = 50,
	backspaceCharsPerSecond = 150,
	choiceDelayAfterText = 0.15,
	playerLineReadDelay = 1.2,
	idleTimeout = 10,
	scaleLerpSpeed = 18,
	clickScaleLerpSpeed = 30,
	hoverScale = 1.05,
	clickScale = 0.95,
	positionLerpSpeed = 8,
	referenceHeight = 1080,
}

local dialogueController = {}
dialogueController.__index = dialogueController

local function scaleTrackKey(button: ImageButton): string
	return "dialogueChoiceScale_" .. button.Name
end

local function getOrCreateButtonScale(button: ImageButton): UIScale
	local existingScale = button:FindFirstChildOfClass("UIScale")
	if existingScale then
		return existingScale
	end

	local newScale = Instance.new("UIScale")
	newScale.Scale = 1
	newScale.Parent = button
	return newScale
end

local function setChoiceVisible(button: ImageButton, isVisible: boolean)
	local transparency = isVisible and 0 or 1
	button.ImageTransparency = transparency

	local textChild = button:FindFirstChild("Text")
	if textChild and textChild:IsA("TextLabel") then
		textChild.TextTransparency = transparency
	end
end

function dialogueController.new(context)
	local self = setmetatable({}, dialogueController)

	self.context = context
	self.animator = guiAnimatorModule.new(context.dialogue.frame)
	self.connections = {}
	self.actionHandlers = {}
	self.currentChoices = {}
	self.currentNpcId = nil
	self.dialogueThread = nil
	self.idleThread = nil
	self.sequenceGeneration = 0
	self.textSizeEntries = {}
	self.active = false
	self.queued = false

	self:initialize()

	return self
end

function dialogueController:onAction(actionName: string, handler: () -> ())
	self.actionHandlers[actionName] = handler
end

function dialogueController:fireAction(actionName: string)
	local handler = self.actionHandlers[actionName]
	if handler then
		handler()
	end
end

function dialogueController:isActive(): boolean
	return self.active
end

function dialogueController:isQueued(): boolean
	return self.queued
end

function dialogueController:getChoiceButtons(): { ImageButton }
	return self.context.dialogue.choiceButtons
end

function dialogueController:updateTextSizes()
	local currentCamera = workspace.CurrentCamera
	if currentCamera == nil then
		return
	end

	local scaleFactor = currentCamera.ViewportSize.Y / dialogueConfig.referenceHeight
	for _, textSizeEntry in ipairs(self.textSizeEntries) do
		textSizeEntry.label.TextScaled = false
		textSizeEntry.label.TextSize = math.round(textSizeEntry.baseSize * scaleFactor)
	end
end

function dialogueController:cancelIdleTimer()
	if self.idleThread ~= nil then
		task.cancel(self.idleThread)
		self.idleThread = nil
	end
end

function dialogueController:startIdleTimer()
	self:cancelIdleTimer()

	self.idleThread = task.delay(dialogueConfig.idleTimeout, function()
		self.idleThread = nil
		if not self.active then
			return
		end

		self:fireAction("dialogueIdle")
	end)
end

function dialogueController:stopDialogueSequence()
	if self.dialogueThread ~= nil then
		task.cancel(self.dialogueThread)
		self.dialogueThread = nil
	end
end

function dialogueController:typewriteLabel(label: TextLabel, text: string, charsPerSecond: number)
	label.Text = text
	label.MaxVisibleGraphemes = 0

	local graphemeCount = utf8.len(text) or #text
	local progress = 0

	while progress < graphemeCount do
		if not self.active then
			return
		end

		local deltaTime = task.wait()
		progress = math.min(progress + charsPerSecond * deltaTime, graphemeCount)
		label.MaxVisibleGraphemes = math.floor(progress)
	end

	label.MaxVisibleGraphemes = -1
end

function dialogueController:backspaceLabel(label: TextLabel, charsPerSecond: number)
	local text = label.Text
	local graphemeCount = utf8.len(text) or #text
	if graphemeCount == 0 then
		return
	end

	local progress = graphemeCount
	label.MaxVisibleGraphemes = graphemeCount

	while progress > 0 do
		if not self.active then
			return
		end

		local deltaTime = task.wait()
		progress = math.max(progress - charsPerSecond * deltaTime, 0)
		label.MaxVisibleGraphemes = math.floor(progress)
	end

	label.Text = ""
	label.MaxVisibleGraphemes = -1
end

function dialogueController:startDialogueSequence(nameText: string, bodyText: string, onComplete: (() -> ())?)
	self:stopDialogueSequence()
	self:cancelIdleTimer()

	self.sequenceGeneration += 1
	local generation = self.sequenceGeneration

	local npcNameLabel = self.context.dialogue.npcNameLabel
	local textLabel = self.context.dialogue.textLabel

	self.dialogueThread = task.spawn(function()
		if #textLabel.Text > 0 then
			self:backspaceLabel(textLabel, dialogueConfig.backspaceCharsPerSecond)
			if not self.active or self.sequenceGeneration ~= generation then
				return
			end
		end

		if #npcNameLabel.Text > 0 then
			self:backspaceLabel(npcNameLabel, dialogueConfig.backspaceCharsPerSecond)
			if not self.active or self.sequenceGeneration ~= generation then
				return
			end
		end

		self:typewriteLabel(npcNameLabel, nameText, dialogueConfig.typeCharsPerSecond)
		if not self.active or self.sequenceGeneration ~= generation then
			return
		end

		self:typewriteLabel(textLabel, bodyText, dialogueConfig.typeCharsPerSecond)
		if not self.active or self.sequenceGeneration ~= generation then
			return
		end

		self.dialogueThread = nil

		if onComplete then
			onComplete()
		end

		self:startIdleTimer()
	end)
end

function dialogueController:getChoiceAreaHeight(): number
	local choiceButtons = self:getChoiceButtons()
	local buttonHeight = choiceButtons[1].AbsoluteSize.Y
	if buttonHeight < 1 then
		return 0
	end

	local dialogueFrame = self.context.dialogue.frame
	local dialogueBox = self.context.dialogue.dialogueBox
	local gap = dialogueFrame.AbsoluteSize.Y - dialogueBox.AbsoluteSize.Y - buttonHeight

	return buttonHeight + math.max(gap, 0)
end

function dialogueController:shiftChoicesDown()
	self.animator:setNumberLerpTarget("dialogueYOffset", self:getChoiceAreaHeight())
end

function dialogueController:shiftChoicesUp()
	self.animator:setNumberLerpTarget("dialogueYOffset", 0)
end

function dialogueController:hideChoices()
	for _, button in ipairs(self:getChoiceButtons()) do
		setChoiceVisible(button, false)
		self.animator:snapNumberLerp(scaleTrackKey(button), 1)
	end

	self:shiftChoicesDown()
end

function dialogueController:showChoices()
	self:shiftChoicesUp()

	for index, button in ipairs(self:getChoiceButtons()) do
		local choice = self.currentChoices[index]
		if choice == nil then
			setChoiceVisible(button, false)
			continue
		end

		local textChild = button:FindFirstChild("Text")
		if textChild and textChild:IsA("TextLabel") then
			textChild.Text = choice.text or ""
		end

		task.delay(dialogueConfig.choiceDelayAfterText * index, function()
			if self.active then
				setChoiceVisible(button, true)
			end
		end)
	end
end

function dialogueController:displayResponse(responseData)
	self.currentNpcId = responseData.npcId
	self.currentChoices = responseData.choices or {}

	if responseData.promoted then
		self.queued = false
		self:fireAction("promoted")
	end

	if responseData.queued then
		self.queued = true
		self:fireAction("queued")
	end

	local hasNpcText = type(responseData.text) == "string" and #responseData.text > 0
	local hasPlayerLine = type(responseData.playerLine) == "string" and #responseData.playerLine > 0

	if hasNpcText or hasPlayerLine then
		self:fireAction("dialogueStarted")
	end

	if type(responseData.action) == "string" then
		self:fireAction(responseData.action)
	end

	if not hasNpcText and not hasPlayerLine then
		return
	end

	if #self.currentChoices > 0 then
		self:hideChoices()
	end

	local function showNpcResponse()
		self:startDialogueSequence(responseData.npcName or "", responseData.text or "", function()
			if self.active and #self.currentChoices > 0 then
				self:showChoices()
			end
		end)
	end

	if hasPlayerLine and responseData.playerName then
		local generation = self.sequenceGeneration + 1
		self:startDialogueSequence(responseData.playerName, responseData.playerLine, function()
			if not self.active or self.sequenceGeneration ~= generation then
				return
			end

			task.delay(dialogueConfig.playerLineReadDelay, function()
				if self.active and self.sequenceGeneration == generation then
					showNpcResponse()
				end
			end)
		end)
		return
	end

	showNpcResponse()
end

function dialogueController:resetDialogueState()
	self.queued = false
	self.currentNpcId = nil
	self.currentChoices = {}
	self.context.dialogue.textLabel.Text = ""
	self.context.dialogue.npcNameLabel.Text = ""
	self:hideChoices()
end

function dialogueController:request(npcId: string)
	self.active = true
	self:cancelIdleTimer()
	self:stopDialogueSequence()
	self:resetDialogueState()
	self.context.networking.events.requestDialogue:FireServer(npcId)
end

function dialogueController:close()
	if not self.active then
		return
	end

	self.active = false
	self:cancelIdleTimer()
	self:stopDialogueSequence()
	self:resetDialogueState()
	self.context.networking.events.closeDialogue:FireServer()
	self:fireAction("dialogueClosed")
end

function dialogueController:initializeChoiceButtons()
	for index, button in ipairs(self:getChoiceButtons()) do
		local uiScale = getOrCreateButtonScale(button)
		local trackName = scaleTrackKey(button)

		self.animator:addNumberLerpTrack(trackName, function(scale)
			uiScale.Scale = scale
		end, 1, 1, dialogueConfig.scaleLerpSpeed)

		table.insert(
			self.connections,
			button.MouseEnter:Connect(function()
				if not self.active then
					return
				end

				self.animator:setNumberLerpTarget(trackName, dialogueConfig.hoverScale)
			end)
		)

		table.insert(
			self.connections,
			button.MouseLeave:Connect(function()
				if not self.active then
					return
				end

				self.animator:setNumberLerpTarget(trackName, 1)
			end)
		)

		table.insert(
			self.connections,
			button.MouseButton1Down:Connect(function()
				if not self.active then
					return
				end

				self.animator:setNumberLerpTarget(
					trackName,
					dialogueConfig.clickScale,
					dialogueConfig.clickScaleLerpSpeed
				)
			end)
		)

		table.insert(
			self.connections,
			button.MouseButton1Up:Connect(function()
				if not self.active then
					return
				end

				self.animator:setNumberLerpTarget(trackName, dialogueConfig.hoverScale)
			end)
		)

		table.insert(
			self.connections,
			button.Activated:Connect(function()
				if not self.active then
					return
				end

				local choice = self.currentChoices[index]
				if choice ~= nil then
					self.context.networking.events.selectChoice:FireServer(choice.id)
				end
			end)
		)

		setChoiceVisible(button, false)
	end
end

function dialogueController:initialize()
	local dialogueBox = self.context.dialogue.dialogueBox
	local choiceButtons = self:getChoiceButtons()

	self.dialogueBoxBasePosition = dialogueBox.Position

	self.animator:addNumberLerpTrack("dialogueYOffset", function(yOffset)
		dialogueBox.Position = self.dialogueBoxBasePosition + UDim2.fromOffset(0, yOffset)
	end, 0, 0, dialogueConfig.positionLerpSpeed)

	self:initializeChoiceButtons()

	self.textSizeEntries = {
		{ label = self.context.dialogue.npcNameLabel, baseSize = 22 },
		{ label = self.context.dialogue.textLabel, baseSize = 18 },
	}

	for _, button in ipairs(choiceButtons) do
		local textChild = button:FindFirstChild("Text")
		if textChild and textChild:IsA("TextLabel") then
			table.insert(self.textSizeEntries, { label = textChild, baseSize = 16 })
		end
	end

	self:updateTextSizes()

	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		table.insert(
			self.connections,
			currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:updateTextSizes()
			end)
		)
	end

	table.insert(
		self.connections,
		self.context.networking.events.showDialogueResponse.OnClientEvent:Connect(function(responseData)
			if self.active then
				self:displayResponse(responseData)
			end
		end)
	)

	table.insert(
		self.connections,
		self.context.networking.events.forceCloseDialogue.OnClientEvent:Connect(
			function(npcId: string?, actionName: string?)
				if self.currentNpcId ~= npcId and npcId ~= nil then
					return
				end

				self.active = false
				self:cancelIdleTimer()
				self:stopDialogueSequence()
				self:resetDialogueState()

				if type(actionName) == "string" then
					self:fireAction(actionName)
				else
					self:fireAction("dialogueClosed")
				end
			end
		)
	)
end

function dialogueController:update(deltaTime: number)
	self.animator:applyTracks(deltaTime)
end

function dialogueController:destroy()
	self:cancelIdleTimer()
	self:stopDialogueSequence()

	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
	self.animator:destroy()

	setmetatable(self, nil)
end

return dialogueController
