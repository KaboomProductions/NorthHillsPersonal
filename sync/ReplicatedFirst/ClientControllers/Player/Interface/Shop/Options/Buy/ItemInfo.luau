local itemInfoController = {}
itemInfoController.__index = itemInfoController

local statLerpSpeed = 3

local catalogByItemId = {}
local hasLoadedCatalog = false

local function getTextDisplay(container: Instance): TextLabel?
	local directText = container:FindFirstChild("Text")
	if directText and directText:IsA("TextLabel") then
		return directText
	end

	return container:FindFirstChildWhichIsA("TextLabel")
end

local function getStatGradient(statHolder: GuiObject): UIGradient?
	local background = statHolder:FindFirstChild("BG")
	if not background then
		return nil
	end

	local fill = background:FindFirstChild("Fill")
	if not fill then
		return nil
	end

	return fill:FindFirstChildOfClass("UIGradient")
end

local function setChoiceButtonVisible(button: ImageButton, isVisible: boolean)
	local transparency = isVisible and 0 or 1
	button.ImageTransparency = transparency

	local textChild = button:FindFirstChild("Text")
	if textChild and textChild:IsA("TextLabel") then
		textChild.TextTransparency = transparency
	end
end

local function updateStatGradient(statHolder: GuiObject, fillAmount: number)
	local gradient = getStatGradient(statHolder)
	if gradient == nil then
		return
	end

	local clampedFillAmount = math.clamp(fillAmount, 0, 1)
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(math.max(clampedFillAmount, 0.001), 0),
		NumberSequenceKeypoint.new(math.min(clampedFillAmount + 0.001, 1), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function clearStatGradient(statHolder: GuiObject)
	local gradient = getStatGradient(statHolder)
	if gradient ~= nil then
		gradient.Transparency = NumberSequence.new(1)
	end
end

local function loadCatalog(categoriesFolder: Instance)
	if hasLoadedCatalog then
		return
	end

	hasLoadedCatalog = true

	for _, categoryModule in ipairs(categoriesFolder:GetChildren()) do
		if not categoryModule:IsA("ModuleScript") then
			continue
		end

		local categoryData = require(categoryModule)
		for itemId, itemConfig in pairs(categoryData) do
			catalogByItemId[itemId] = itemConfig
		end
	end
end

function itemInfoController.new(optionContext)
	local self = setmetatable({}, itemInfoController)
	self.context = optionContext.context
	self.shopAnimator = optionContext.shopAnimator
	self.connections = {}
	self.statValues = {}
	self.statLerpThread = nil
	self.selectedItemId = nil
	self.selectedItemConfig = nil

	local sharedAssets = self.context.sharedAssets
	self.categoriesFolder = sharedAssets.Dictionaries:WaitForChild("ShopCategories")
	loadCatalog(self.categoriesFolder)

	self.informationFrame = self.context.buyPage.informationFrame
	self.cashDisplay = self.informationFrame:WaitForChild("CashDisplay")
	self.itemNameHolder = self.informationFrame:WaitForChild("ItemName")
	self.scrollingFrame = self.informationFrame:WaitForChild("Holder"):WaitForChild("Scrolling")
	self.itemRarityHolder = self.scrollingFrame:WaitForChild("ItemRarityHolder")
	self.itemDescriptionHolder = self.scrollingFrame:WaitForChild("ItemDescriptionHolder")
	self.itemTypeHolder = self.scrollingFrame:WaitForChild("ItemTypeHolder")
	self.statHolders = {
		self.scrollingFrame:WaitForChild("StatHolder1"),
		self.scrollingFrame:WaitForChild("StatHolder2"),
		self.scrollingFrame:WaitForChild("StatHolder3"),
		self.scrollingFrame:WaitForChild("StatHolder4"),
	}

	local choiceButtons = self.context.dialogue.choiceButtons
	self.choiceButtonA = choiceButtons[1]
	self.choiceButtonB = choiceButtons[2]

	self:initialize()

	return self
end

function itemInfoController:getItemConfig(itemId: string)
	return catalogByItemId[itemId]
end

function itemInfoController:stopStatLerp()
	if self.statLerpThread ~= nil then
		task.cancel(self.statLerpThread)
		self.statLerpThread = nil
	end
end

function itemInfoController:animateStats(stats: { any })
	self:stopStatLerp()

	local targets = {}
	local currentValues = {}

	for index, statHolder in ipairs(self.statHolders) do
		local stat = stats[index]
		if stat ~= nil then
			targets[index] = math.clamp(stat.value or 0, 0, 1)
			currentValues[index] = self.statValues[index] or 0
			statHolder.Visible = true
		elseif (self.statValues[index] or 0) > 0.001 then
			targets[index] = 0
			currentValues[index] = self.statValues[index]
		else
			statHolder.Visible = false
			clearStatGradient(statHolder)
		end
	end

	self.statLerpThread = task.spawn(function()
		local isSettled = false

		while not isSettled do
			local deltaTime = task.wait()
			isSettled = true

			for index, targetValue in pairs(targets) do
				local currentValue = currentValues[index]
				if math.abs(currentValue - targetValue) < 0.001 then
					currentValues[index] = targetValue
					self.statValues[index] = targetValue
					updateStatGradient(self.statHolders[index], targetValue)
					continue
				end

				isSettled = false

				local nextValue = currentValue + (targetValue - currentValue) * math.min(statLerpSpeed * deltaTime, 1)
				currentValues[index] = nextValue
				self.statValues[index] = nextValue
				updateStatGradient(self.statHolders[index], nextValue)
			end
		end

		self.statLerpThread = nil
	end)
end

function itemInfoController:showChoiceButtons(itemConfig)
	local choiceTextA = self.choiceButtonA:FindFirstChild("Text")
	local choiceTextB = self.choiceButtonB:FindFirstChild("Text")

	if choiceTextB and choiceTextB:IsA("TextLabel") then
		choiceTextB.Text = "I'll take it."
	end

	if choiceTextA and choiceTextA:IsA("TextLabel") then
		if itemConfig.discountedPrice then
			choiceTextA.Text = "$" .. tostring(itemConfig.discountedPrice) .. ", take it or leave it."
		else
			choiceTextA.Text = "How about a lower price?"
		end
	end

	setChoiceButtonVisible(self.choiceButtonA, true)
	setChoiceButtonVisible(self.choiceButtonB, true)
end

function itemInfoController:hideChoiceButtons()
	setChoiceButtonVisible(self.choiceButtonA, false)
	setChoiceButtonVisible(self.choiceButtonB, false)
end

function itemInfoController:clearPanel()
	local nameLabel = getTextDisplay(self.itemNameHolder)
	local rarityLabel = getTextDisplay(self.itemRarityHolder)
	local descriptionLabel = getTextDisplay(self.itemDescriptionHolder)
	local typeLabel = getTextDisplay(self.itemTypeHolder)
	local priceLabel = self.cashDisplay:FindFirstChild("Price") or getTextDisplay(self.cashDisplay)

	if nameLabel then
		nameLabel.Text = ""
	end

	if rarityLabel then
		rarityLabel.Text = ""
	end

	if descriptionLabel then
		descriptionLabel.Text = ""
	end

	if typeLabel then
		typeLabel.Text = ""
	end

	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = ""
	end

	for _, statHolder in ipairs(self.statHolders) do
		statHolder.Visible = false
		clearStatGradient(statHolder)
	end

	self:hideChoiceButtons()
	table.clear(self.statValues)
end

function itemInfoController:populatePanel(itemConfig)
	local nameLabel = getTextDisplay(self.itemNameHolder)
	local rarityLabel = getTextDisplay(self.itemRarityHolder)
	local descriptionLabel = getTextDisplay(self.itemDescriptionHolder)
	local typeLabel = getTextDisplay(self.itemTypeHolder)
	local priceLabel = self.cashDisplay:FindFirstChild("Price") or getTextDisplay(self.cashDisplay)

	if nameLabel then
		nameLabel.Text = itemConfig.displayName or "Unknown"
	end

	if rarityLabel then
		rarityLabel.Text = itemConfig.rarity or "Common"
		if itemConfig.rarityColor then
			rarityLabel.TextColor3 = itemConfig.rarityColor
		end
	end

	if descriptionLabel then
		descriptionLabel.Text = itemConfig.description or ""
	end

	if typeLabel then
		typeLabel.Text = itemConfig.weaponType or itemConfig.itemType or ""
	end

	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = "PRICE: $" .. tostring(itemConfig.price or 0)
	end

	local stats = itemConfig.stats or {}
	for index, statHolder in ipairs(self.statHolders) do
		local stat = stats[index]
		local statNameLabel = statHolder:FindFirstChild("Text")

		if stat ~= nil then
			statHolder.Visible = true
			if statNameLabel and statNameLabel:IsA("TextLabel") then
				statNameLabel.Text = stat.name or ""
			end
		else
			statHolder.Visible = false
			clearStatGradient(statHolder)
		end
	end

	self:animateStats(stats)
	self:showChoiceButtons(itemConfig)
end

function itemInfoController:deselectItem()
	if self.selectedItemId == nil then
		return
	end

	self:stopStatLerp()
	self.selectedItemId = nil
	self.selectedItemConfig = nil
	self:hideChoiceButtons()
	self.shopAnimator.hideInfo()
end

function itemInfoController:selectItem(itemId: string)
	local itemConfig = self:getItemConfig(itemId)
	if itemConfig == nil then
		return
	end

	if self.selectedItemId == itemId then
		self:deselectItem()
		return
	end

	self.selectedItemId = itemId
	self.selectedItemConfig = itemConfig
	self:populatePanel(itemConfig)
	self.shopAnimator.showInfo()

	self.context.networking.events.selectChoice:FireServer("itemSelect_" .. itemId)
end

function itemInfoController:attemptPurchase()
	if self.selectedItemId ~= nil then
		self.context.networking.events.selectChoice:FireServer("buyConfirm_" .. self.selectedItemId)
	end
end

function itemInfoController:attemptHaggle()
	if self.selectedItemId ~= nil then
		self.context.networking.events.selectChoice:FireServer("haggle_" .. self.selectedItemId)
	end
end

function itemInfoController:initialize()
	self.informationFrame.Visible = false
	self:clearPanel()

	table.insert(
		self.connections,
		self.choiceButtonA.Activated:Connect(function()
			self:attemptHaggle()
		end)
	)

	table.insert(
		self.connections,
		self.choiceButtonB.Activated:Connect(function()
			self:attemptPurchase()
		end)
	)
end

function itemInfoController:destroy()
	self:stopStatLerp()

	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
	self.selectedItemId = nil
	self.selectedItemConfig = nil

	setmetatable(self, nil)
end

return itemInfoController
