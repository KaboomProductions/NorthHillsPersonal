local runService = game:GetService("RunService")

local mouseUnlock = require(script.Parent.MouseUnlock)

local contextModule = require(script.Context)
local dialogueControllerModule = require(script.Dialogue)
local mainPageControllerModule = require(script.MainPageController)
local optionRegistryModule = require(script.OptionRegistry)
local shopAnimator = require(script.Animator)

local zaraNpcId = "zara"

local shopController = {}
shopController.__index = shopController

local function getCharacterRootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	return character.PrimaryPart or character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getPromptWorldPosition(promptHolder: Instance): Vector3?
	if promptHolder:IsA("Attachment") then
		return promptHolder.WorldPosition
	end

	if promptHolder:IsA("BasePart") then
		return promptHolder.Position
	end

	return nil
end

function shopController.new()
	local self = setmetatable({}, shopController)

	self.context = contextModule.new()
	self.isOpen = false
	self.currentOptionId = nil
	self.currentOption = nil
	self.connections = {}
	self.mouseUnlockToken = nil

	self.dialogueController = dialogueControllerModule.new(self.context)
	self.optionRegistry = optionRegistryModule.new(script.Options, self.context.mainPage.optionButtons)
	self.mainPageController = mainPageControllerModule.new(self.context, {
		isShopOpen = function()
			return self.isOpen
		end,

		onCloseRequested = function()
			self:close()
		end,

		onOptionCloseRequested = function()
			self:closeCurrentOption()
		end,

		onOptionButtonActivated = function(optionId: string)
			self:handleOptionButtonActivated(optionId)
		end,
	})

	self.mainPageController:setButtonOptionIds(self.optionRegistry.buttonOptionIds)
	self:registerDialogueActions()
	self:bind()

	return self
end

function shopController:bind()
	local proximityPrompt = self.context.prompt.prompt

	table.insert(
		self.connections,
		proximityPrompt.Triggered:Connect(function()
			self:open()
		end)
	)

	runService:UnbindFromRenderStep("ShopInterfaceController")
	runService:BindToRenderStep(
		"ShopInterfaceController",
		Enum.RenderPriority.Camera.Value + 1,
		function(deltaTime: number)
			self:update(deltaTime)
		end
	)
end

function shopController:registerDialogueActions()
	for _, optionId in ipairs(self.optionRegistry:getOptionIds()) do
		self.dialogueController:onAction("open" .. optionId, function()
			self:openOption(optionId)
		end)
	end

	self.dialogueController:onAction("dialogueStarted", function()
		self:playAnimation("openDialogue")
	end)

	self.dialogueController:onAction("dialogueIdle", function()
		self:playAnimation("closeDialogue")
	end)

	self.dialogueController:onAction("closeShop", function()
		self:close()
	end)

	self.dialogueController:onAction("forceCloseShop", function()
		self:close()
	end)

	self.dialogueController:onAction("dialogueClosed", function()
		if not self.isOpen then
			return
		end

		if self.context.shopFrame.Visible and not self.context.mainPage.frame.Visible then
			return
		end

		self:close()
	end)
end

function shopController:playAnimation(animationName: string)
	local animation = shopAnimator[animationName]
	if type(animation) == "function" then
		animation()
	end
end

function shopController:createOptionContext()
	return {
		context = self.context,
		dialogueController = self.dialogueController,
		shopAnimator = shopAnimator,
	}
end

function shopController:handleOptionButtonActivated(optionId: string)
	if self.currentOptionId ~= nil then
		return
	end

	if self.dialogueController:isQueued() then
		self:openOption(optionId)
		return
	end

	self.context.networking.events.selectChoice:FireServer(string.lower(optionId))
end

function shopController:openOption(optionId: string)
	if not self.isOpen or self.currentOptionId ~= nil then
		return
	end

	local option = self.optionRegistry:createOption(optionId, self:createOptionContext())
	if option == nil then
		return
	end

	self.currentOptionId = optionId
	self.currentOption = option

	self.mainPageController:setSubpageOpen(true)
	self:playAnimation("open" .. optionId)
end

function shopController:destroyCurrentOption()
	local currentOption = self.currentOption
	if currentOption ~= nil and type(currentOption.destroy) == "function" then
		currentOption:destroy()
	end

	self.currentOption = nil
end

function shopController:closeCurrentOption()
	local currentOptionId = self.currentOptionId
	if currentOptionId == nil then
		return
	end

	self:destroyCurrentOption()
	self.currentOptionId = nil

	self.mainPageController:setSubpageOpen(false)
	self:playAnimation("close" .. currentOptionId)
end

function shopController:open()
	if self.isOpen or getCharacterRootPart(self.context.player) == nil then
		return
	end

	self.isOpen = true
	self.mouseUnlockToken = mouseUnlock.acquire("shop")
	self.context.prompt.prompt.Enabled = false

	self.mainPageController:setSubpageOpen(false)
	shopAnimator.preload()
	self:playAnimation("openShop")
	self.dialogueController:request(zaraNpcId)
end

function shopController:close()
	if not self.isOpen then
		return
	end

	self.isOpen = false
	mouseUnlock.release(self.mouseUnlockToken)
	self.mouseUnlockToken = nil
	self.context.prompt.prompt.Enabled = true

	if self.dialogueController:isActive() then
		self.dialogueController:close()
	end

	self:playAnimation("closeDialogue")
	self.mainPageController:resetOptionButtons()

	if self.currentOptionId ~= nil then
		local currentOptionId = self.currentOptionId
		self:destroyCurrentOption()
		self.currentOptionId = nil
		self.mainPageController:setSubpageOpen(false)
		self:playAnimation("close" .. currentOptionId)
		task.delay(0.8, function()
			self:playAnimation("closeShop")
		end)
		return
	end

	self:playAnimation("closeShop")
end

function shopController:updateDistanceCheck()
	local rootPart = getCharacterRootPart(self.context.player)
	local promptPosition = getPromptWorldPosition(self.context.prompt.holder)
	if rootPart == nil or promptPosition == nil then
		self:close()
		return
	end

	local maxDistance = self.context.prompt.prompt.MaxActivationDistance
	local currentDistance = (promptPosition - rootPart.Position).Magnitude

	if currentDistance > maxDistance then
		self:close()
	end
end

function shopController:update(deltaTime: number)
	self.mainPageController:update(deltaTime)
	self.dialogueController:update(deltaTime)
	shopAnimator.update(deltaTime)

	local currentOption = self.currentOption
	if currentOption ~= nil and type(currentOption.update) == "function" then
		currentOption:update(deltaTime)
	end

	if self.isOpen then
		self:updateDistanceCheck()
	end
end

function shopController:destroy()
	runService:UnbindFromRenderStep("ShopInterfaceController")

	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)

	self:destroyCurrentOption()
	self.dialogueController:destroy()
	self.mainPageController:destroy()
	shopAnimator.destroy()
	mouseUnlock.release(self.mouseUnlockToken)
	self.mouseUnlockToken = nil

	setmetatable(self, nil)
end

return shopController
