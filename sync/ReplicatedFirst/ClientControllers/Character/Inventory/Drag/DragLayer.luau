--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local GuiAnimator = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)

local dragOffset = 12
local activeScale = 1.05
local hiddenScale = 0.75
local springSettleDistance = 0.01

local positionSpringFrequency = 8
local positionSpringDamping = 300
local positionSpringMass = 25
local positionSpringSpeed = 8

local scaleSpringFrequency = 15
local scaleSpringDamping = 100
local scaleSpringMass = 4
local scaleSpringSpeed = 2.3

local positionSpringKey = "dragPosition"
local positionTrackKey = "dragPositionTrack"
local scaleSpringKey = "dragScale"
local scaleTrackKey = "dragScaleTrack"

local dragLayer = {}
dragLayer.__index = dragLayer

export type DragIntent = "CANCEL" | "DROP" | "INVALID" | "MOVE" | "MERGE" | "SWAP"

export type DragLayer = {
	frame: Frame?,
	intentLabel: TextLabel?,
	ghost: GuiButton?,
	animator: any,
	renderConnection: RBXScriptConnection?,
	pointerOffset: Vector2,
	isHiding: boolean,
	destroyed: boolean,
	show: (self: DragLayer, sourceButton: GuiButton, point: Vector2) -> (),
	update: (self: DragLayer, point: Vector2) -> (),
	setIntent: (self: DragLayer, intent: DragIntent) -> (),
	hide: (self: DragLayer) -> (),
	destroy: (self: DragLayer) -> (),
	_clearGhost: (self: DragLayer) -> (),
	_start: (self: DragLayer) -> (),
	_stop: (self: DragLayer) -> (),
	_updateAnimation: (self: DragLayer, deltaTime: number) -> (),
}

function dragLayer._clearGhost(self: DragLayer): ()
	local ghost = self.ghost
	self.ghost = nil
	if ghost then
		ghost:Destroy()
	end
end

function dragLayer._stop(self: DragLayer): ()
	local renderConnection = self.renderConnection
	if renderConnection == nil then
		return
	end

	renderConnection:Disconnect()
	self.renderConnection = nil
end

function dragLayer._updateAnimation(self: DragLayer, deltaTime: number): ()
	local animator = self.animator
	local frame = self.frame
	if animator == nil or frame == nil then
		self:_stop()
		return
	end

	animator:applyTracks(deltaTime)
	if
		not self.isHiding or not animator:isSpringSettled(scaleSpringKey, springSettleDistance, springSettleDistance)
	then
		return
	end

	frame.Visible = false
	self.isHiding = false
	self:_clearGhost()
	local intentLabel = self.intentLabel
	if intentLabel then
		intentLabel.Visible = false
	end
	self:_stop()
end

function dragLayer._start(self: DragLayer): ()
	if self.destroyed or self.renderConnection ~= nil then
		return
	end

	self.renderConnection = runService.RenderStepped:Connect(function(deltaTime: number)
		self:_updateAnimation(deltaTime)
	end)
end

function dragLayer.new(parent: Instance): DragLayer
	local frame = Instance.new("Frame")
	frame.Name = "InventoryDragLayer"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	frame.Size = UDim2.fromOffset(1, 1)
	frame.Visible = false
	frame.ZIndex = 100
	frame.Parent = parent

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "DragScale"
	uiScale.Scale = hiddenScale
	uiScale.Parent = frame

	local intentLabel = Instance.new("TextLabel")
	intentLabel.Name = "Intent"
	intentLabel.AnchorPoint = Vector2.new(0.5, 0)
	intentLabel.BackgroundColor3 = Color3.fromRGB(145, 36, 30)
	intentLabel.BackgroundTransparency = 0.15
	intentLabel.BorderSizePixel = 0
	intentLabel.Font = Enum.Font.GothamBold
	intentLabel.Position = UDim2.new(0.5, 0, 1, 6)
	intentLabel.Size = UDim2.new(1, 24, 0, 22)
	intentLabel.TextColor3 = Color3.new(1, 1, 1)
	intentLabel.TextSize = 12
	intentLabel.Visible = false
	intentLabel.ZIndex = 200
	intentLabel.Parent = frame

	local intentCorner = Instance.new("UICorner")
	intentCorner.CornerRadius = UDim.new(0, 5)
	intentCorner.Parent = intentLabel

	local animator = GuiAnimator.new(frame)
	animator:addSpring(
		positionSpringKey,
		Vector2.zero,
		positionSpringFrequency,
		positionSpringDamping,
		positionSpringMass,
		positionSpringSpeed
	)
	animator:addPositionSpringTrack(positionTrackKey, frame, positionSpringKey, true)
	animator:addScalarSpring(
		scaleSpringKey,
		hiddenScale,
		scaleSpringFrequency,
		scaleSpringDamping,
		scaleSpringMass,
		scaleSpringSpeed
	)
	animator:addNumberSpringTrack(scaleTrackKey, function(scale: number)
		uiScale.Scale = math.max(scale, 0)
	end, scaleSpringKey, 0)

	local self: DragLayer = (
		setmetatable({
			frame = frame,
			intentLabel = intentLabel,
			ghost = nil,
			animator = animator,
			renderConnection = nil,
			pointerOffset = Vector2.zero,
			isHiding = false,
			destroyed = false,
		}, dragLayer) :: unknown
	) :: DragLayer
	return self
end

function dragLayer:show(sourceButton: GuiButton, point: Vector2): ()
	local frame = self.frame
	local animator = self.animator
	if frame == nil or animator == nil then
		return
	end

	self:_clearGhost()
	local ghost = sourceButton:Clone()
	assert(ghost:IsA("GuiButton"), "drag ghost must remain a GuiButton")
	ghost.Name = "DraggedSlot"
	ghost.Active = false
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.AutoButtonColor = false
	ghost.LayoutOrder = 0
	ghost.Position = UDim2.fromScale(0.5, 0.5)
	ghost.Selectable = false
	ghost.Size = UDim2.fromScale(1, 1)
	ghost.ZIndex = 101

	for _, descendant in ghost:GetDescendants() do
		if descendant:IsA("UIDragDetector") then
			descendant:Destroy()
		elseif descendant:IsA("GuiObject") then
			descendant.ZIndex += 101
			if descendant:IsA("GuiButton") then
				descendant.Active = false
				descendant.AutoButtonColor = false
				descendant.Selectable = false
			end
		end
	end

	local sourceSize = sourceButton.AbsoluteSize
	local width = math.max(sourceSize.X, 1)
	local height = math.max(sourceSize.Y, 1)
	frame.Size = UDim2.fromOffset(width, height)
	self.pointerOffset = Vector2.new(dragOffset + width / 2, dragOffset + height / 2)
	self.ghost = ghost
	ghost.Parent = frame

	local targetPosition = point + self.pointerOffset
	animator:snapSpring(positionSpringKey, targetPosition)
	animator:snapSpring(scaleSpringKey, Vector2.new(hiddenScale, 0))
	animator:setSpring(scaleSpringKey, Vector2.new(activeScale, 0))
	self.isHiding = false
	frame.Visible = true
	self:_start()
end

function dragLayer:update(point: Vector2): ()
	local animator = self.animator
	if animator then
		animator:setSpring(positionSpringKey, point + self.pointerOffset)
	end
end

function dragLayer:setIntent(intent: DragIntent): ()
	local intentLabel = self.intentLabel
	if intentLabel then
		intentLabel.Text = intent
		intentLabel.Visible = true
	end
end

function dragLayer:hide(): ()
	local frame = self.frame
	local animator = self.animator
	if frame == nil or animator == nil or not frame.Visible then
		return
	end

	self.isHiding = true
	animator:setSpring(scaleSpringKey, Vector2.new(hiddenScale, 0))
	self:_start()
end

function dragLayer:destroy(): ()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self:_stop()
	self:_clearGhost()
	local animator = self.animator
	self.animator = nil
	if animator then
		animator:destroy()
	end
	local frame = self.frame
	if frame then
		frame:Destroy()
	end
	table.clear(self)
end

return dragLayer
