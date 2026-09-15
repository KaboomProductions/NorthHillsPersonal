local players = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local audioModule = require(script.Audio)
local visualModule = require(script.Visual)

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local player = players.LocalPlayer
local staminaEffectsController = {}
staminaEffectsController.__index = staminaEffectsController

local config = {
	barConfig = {
		transparencyThreshold = 0.001,
		uiLerpSpeed = 10,
	},
}

local function getHumanoid(character: Model?): Humanoid?
	if character == nil or character.Parent == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function staminaEffectsController:preload()
	local interface = player.PlayerGui:WaitForChild("Interface")
	local progressBars = interface:WaitForChild("ProgressBars")
	local staminaBar = progressBars.ProgressBarList.Stamina
	local staminaBarFill = staminaBar.BarBackground.BarFill

	self.staminaBar = staminaBar
	self.staminaBarGradient = staminaBarFill.UIGradient
end

function staminaEffectsController:bindCharacter(character: Model?)
	self.character = character

	if self.audio then
		self.audio:bindCharacter(character)
	end

	if self.visual then
		self.visual:bindCharacter(character)
	end
end

function staminaEffectsController:updateStaminaBarGradient(average: number)
	local cachedAverage = self.gradientCacheAverage
	local transparencyThreshold = config.barConfig.transparencyThreshold

	if cachedAverage ~= nil and math.abs(cachedAverage - average) <= transparencyThreshold then
		return
	end

	self.gradientCacheAverage = average

	local clampedAverage = math.clamp(average, 0, 1)
	local clampedAverageMinus = math.clamp(clampedAverage - transparencyThreshold, 0, 1)

	self.staminaBarGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(clampedAverageMinus, 0),
		NumberSequenceKeypoint.new(clampedAverage, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

function staminaEffectsController:reset()
	self.lerpedStaminaAverage = 1
	self.gradientCacheAverage = nil
	--self.audio:reset()
	self.visual:reset()
end

function staminaEffectsController:init()
	self:preload()
	self.audio = audioModule.new(self.parentController)
	self.visual = visualModule.new(self.parentController)
	self:bindCharacter(self.parentController.character)

	runService:UnbindFromRenderStep("StaminaBar")
	runService:BindToRenderStep("StaminaBar", Enum.RenderPriority.Last.Value, function(deltaTime: number)
		local character = self.parentController.character
		local humanoid = getHumanoid(character)
		if humanoid == nil then
			return
		end

		if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
			self:reset()
			return
		end

		local maximumStamina = character:GetAttribute("StaminaMax")
		local currentStamina = character:GetAttribute("Stamina")
		local staminaAverage = currentStamina / maximumStamina
		local uiAlpha = mathUtilities.exponentialAlpha(config.barConfig.uiLerpSpeed, deltaTime)

		self.lerpedStaminaAverage = mathUtilities.lerp(self.lerpedStaminaAverage, staminaAverage, uiAlpha)
		self:updateStaminaBarGradient(self.lerpedStaminaAverage)
		self.staminaBar:SetAttribute("Full", staminaAverage >= 1)
	end)
end

function staminaEffectsController.new(parentController)
	local self = setmetatable({}, staminaEffectsController)

	self.parentController = parentController
	self.character = nil
	self.audio = nil
	self.visual = nil
	self.lerpedStaminaAverage = 1
	self.gradientCacheAverage = nil
	self.staminaBar = nil
	self.staminaBarGradient = nil

	task.defer(self.init, self)

	return self
end

function staminaEffectsController:destroy()
	runService:UnbindFromRenderStep("StaminaBar")

	if self.audio then
		self.audio:destroy()
		self.audio = nil
	end

	if self.visual then
		self.visual:destroy()
		self.visual = nil
	end

	setmetatable(self, nil)
end

return staminaEffectsController
