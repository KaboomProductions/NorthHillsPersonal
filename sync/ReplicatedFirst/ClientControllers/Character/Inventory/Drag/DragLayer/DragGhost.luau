--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local GuiAnimator = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)
local ItemVisuals = require(script.Parent.ItemVisuals)

local motionSpringFrequency = 8
local motionSpringDamping = 300
local motionSpringMass = 16
local motionSpringSpeed = 8

local followDamping = 16
local glideDamping = 28
local scaleSpringFrequency = 15
local scaleSpringDamping = 100
local scaleSpringMass = 4
local scaleSpringSpeed = 2.3

local positionSpringKey = "position"
local positionTrackKey = "positionTrack"
local sizeSpringKey = "size"
local sizeTrackKey = "sizeTrack"
local scaleSpringKey = "scale"
local scaleTrackKey = "scaleTrack"

local dragGhost = {}
dragGhost.__index = dragGhost

export type DragGhost = {
	root: GuiObject?,
	frame: Frame?,
	animator: any,
	button: GuiButton?,
	liftedVisuals: { GuiObject },
	destroyingConnection: RBXScriptConnection?,
	destroyed: boolean,
	lift: (self: DragGhost, button: GuiButton) -> (),
	liftInPlace: (self: DragGhost, button: GuiButton) -> (),
	release: (self: DragGhost) -> (),
	isLifted: (self: DragGhost) -> boolean,
	getButton: (self: DragGhost) -> GuiButton?,
	getCenter: (self: DragGhost) -> Vector2,
	slotCenter: (self: DragGhost, slot: GuiObject) -> Vector2,
	snapTo: (self: DragGhost, center: Vector2, size: Vector2) -> (),
	moveTo: (self: DragGhost, center: Vector2, size: Vector2) -> (),
	snapToSlot: (self: DragGhost, slot: GuiObject) -> (),
	moveToSlot: (self: DragGhost, slot: GuiObject) -> (),
	moveToPoint: (self: DragGhost, point: Vector2) -> (),
	setScale: (self: DragGhost, scale: number) -> (),
	step: (self: DragGhost, deltaTime: number) -> (),
	hasLanded: (self: DragGhost, distance: number) -> boolean,
	destroy: (self: DragGhost) -> (),
	_dropLiftedVisuals: (self: DragGhost) -> (),
	_setDamping: (self: DragGhost, damping: number) -> (),
	_setTargets: (self: DragGhost, center: Vector2, size: Vector2) -> (),
}

local function resolvedSize(size: Vector2): Vector2
	return Vector2.new(math.max(size.X, 1), math.max(size.Y, 1))
end

function dragGhost.new(root: GuiObject, name: string, zIndex: number): DragGhost
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(1, 1)
	frame.Visible = false
	frame.ZIndex = zIndex
	frame.Parent = root

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "GhostScale"
	uiScale.Parent = frame

	local animator = GuiAnimator.new(frame)
	animator:addSpring(
		positionSpringKey,
		Vector2.zero,
		motionSpringFrequency,
		motionSpringDamping,
		motionSpringMass,
		motionSpringSpeed
	)
	animator:addPositionSpringTrack(positionTrackKey, frame, positionSpringKey, true)
	animator:addSpring(
		sizeSpringKey,
		Vector2.one,
		motionSpringFrequency,
		motionSpringDamping,
		motionSpringMass,
		motionSpringSpeed
	)
	animator:addSizeSpringTrack(sizeTrackKey, frame, "Size", sizeSpringKey, true)
	animator:addScalarSpring(
		scaleSpringKey,
		1,
		scaleSpringFrequency,
		scaleSpringDamping,
		scaleSpringMass,
		scaleSpringSpeed
	)
	animator:addNumberSpringTrack(scaleTrackKey, function(scale: number)
		uiScale.Scale = math.max(scale, 0)
	end, scaleSpringKey, 0)

	return (
		setmetatable({
			root = root,
			frame = frame,
			animator = animator,
			button = nil,
			liftedVisuals = {},
			destroyingConnection = nil,
			destroyed = false,
		}, dragGhost) :: unknown
	) :: DragGhost
end

function dragGhost._dropLiftedVisuals(self: DragGhost): ()
	local destroyingConnection = self.destroyingConnection
	self.destroyingConnection = nil
	if destroyingConnection then
		destroyingConnection:Disconnect()
	end

	ItemVisuals.destroy(self.liftedVisuals)
	table.clear(self.liftedVisuals)
	self.button = nil

	local frame = self.frame
	if frame then
		frame.Visible = false
	end
end

function dragGhost.liftInPlace(self: DragGhost, button: GuiButton): ()
	local frame = self.frame
	if frame == nil or self.destroyed then
		return
	end

	self:release()
	self.button = button
	self.liftedVisuals = ItemVisuals.lift(button, frame)
	self.destroyingConnection = button.Destroying:Connect(function()
		self:_dropLiftedVisuals()
	end)
	frame.Visible = true
end

function dragGhost.lift(self: DragGhost, button: GuiButton): ()
	self:liftInPlace(button)
	if self.button == nil then
		return
	end

	self:snapToSlot(button)
	self:setScale(1)
	self.animator:applyTracks(0)
end

function dragGhost.release(self: DragGhost): ()
	local button = self.button
	if button == nil then
		return
	end

	local destroyingConnection = self.destroyingConnection
	self.destroyingConnection = nil
	if destroyingConnection then
		destroyingConnection:Disconnect()
	end

	ItemVisuals.restore(button, self.liftedVisuals)
	table.clear(self.liftedVisuals)
	self.button = nil

	local frame = self.frame
	if frame then
		frame.Visible = false
	end
end

function dragGhost.isLifted(self: DragGhost): boolean
	return self.button ~= nil
end

function dragGhost.getButton(self: DragGhost): GuiButton?
	return self.button
end

function dragGhost.getCenter(self: DragGhost): Vector2
	local position = self.animator:getSpringState(positionSpringKey)
	return position
end

function dragGhost.slotCenter(self: DragGhost, slot: GuiObject): Vector2
	local root = self.root
	local rootPosition = if root then root.AbsolutePosition else Vector2.zero
	return slot.AbsolutePosition + slot.AbsoluteSize / 2 - rootPosition
end

function dragGhost._setDamping(self: DragGhost, damping: number): ()
	local animator = self.animator
	animator:getSpring(positionSpringKey).damping = damping
	animator:getSpring(sizeSpringKey).damping = damping
end

function dragGhost._setTargets(self: DragGhost, center: Vector2, size: Vector2): ()
	local animator = self.animator
	animator:setSpring(positionSpringKey, center)
	animator:setSpring(sizeSpringKey, resolvedSize(size))
end

function dragGhost.snapTo(self: DragGhost, center: Vector2, size: Vector2): ()
	local animator = self.animator
	animator:snapSpring(positionSpringKey, center)
	animator:snapSpring(sizeSpringKey, resolvedSize(size))
end

function dragGhost.moveTo(self: DragGhost, center: Vector2, size: Vector2): ()
	self:_setDamping(glideDamping)
	self:_setTargets(center, size)
end

function dragGhost.snapToSlot(self: DragGhost, slot: GuiObject): ()
	self:snapTo(self:slotCenter(slot), slot.AbsoluteSize)
end

function dragGhost.moveToSlot(self: DragGhost, slot: GuiObject): ()
	self:moveTo(self:slotCenter(slot), slot.AbsoluteSize)
end

function dragGhost.moveToPoint(self: DragGhost, point: Vector2): ()
	local button = self.button
	local size = if button then button.AbsoluteSize else Vector2.one
	self:_setDamping(followDamping)
	self:_setTargets(point, size)
end

function dragGhost.setScale(self: DragGhost, scale: number): ()
	self.animator:setSpring(scaleSpringKey, Vector2.new(scale, 0))
end

function dragGhost.step(self: DragGhost, deltaTime: number): ()
	if self.frame == nil then
		return
	end
	self.animator:applyTracks(deltaTime)
end

function dragGhost.hasLanded(self: DragGhost, distance: number): boolean
	local animator = self.animator
	return animator:isSpringSettled(positionSpringKey, distance, distance)
		and animator:isSpringSettled(sizeSpringKey, distance, distance)
end

function dragGhost.destroy(self: DragGhost): ()
	if self.destroyed then
		return
	end
	self.destroyed = true

	self:release()

	local animator = self.animator
	self.animator = nil
	if animator then
		animator:destroy()
	end

	local frame = self.frame
	self.frame = nil
	if frame then
		frame:Destroy()
	end
	self.root = nil
end

return dragGhost
