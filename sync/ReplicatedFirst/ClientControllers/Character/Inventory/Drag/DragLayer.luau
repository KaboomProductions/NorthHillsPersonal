--!strict

local runService = game:GetService("RunService")

local DragGhost = require(script.DragGhost)

local activeScale = 1.05
local snappedScale = 1
local landedDistance = 0.5
local returnMaxSeconds = 0.6
local confirmMaxSeconds = 1.5
local draggedZIndex = 1000
local swapZIndex = 999

type Phase = "idle" | "dragging" | "confirming" | "returning"

local dragLayer = {}
dragLayer.__index = dragLayer

export type DragLayer = {
	root: Frame?,
	dragged: DragGhost.DragGhost?,
	swap: DragGhost.DragGhost?,
	renderConnection: RBXScriptConnection?,
	phase: Phase,
	phaseElapsedSeconds: number,
	isSwapReturning: boolean,
	destroyed: boolean,
	show: (self: DragLayer, sourceButton: GuiButton) -> (),
	update: (self: DragLayer, point: Vector2, targetButton: GuiButton?, isSwap: boolean) -> (),
	confirm: (self: DragLayer, targetButton: GuiButton, isSwap: boolean) -> (),
	relocate: (self: DragLayer, currentButton: GuiButton, displacedButton: GuiButton?) -> (),
	finish: (self: DragLayer) -> (),
	cancel: (self: DragLayer) -> (),
	destroy: (self: DragLayer) -> (),
	_previewSwap: (self: DragLayer, targetButton: GuiButton) -> (),
	_returnSwap: (self: DragLayer) -> (),
	_start: (self: DragLayer) -> (),
	_stop: (self: DragLayer) -> (),
	_step: (self: DragLayer, deltaTime: number) -> (),
}

local function swapStartCenter(dragged: DragGhost.DragGhost, sourceCenter: Vector2, targetCenter: Vector2): Vector2
	local swapDelta = targetCenter - sourceCenter
	local swapDistanceSquared = swapDelta:Dot(swapDelta)
	if swapDistanceSquared <= 0.001 then
		return targetCenter
	end

	local progress = math.clamp((dragged:getCenter() - sourceCenter):Dot(swapDelta) / swapDistanceSquared, 0, 1)
	return targetCenter:Lerp(sourceCenter, progress)
end

function dragLayer.new(parent: Instance): DragLayer
	local root = Instance.new("Frame")
	root.Name = "InventoryDragRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Position = UDim2.fromScale(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 100
	root.Parent = parent

	return (
		setmetatable({
			root = root,
			dragged = DragGhost.new(root, "DraggedItem", draggedZIndex),
			swap = DragGhost.new(root, "SwappedItem", swapZIndex),
			renderConnection = nil,
			phase = "idle" :: Phase,
			phaseElapsedSeconds = 0,
			isSwapReturning = false,
			destroyed = false,
		}, dragLayer) :: unknown
	) :: DragLayer
end

function dragLayer._stop(self: DragLayer): ()
	local renderConnection = self.renderConnection
	if renderConnection == nil then
		return
	end

	renderConnection:Disconnect()
	self.renderConnection = nil
end

function dragLayer._start(self: DragLayer): ()
	if self.destroyed or self.renderConnection ~= nil then
		return
	end

	self.renderConnection = runService.RenderStepped:Connect(function(deltaTime: number)
		self:_step(deltaTime)
	end)
end

function dragLayer._step(self: DragLayer, deltaTime: number): ()
	local dragged = self.dragged
	local swap = self.swap
	if dragged == nil or swap == nil then
		self:_stop()
		return
	end

	dragged:step(deltaTime)
	swap:step(deltaTime)

	if self.isSwapReturning and swap:hasLanded(landedDistance) then
		swap:release()
		self.isSwapReturning = false
	end

	if self.phase == "idle" then
		if not swap:isLifted() then
			self:_stop()
		end
		return
	end

	if not dragged:isLifted() then
		self:finish()
		return
	end

	self.phaseElapsedSeconds += deltaTime
	if self.phase == "returning" then
		if dragged:hasLanded(landedDistance) or self.phaseElapsedSeconds >= returnMaxSeconds then
			self:finish()
		end
		return
	end

	if self.phase == "confirming" and self.phaseElapsedSeconds >= confirmMaxSeconds then
		self:finish()
	end
end

function dragLayer._returnSwap(self: DragLayer): ()
	local swap = self.swap
	if swap == nil or self.isSwapReturning then
		return
	end

	local swapButton = swap:getButton()
	if swapButton == nil then
		return
	end

	self.isSwapReturning = true
	swap:moveToSlot(swapButton)
end

function dragLayer._previewSwap(self: DragLayer, targetButton: GuiButton): ()
	local dragged = self.dragged
	local swap = self.swap
	if dragged == nil or swap == nil then
		return
	end

	local sourceButton = dragged:getButton()
	if sourceButton == nil then
		return
	end

	local sourceCenter = dragged:slotCenter(sourceButton)
	if swap:getButton() == targetButton then
		self.isSwapReturning = false
		swap:moveTo(sourceCenter, sourceButton.AbsoluteSize)
		return
	end

	swap:release()
	self.isSwapReturning = false

	local targetCenter = swap:slotCenter(targetButton)
	swap:lift(targetButton)
	swap:snapTo(swapStartCenter(dragged, sourceCenter, targetCenter), targetButton.AbsoluteSize)
	swap:moveTo(sourceCenter, sourceButton.AbsoluteSize)
end

function dragLayer.show(self: DragLayer, sourceButton: GuiButton): ()
	local dragged = self.dragged
	if dragged == nil or self.destroyed then
		return
	end

	self:finish()
	dragged:lift(sourceButton)
	self.phase = "dragging"
	self.phaseElapsedSeconds = 0
	self:_start()
end

function dragLayer.update(self: DragLayer, point: Vector2, targetButton: GuiButton?, isSwap: boolean): ()
	local root = self.root
	local dragged = self.dragged
	if root == nil or dragged == nil or self.phase ~= "dragging" then
		return
	end

	if targetButton then
		dragged:moveToSlot(targetButton)
		dragged:setScale(snappedScale)
	else
		dragged:moveToPoint(point - root.AbsolutePosition)
		dragged:setScale(activeScale)
	end

	if targetButton and isSwap then
		self:_previewSwap(targetButton)
	else
		self:_returnSwap()
	end
end

function dragLayer.confirm(self: DragLayer, targetButton: GuiButton, isSwap: boolean): ()
	local dragged = self.dragged
	if dragged == nil or self.phase ~= "dragging" then
		return
	end

	self.phase = "confirming"
	self.phaseElapsedSeconds = 0
	dragged:moveToSlot(targetButton)
	dragged:setScale(snappedScale)

	if isSwap then
		self:_previewSwap(targetButton)
	else
		self:_returnSwap()
	end
end

function dragLayer.relocate(self: DragLayer, currentButton: GuiButton, displacedButton: GuiButton?): ()
	local dragged = self.dragged
	local swap = self.swap
	if dragged == nil or swap == nil or self.phase == "idle" then
		return
	end

	local previousButton = dragged:getButton()
	if previousButton == currentButton then
		return
	end

	local wasPreviewingCurrent = swap:getButton() == currentButton
	swap:release()
	dragged:release()
	dragged:liftInPlace(currentButton)
	self.isSwapReturning = false

	if self.phase == "returning" then
		dragged:moveToSlot(currentButton)
	end

	if displacedButton == nil then
		return
	end

	swap:liftInPlace(displacedButton)
	if not wasPreviewingCurrent then
		swap:snapToSlot(currentButton)
	end
	swap:moveToSlot(displacedButton)
	self.isSwapReturning = true
end

function dragLayer.finish(self: DragLayer): ()
	if self.phase == "idle" then
		return
	end

	self.phase = "idle"
	self.phaseElapsedSeconds = 0
	self.isSwapReturning = false

	local dragged = self.dragged
	if dragged then
		dragged:release()
	end

	local swap = self.swap
	if swap then
		swap:release()
	end
end

function dragLayer.cancel(self: DragLayer): ()
	local dragged = self.dragged
	if dragged == nil or self.phase == "idle" or self.phase == "returning" then
		return
	end

	local sourceButton = dragged:getButton()
	if sourceButton == nil then
		self:finish()
		return
	end

	self.phase = "returning"
	self.phaseElapsedSeconds = 0
	dragged:moveToSlot(sourceButton)
	dragged:setScale(snappedScale)
	self:_returnSwap()
	self:_start()
end

function dragLayer.destroy(self: DragLayer): ()
	if self.destroyed then
		return
	end
	self.destroyed = true

	self:_stop()
	self:finish()

	local dragged = self.dragged
	self.dragged = nil
	if dragged then
		dragged:destroy()
	end

	local swap = self.swap
	self.swap = nil
	if swap then
		swap:destroy()
	end

	local root = self.root
	self.root = nil
	if root then
		root:Destroy()
	end
end

return dragLayer
