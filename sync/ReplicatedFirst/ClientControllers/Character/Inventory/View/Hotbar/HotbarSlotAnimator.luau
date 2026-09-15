--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local selectionLerpSpeed = 10
local selectionSettleDistance = 0.001

type SelectionProgressSource = (() -> number) & ((selectionProgress: number) -> number)

export type HotbarSlotAnimator = {
	selectionProgress: SelectionProgressSource,
	targetSelectionProgress: number,
	renderConnection: RBXScriptConnection?,
	destroyed: boolean,
	setSelected: (self: HotbarSlotAnimator, isSelected: boolean) -> (),
	destroy: (self: HotbarSlotAnimator) -> (),
	_startAnimation: (self: HotbarSlotAnimator) -> (),
	_stopAnimation: (self: HotbarSlotAnimator) -> (),
	_updateAnimation: (self: HotbarSlotAnimator, deltaTime: number) -> (),
}

local hotbarSlotAnimator = {}
hotbarSlotAnimator.__index = hotbarSlotAnimator

function hotbarSlotAnimator._stopAnimation(self: HotbarSlotAnimator): ()
	local renderConnection = self.renderConnection
	if renderConnection == nil then
		return
	end

	renderConnection:Disconnect()
	self.renderConnection = nil
end

function hotbarSlotAnimator._updateAnimation(self: HotbarSlotAnimator, deltaTime: number): ()
	local currentSelectionProgress = self.selectionProgress()
	local progressDistance = math.abs(self.targetSelectionProgress - currentSelectionProgress)
	if progressDistance <= selectionSettleDistance then
		self.selectionProgress(self.targetSelectionProgress)
		self:_stopAnimation()
		return
	end

	local lerpAlpha = 1 - math.exp(-selectionLerpSpeed * deltaTime)
	self.selectionProgress(math.lerp(currentSelectionProgress, self.targetSelectionProgress, lerpAlpha))
end

function hotbarSlotAnimator._startAnimation(self: HotbarSlotAnimator): ()
	if self.destroyed or self.renderConnection ~= nil then
		return
	end

	self.renderConnection = runService.RenderStepped:Connect(function(deltaTime: number)
		self:_updateAnimation(deltaTime)
	end)
end

function hotbarSlotAnimator.setSelected(self: HotbarSlotAnimator, isSelected: boolean): ()
	local targetSelectionProgress = if isSelected then 1 else 0
	if self.targetSelectionProgress == targetSelectionProgress then
		return
	end

	self.targetSelectionProgress = targetSelectionProgress
	if math.abs(targetSelectionProgress - self.selectionProgress()) <= selectionSettleDistance then
		self.selectionProgress(targetSelectionProgress)
		self:_stopAnimation()
		return
	end

	self:_startAnimation()
end

function hotbarSlotAnimator.destroy(self: HotbarSlotAnimator): ()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self:_stopAnimation()
end

function hotbarSlotAnimator.new(isSelected: boolean): HotbarSlotAnimator
	local initialSelectionProgress = if isSelected then 1 else 0
	local self: HotbarSlotAnimator = (
		setmetatable({
			selectionProgress = vide.source(initialSelectionProgress),
			targetSelectionProgress = initialSelectionProgress,
			renderConnection = nil,
			destroyed = false,
		}, hotbarSlotAnimator) :: unknown
	) :: HotbarSlotAnimator

	return self
end

return hotbarSlotAnimator
