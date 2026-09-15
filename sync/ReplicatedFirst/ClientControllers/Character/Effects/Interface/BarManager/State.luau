local replicatedStorage = game:GetService("ReplicatedStorage")

local spring = require(replicatedStorage.SharedClasses.Spring)

local barManagerState = {}

local function expLerpAlpha(speed: number, deltaTime: number): number
	return 1 - math.exp(-speed * deltaTime)
end

function barManagerState.extend(barManager, utils)
	function barManager:isShopOpen(): boolean
		local stateValues = self.__vars
		local shopFrame = self.shopFrame

		if shopFrame == nil then
			return stateValues.isShopOpen
		end

		return stateValues.isShopOpen or shopFrame.Visible
	end

	function barManager:applyBarPosition(barData, yScale: number)
		local basePosition = barData.basePosition

		barData.bar.Position = UDim2.new(basePosition.X.Scale, basePosition.X.Offset, yScale, basePosition.Y.Offset)
	end

	function barManager:getCurrentTransparency(barData): number
		return barData.currentTransparency
	end

	function barManager:isBarFullyHidden(barData): boolean
		local stateValues = self.__vars
		local isTransparencyHidden = self:getCurrentTransparency(barData)
			>= stateValues.hiddenTransparency - stateValues.transparencySettleThreshold

		return isTransparencyHidden
	end

	function barManager:setBarVisible(barData, isVisible: boolean)
		barData.bar.Visible = isVisible
	end

	function barManager:applyBarTransparency(barData, transparency: number)
		barData.currentTransparency = transparency

		for _, imageTarget in ipairs(barData.imageTargets) do
			imageTarget.ImageTransparency = transparency
		end
	end

	function barManager:setBarTransparency(barData, targetTransparency: number)
		barData.targetTransparency = targetTransparency
	end

	function barManager:updateBarAnimation(barData, deltaTime: number)
		local positionSpring = barData.positionSpring
		if positionSpring ~= nil then
			local nextPosition = positionSpring:update(deltaTime)
			self:applyBarPosition(barData, nextPosition.X)
		end

		local currentTransparency = barData.currentTransparency
		local targetTransparency = barData.targetTransparency
		if currentTransparency == nil or targetTransparency == nil then
			return
		end

		local alpha = math.clamp(expLerpAlpha(self.__vars.transparencyLerpSpeed, deltaTime), 0, 1)
		local nextTransparency = currentTransparency + (targetTransparency - currentTransparency) * alpha

		if math.abs(nextTransparency - targetTransparency) <= self.__vars.transparencySettleThreshold then
			nextTransparency = targetTransparency
		end

		self:applyBarTransparency(barData, nextTransparency)
	end

	function barManager:setBarSlot(barData, slotIndex: number)
		local targetYScale = self:getTargetSlotYScale(slotIndex)
		local shouldSlideInFromBottom = barData.state == "hidden" or barData.state == "hiding"

		barData.assignedSlotIndex = slotIndex
		barData.state = "visible"
		barData.hideToken = nil

		if shouldSlideInFromBottom then
			local hiddenYScale = self.__vars.hiddenYScale
			barData.positionSpring.position = Vector2.new(hiddenYScale, 0)
			barData.positionSpring.target = Vector2.new(hiddenYScale, 0)
			barData.positionSpring.velocity = Vector2.zero
			self:applyBarPosition(barData, hiddenYScale)
		end

		self:setBarVisible(barData, true)
		barData.positionSpring.target = Vector2.new(targetYScale, 0)
		self:setBarTransparency(barData, self.__vars.visibleTransparency)
	end

	function barManager:beginHide(barData)
		local stateValues = self.__vars

		barData.state = "hiding"
		barData.hideToken = nil

		self:setBarVisible(barData, true)
		self:setBarTransparency(barData, stateValues.hiddenTransparency)
	end

	function barManager:finishHideIfSettled(barData)
		if barData.state ~= "hiding" then
			return
		end

		if not self:isBarFullyHidden(barData) then
			return
		end

		barData.state = "hidden"
		barData.assignedSlotIndex = nil
		self:setBarVisible(barData, false)
		self:updateLayout()
	end

	function barManager:cancelHideDelay(barData)
		local hideToken = barData.hideToken
		if hideToken then
			hideToken.cancelled = true
			barData.hideToken = nil
		end
	end

	function barManager:scheduleHide(barData)
		if barData.hideToken ~= nil or barData.state == "hiding" then
			return
		end

		local hideToken = { cancelled = false }
		barData.hideToken = hideToken

		task.delay(self.__vars.hideDelaySeconds, function()
			if self.isDestroyed or hideToken.cancelled then
				return
			end

			barData.hideToken = nil

			if not barData.bar.Parent or self:isShopOpen() or not barData.isFull then
				return
			end

			self:beginHide(barData)
			self:updateLayout()
		end)
	end

	function barManager:createBarData(bar: GuiObject)
		local imageTargets = utils.collectImageTargets(bar)
		local basePosition = bar.Position
		local hiddenYScale = self.__vars.hiddenYScale
		local positionSpring = self.__vars.positionSpring
		local positionSpringState = spring.new(
			Vector2.new(hiddenYScale, 0),
			positionSpring.frequency,
			positionSpring.damping,
			positionSpring.mass,
			positionSpring.speed
		)

		local nextBarData = {
			bar = bar,
			basePosition = basePosition,
			imageTargets = imageTargets,
			positionSpring = positionSpringState,
			assignedSlotIndex = nil,
			state = "hidden",
			isFull = utils.getFullAttribute(bar),
			lastFullState = utils.getFullAttribute(bar),
			currentTransparency = self.__vars.hiddenTransparency,
			targetTransparency = self.__vars.hiddenTransparency,
			hideToken = nil,
		}

		self.barDataByBar[bar] = nextBarData
		self:applyBarPosition(nextBarData, hiddenYScale)
		self:applyBarTransparency(nextBarData, self.__vars.hiddenTransparency)
		self:setBarVisible(nextBarData, false)

		return nextBarData
	end

	function barManager:removeBar(bar: GuiObject)
		local barData = self.barDataByBar[bar]
		if barData == nil then
			return
		end

		self:cancelHideDelay(barData)

		self.barDataByBar[bar] = nil
		self:updateLayout()
	end

	function barManager:getOrCreateBarData(bar: GuiObject)
		return self.barDataByBar[bar] or self:createBarData(bar)
	end

	function barManager:handleBarFullChanged(barData)
		barData.isFull = utils.getFullAttribute(barData.bar)

		if self.isDestroyed then
			return
		end

		if self.ignoreChangesUntil and time() < self.ignoreChangesUntil then
			barData.lastFullState = barData.isFull
			return
		end

		if self:isShopOpen() then
			self:cancelHideDelay(barData)
			self:beginHide(barData)
			self:updateLayout()
			return
		end

		if barData.isFull then
			self:scheduleHide(barData)
		else
			self:cancelHideDelay(barData)
			self:updateLayout()
		end

		barData.lastFullState = barData.isFull
	end
end

return barManagerState
