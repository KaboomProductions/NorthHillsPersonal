local replicatedStorage = game:GetService("ReplicatedStorage")

local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)

local barManagerLayout = {}

function barManagerLayout.extend(barManager, config, utils)
	function barManager:getBarsContainer(): Instance
		local progressBarList = self.progressBars:FindFirstChild("ProgressBarList")
		if progressBarList and progressBarList:IsA("Instance") then
			return progressBarList
		end

		return self.progressBars
	end

	function barManager:getBarPriority(bar: GuiObject): number
		return config.priorityByBarName[bar.Name] or 1000
	end

	function barManager:getTargetSlotYScale(slotIndex: number): number
		local stateValues = self.__vars

		return stateValues.firstSlotYScale - ((slotIndex - 1) * stateValues.slotStep)
	end

	function barManager:getTrackedBars(): { any }
		local trackedBars = {}

		for _, child in ipairs(self:getBarsContainer():GetChildren()) do
			if utils.isGuiObject(child) then
				table.insert(trackedBars, self:getOrCreateBarData(child))
			end
		end

		table.sort(trackedBars, function(leftBarData, rightBarData)
			local leftBar = leftBarData.bar
			local rightBar = rightBarData.bar
			local leftPriority = self:getBarPriority(leftBar)
			local rightPriority = self:getBarPriority(rightBar)

			if leftPriority ~= rightPriority then
				return leftPriority < rightPriority
			end

			return leftBar.Name < rightBar.Name
		end)

		return trackedBars
	end

	function barManager:getNextAvailableSlotIndex(usedSlots: { [number]: boolean }): number
		local slotIndex = 1

		while usedSlots[slotIndex] do
			slotIndex += 1
		end

		return slotIndex
	end

	function barManager:trackBar(bar: GuiObject)
		local barData = self:getOrCreateBarData(bar)

		if self.attributeConnections[bar] ~= nil then
			return
		end

		if bar:GetAttribute("Full") == nil then
			bar:SetAttribute("Full", true)
		end

		self.attributeConnections[bar] = bar:GetAttributeChangedSignal("Full"):Connect(function()
			self:handleBarFullChanged(barData)
		end)
	end

	function barManager:refreshTracking()
		local activeBarsByInstance = {}

		for _, child in ipairs(self:getBarsContainer():GetChildren()) do
			if utils.isGuiObject(child) then
				activeBarsByInstance[child] = true
				self:trackBar(child)
			end
		end

		for bar, _ in pairs(self.barDataByBar) do
			if not activeBarsByInstance[bar] then
				connectionUtilities.disconnectConnection(self.attributeConnections[bar])
				self.attributeConnections[bar] = nil
				self:removeBar(bar)
			end
		end
	end

	function barManager:updateLayout()
		if self.isDestroyed then
			return
		end

		self:refreshTracking()

		local isShopOpen = self:isShopOpen()
		local trackedBars = self:getTrackedBars()
		local usedSlots = {}
		local slotOwners = {}

		for _, barData in ipairs(trackedBars) do
			local shouldReserveCurrentSlot = barData.assignedSlotIndex ~= nil
				and (barData.state == "hiding" or barData.state == "visible")
				and (barData.state == "hiding" or barData.isFull)
			if shouldReserveCurrentSlot then
				local assignedSlotIndex = barData.assignedSlotIndex
				usedSlots[assignedSlotIndex] = true
				slotOwners[assignedSlotIndex] = barData
			end
		end

		for _, barData in ipairs(trackedBars) do
			local shouldShowBar = not isShopOpen and not barData.isFull

			if shouldShowBar then
				self:cancelHideDelay(barData)

				local assignedSlotIndex = self:getNextAvailableSlotIndex(usedSlots)

				usedSlots[assignedSlotIndex] = true
				slotOwners[assignedSlotIndex] = barData
				self:setBarSlot(barData, assignedSlotIndex)
			elseif isShopOpen then
				self:cancelHideDelay(barData)

				if barData.state ~= "hidden" then
					self:beginHide(barData)
				end
			elseif barData.isFull and barData.state == "visible" then
				self:scheduleHide(barData)
			end
		end
	end
end

return barManagerLayout
