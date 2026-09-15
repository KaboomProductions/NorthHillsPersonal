local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local audioModule = require(script.Audio)
local visualModule = require(script.Visual)

local player = players.LocalPlayer
local healthEffectController = {}
healthEffectController.__index = healthEffectController

local config = {
	audioConfig = {
		healthMultiplier = 0.75,
		basePitch = 0.85,
		maxVolumeScale = 1 / 1.5,
		volumeThreshold = 0.01,
		pulseMultiplier = 0.0005,
		heartBeatLerpSpeed = 12,
		fadeLerpSpeed = 6,
	},
	visualConfig = {
		bloodShotConfig = {
			maxTransparency = 1,
			minTransparency = 0.18,
			maxShakeZoom = 0.15,
			edgeCoverZoom = 0.3,
		},
		blurConfig = {
			maxBlur = 25,
			pulseBlur = 35,
			lerpSpeed = 15,
		},
		colorConfig = {
			maxDarken = 0.35,
			pulseDarken = 0.035,
			redTint = 0.45,
			pulseRed = 0.075,
			lerpSpeed = 5,
		},
		lerpSpeed = {
			userInterface = 10,
			pulse = 18,
		},
		shakeConfig = {
			startHealth = 45,
			maxPosition = 25,
			maxRotation = 8,
			shakeSpeed = 30,
			returnSpeed = 8,
			screenShakeMultiplier = 0.035,
		},
	},
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

function healthEffectController:preload()
	local interface = player.PlayerGui:WaitForChild("Interface")
	local progressBars = interface.ProgressBars
	local healthBar = progressBars.ProgressBarList.Health
	local healthBarFill = healthBar.BarBackground.BarFill

	self.healthBar = healthBar
	self.healthBarGradient = healthBarFill.UIGradient
	self.bloodShot = interface.Vignettes.Bloodshot
end

function healthEffectController:updateHealthBarGradient(average: number)
	local cachedAverage = self.gradientCacheAverage
	local transparencyThreshold = config.barConfig.transparencyThreshold
	if cachedAverage ~= nil and math.abs(cachedAverage - average) <= transparencyThreshold then
		return
	end

	self.gradientCacheAverage = average

	local clampedAverage = math.clamp(average, 0, 1)
	local clampedAverageMinus = math.clamp(clampedAverage - transparencyThreshold, 0, 1)

	self.healthBarGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(clampedAverageMinus, 0),
		NumberSequenceKeypoint.new(clampedAverage, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

function healthEffectController:reset()
	self.lerpedHealthAverage = 1
	self.gradientCacheAverage = nil
	self.audio:reset()
	self.visual:reset()
end

function healthEffectController:init()
	self:preload()
	self.audio = audioModule.new(config)
	self.visual = visualModule.new({
		bloodShot = self.bloodShot,
		config = config.visualConfig,
	})

	runService:UnbindFromRenderStep("HealthEffects")
	runService:BindToRenderStep("HealthEffects", Enum.RenderPriority.Character.Value, function(deltaTime: number)
		local character = self.parentController.character
		local humanoid = getHumanoid(character)
		if humanoid == nil then
			return
		end

		if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
			self:reset()
			return
		end

		local maximumHealth = humanoid.MaxHealth
		local currentHealth = humanoid.Health
		local healthAverage = currentHealth / maximumHealth
		local uiAlpha = mathUtilities.exponentialAlpha(config.barConfig.uiLerpSpeed, deltaTime)

		self.lerpedHealthAverage = mathUtilities.lerp(self.lerpedHealthAverage, healthAverage, uiAlpha)
		self:updateHealthBarGradient(self.lerpedHealthAverage)
		self.healthBar:SetAttribute("Full", healthAverage >= 1)

		local pulse = self.audio:update(deltaTime, currentHealth, maximumHealth)
		self.visual:update(deltaTime, healthAverage, pulse)
	end)
end

function healthEffectController.new(parentController)
	local self = setmetatable({}, healthEffectController)

	self.parentController = parentController
	self.lerpedHealthAverage = 1
	self.gradientCacheAverage = nil
	self.audio = nil
	self.visual = nil
	self.healthBar = nil
	self.healthBarGradient = nil
	self.bloodShot = nil

	task.defer(self.init, self)

	return self
end

function healthEffectController:destroy()
	runService:UnbindFromRenderStep("HealthEffects")

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

return healthEffectController
