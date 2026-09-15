local replicatedStorage = game:GetService("ReplicatedStorage")

local guiAnimatorModule = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)
local itemInfoModule = require(script.ItemInfo)

local buyConfig = {
	scaleLerpSpeed = 18,
	clickScaleLerpSpeed = 30,
	hoverScale = 1.02,
	clickScale = 0.97,
	selectedScale = 1.03,

	colorLerpSpeed = 12,
	defaultTextColor = Color3.fromRGB(188, 188, 188),
	hoverTextColor = Color3.fromRGB(225, 225, 225),
	selectedTextColor = Color3.fromRGB(198, 67, 67),

	stockSpringFrequency = 15,
	stockSpringDamping = 100,
	stockSpringMass = 4,
	stockSpringSpeed = 5,
}

local buyController = {}
buyController.__index = buyController

local function scaleTrackKey(button: TextButton): string
	return "scale_" .. button.Name
end

local function colorTrackKey(button: TextButton): string
	return "color_" .. button.Name
end

local function cardScaleTrackKey(card: ImageButton): string
	return "cardScale_" .. card.Name
end

local function getOrCreateScale(guiObject: GuiObject): UIScale
	local existingScale = guiObject:FindFirstChildOfClass("UIScale")
	if existingScale then
		return existingScale
	end

	local newScale = Instance.new("UIScale")
	newScale.Scale = 1
	newScale.Parent = guiObject
	return newScale
end

function buyController.new(optionContext)
	local self = setmetatable({}, buyController)
	self.context = optionContext.context
	self.shopAnimator = optionContext.shopAnimator
	self.buyPage = self.context.buyPage
	self.animator = guiAnimatorModule.new(self.buyPage.frame)
	self.connections = {}
	self.categoryEntries = {}
	self.currentCategory = nil
	self.itemInfo = itemInfoModule.new(optionContext)

	self:initialize()

	return self
end

function buyController:getCategoryEntries(): { any }
	local sortedButtons = {}

	for _, button in ipairs(self.buyPage.categoryButtons) do
		table.insert(sortedButtons, button)
	end

	table.sort(sortedButtons, function(left, right)
		local xDifference = left.AbsolutePosition.X - right.AbsolutePosition.X
		if math.abs(xDifference) > 1 then
			return xDifference < 0
		end

		local yDifference = left.AbsolutePosition.Y - right.AbsolutePosition.Y
		if math.abs(yDifference) > 1 then
			return yDifference < 0
		end

		return left.LayoutOrder < right.LayoutOrder
	end)

	local categoryEntries = {}

	for _, button in ipairs(sortedButtons) do
		table.insert(categoryEntries, {
			button = button,
		})
	end

	for index, categoryEntry in ipairs(categoryEntries) do
		categoryEntry.stockPosition = Vector2.new(-(index - 1), 0)
	end

	return categoryEntries
end

function buyController:isCategorySelected(categoryEntry): boolean
	return self.currentCategory == categoryEntry
end

function buyController:getTargetScale(categoryEntry): number
	local isSelected = self:isCategorySelected(categoryEntry)
	local isHovered = self.hoveredButton == categoryEntry.button

	if isSelected and isHovered then
		return buyConfig.selectedScale * buyConfig.hoverScale
	end

	if isSelected then
		return buyConfig.selectedScale
	end

	if isHovered then
		return buyConfig.hoverScale
	end

	return 1
end

function buyController:getTargetTextColor(categoryEntry): Color3
	if self:isCategorySelected(categoryEntry) then
		return buyConfig.selectedTextColor
	end

	if self.hoveredButton == categoryEntry.button then
		return buyConfig.hoverTextColor
	end

	return buyConfig.defaultTextColor
end

function buyController:updateCategoryVisual(categoryEntry, shouldSnap: boolean?)
	local button = categoryEntry.button
	local scaleKey = scaleTrackKey(button)
	local colorKey = colorTrackKey(button)
	local targetScale = self:getTargetScale(categoryEntry)
	local targetColor = self:getTargetTextColor(categoryEntry)

	if shouldSnap then
		self.animator:snapNumberLerp(scaleKey, targetScale)
		self.animator:snapColorLerp(colorKey, targetColor)
		return
	end

	self.animator:setNumberLerpTarget(scaleKey, targetScale)
	self.animator:setColorLerpTarget(colorKey, targetColor)
end

function buyController:updateAllCategoryVisuals(shouldSnap: boolean?)
	for _, categoryEntry in ipairs(self.categoryEntries) do
		self:updateCategoryVisual(categoryEntry, shouldSnap)
	end
end

function buyController:setStockPosition(stockPosition: Vector2, shouldSnap: boolean?)
	if shouldSnap then
		self.animator:snapSpring("stockPosition", stockPosition)
		return
	end

	self.animator:setSpring("stockPosition", stockPosition)
end

function buyController:selectCategory(categoryEntry)
	if self.currentCategory == categoryEntry then
		self:updateCategoryVisual(categoryEntry)
		self:setStockPosition(categoryEntry.stockPosition)
		return
	end

	self.currentCategory = categoryEntry
	self:updateAllCategoryVisuals()
	self:setStockPosition(categoryEntry.stockPosition)
end

function buyController:setupCategoryButtons()
	for _, categoryEntry in ipairs(self.categoryEntries) do
		local button = categoryEntry.button
		local uiScale = getOrCreateScale(button)
		local scaleKey = scaleTrackKey(button)
		local colorKey = colorTrackKey(button)

		self.animator:addNumberLerpTrack(scaleKey, function(scale)
			uiScale.Scale = scale
		end, 1, 1, buyConfig.scaleLerpSpeed)

		self.animator:addColorLerpTrack(colorKey, function(color)
			button.TextColor3 = color
		end, buyConfig.defaultTextColor, buyConfig.defaultTextColor, buyConfig.colorLerpSpeed)

		table.insert(
			self.connections,
			button.MouseEnter:Connect(function()
				self.hoveredButton = button
				self:updateCategoryVisual(categoryEntry)
			end)
		)

		table.insert(
			self.connections,
			button.MouseLeave:Connect(function()
				if self.hoveredButton == button then
					self.hoveredButton = nil
				end
				self:updateCategoryVisual(categoryEntry)
			end)
		)

		table.insert(
			self.connections,
			button.MouseButton1Down:Connect(function()
				self.animator:setNumberLerpTarget(scaleKey, buyConfig.clickScale, buyConfig.clickScaleLerpSpeed)
			end)
		)

		table.insert(
			self.connections,
			button.MouseButton1Up:Connect(function()
				self.animator:setNumberLerpTarget(scaleKey, self:getTargetScale(categoryEntry))
			end)
		)

		table.insert(
			self.connections,
			button.Activated:Connect(function()
				self:selectCategory(categoryEntry)
			end)
		)
	end
end

function buyController:setupItemCards()
	for _, stockRow in ipairs(self.buyPage.stockFrame:GetChildren()) do
		if not stockRow:IsA("GuiObject") then
			continue
		end

		for _, itemCard in ipairs(stockRow:GetChildren()) do
			if not itemCard:IsA("ImageButton") then
				continue
			end

			local card = itemCard
			local uiScale = getOrCreateScale(card)
			local trackName = cardScaleTrackKey(card)

			self.animator:addNumberLerpTrack(trackName, function(scale)
				uiScale.Scale = scale
			end, 1, 1, buyConfig.scaleLerpSpeed)

			table.insert(
				self.connections,
				card.MouseEnter:Connect(function()
					self.animator:setNumberLerpTarget(trackName, buyConfig.hoverScale)
				end)
			)

			table.insert(
				self.connections,
				card.MouseLeave:Connect(function()
					self.animator:setNumberLerpTarget(trackName, 1)
				end)
			)

			table.insert(
				self.connections,
				card.MouseButton1Down:Connect(function()
					self.animator:setNumberLerpTarget(trackName, buyConfig.clickScale, buyConfig.clickScaleLerpSpeed)
				end)
			)

			table.insert(
				self.connections,
				card.MouseButton1Up:Connect(function()
					self.animator:setNumberLerpTarget(trackName, buyConfig.hoverScale)
				end)
			)

			table.insert(
				self.connections,
				card.Activated:Connect(function()
					self.itemInfo:selectItem(card.Name)
				end)
			)
		end
	end
end

function buyController:initialize()
	task.wait()

	self.categoryEntries = self:getCategoryEntries()

	self.animator:addSpring(
		"stockPosition",
		Vector2.zero,
		buyConfig.stockSpringFrequency,
		buyConfig.stockSpringDamping,
		buyConfig.stockSpringMass,
		buyConfig.stockSpringSpeed
	)

	self.animator:addNumberSpringTrack("stockPositionTrack", function(xScale)
		self.buyPage.stockFrame.Position = UDim2.fromScale(xScale, 0)
	end, "stockPosition", 0)

	self:setupCategoryButtons()
	self:setupItemCards()

	local firstCategory = self.categoryEntries[1]
	if firstCategory ~= nil then
		self.currentCategory = firstCategory
		self:updateAllCategoryVisuals(true)
		self:setStockPosition(firstCategory.stockPosition, true)
	end
end

function buyController:update(deltaTime: number)
	self.animator:applyTracks(deltaTime)
end

function buyController:destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
	self.animator:destroy()
	self.itemInfo:destroy()

	setmetatable(self, nil)
end

return buyController
