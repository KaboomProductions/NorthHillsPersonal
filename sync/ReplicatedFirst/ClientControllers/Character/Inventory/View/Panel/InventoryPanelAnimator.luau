--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local GuiAnimator = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)

local panelSpringFrequency = 15
local panelSpringDamping = 100
local panelSpringMass = 4
local panelSpringSpeed = 2.3
local panelSettleDistance = 0.001
local hiddenPanelWidthMultiplier = 2

local positionSpringKey = "panelPosition"
local positionTrackKey = "panelPositionTrack"

export type InventoryPanelAnimator = {
	panel: Frame?,
	animator: any,
	renderConnection: RBXScriptConnection?,
	openPositionX: number,
	hiddenPositionX: number,
	isOpen: boolean,
	destroyed: boolean,
	setOpen: (self: InventoryPanelAnimator, isOpen: boolean) -> (),
	destroy: (self: InventoryPanelAnimator) -> (),
	_start: (self: InventoryPanelAnimator) -> (),
	_stop: (self: InventoryPanelAnimator) -> (),
	_update: (self: InventoryPanelAnimator, deltaTime: number) -> (),
}

local inventoryPanelAnimator = {}
inventoryPanelAnimator.__index = inventoryPanelAnimator

function inventoryPanelAnimator._stop(self: InventoryPanelAnimator): ()
	local renderConnection = self.renderConnection
	if renderConnection == nil then
		return
	end

	renderConnection:Disconnect()
	self.renderConnection = nil
end

function inventoryPanelAnimator._update(self: InventoryPanelAnimator, deltaTime: number): ()
	local animator = self.animator
	local panel = self.panel
	if animator == nil or panel == nil then
		self:_stop()
		return
	end

	animator:applyTracks(deltaTime)
	if not animator:isSpringSettled(positionSpringKey, panelSettleDistance, panelSettleDistance) then
		return
	end

	local settledPositionX = if self.isOpen then self.openPositionX else self.hiddenPositionX
	animator:snapSpring(positionSpringKey, Vector2.new(settledPositionX, 0))
	if not self.isOpen then
		panel.Visible = false
	end
	self:_stop()
end

function inventoryPanelAnimator._start(self: InventoryPanelAnimator): ()
	if self.destroyed or self.renderConnection ~= nil then
		return
	end

	self.renderConnection = runService.RenderStepped:Connect(function(deltaTime: number)
		self:_update(deltaTime)
	end)
end

function inventoryPanelAnimator.setOpen(self: InventoryPanelAnimator, isOpen: boolean): ()
	if self.destroyed or self.isOpen == isOpen then
		return
	end

	local panel = self.panel
	local animator = self.animator
	if panel == nil or animator == nil then
		return
	end

	self.isOpen = isOpen
	if isOpen then
		panel.Visible = true
	end

	local targetPositionX = if isOpen then self.openPositionX else self.hiddenPositionX
	animator:setSpring(positionSpringKey, Vector2.new(targetPositionX, 0))
	self:_start()
end

function inventoryPanelAnimator.destroy(self: InventoryPanelAnimator): ()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self:_stop()
	local animator = self.animator
	self.animator = nil
	if animator then
		animator:destroy()
	end
	self.panel = nil
end

function inventoryPanelAnimator.new(panel: Frame): InventoryPanelAnimator
	local basePosition = panel.Position
	local openPositionX = basePosition.X.Scale
	local hiddenPositionX = openPositionX - panel.Size.X.Scale * hiddenPanelWidthMultiplier
	local animator = GuiAnimator.new(panel)
	animator:addScalarSpring(
		positionSpringKey,
		hiddenPositionX,
		panelSpringFrequency,
		panelSpringDamping,
		panelSpringMass,
		panelSpringSpeed
	)
	animator:addNumberSpringTrack(positionTrackKey, function(positionX: number)
		panel.Position = UDim2.new(positionX, basePosition.X.Offset, basePosition.Y.Scale, basePosition.Y.Offset)
	end, positionSpringKey, 0)

	panel.Position = UDim2.new(hiddenPositionX, basePosition.X.Offset, basePosition.Y.Scale, basePosition.Y.Offset)
	panel.Visible = false

	local self: InventoryPanelAnimator = (
		setmetatable({
			panel = panel,
			animator = animator,
			renderConnection = nil,
			openPositionX = openPositionX,
			hiddenPositionX = hiddenPositionX,
			isOpen = false,
			destroyed = false,
		}, inventoryPanelAnimator) :: unknown
	) :: InventoryPanelAnimator

	return self
end

return inventoryPanelAnimator
