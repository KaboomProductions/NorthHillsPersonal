local superSonicController = {}
superSonicController.__index = superSonicController
superSonicController.__vars = {
	startTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear),
	endTweenInfo = TweenInfo.new(2, Enum.EasingStyle.Linear),

	activeTweens = {},

	startBlurSize = 32,
	startSaturation = -1,

	endDelayTime = 2,

	shakeFadeInSpeed = 3.5,
	shakeFadeOutSpeed = 1.5,
	maxShakeStrength = 0.2,
}

local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")

local currentCamera = workspace.CurrentCamera

local sharedUtilities = replicatedStorage.SharedUtilities

local audioUtilities = require(sharedUtilities.AudioUtils)
local mathUtilities = require(sharedUtilities.MathUtils)

local clientData = require(replicatedFirst.ClientData)
local movementConfig = clientData.clientConfig.movement
local speedPresets = movementConfig.speedPresets

function superSonicController:cleanupEffects()
	for tweenName, activeTween in self.tweens do
		activeTween:Cancel()
		self.tweens[tweenName] = nil
	end

	for effectName, effect in self.effects do
		effect:Destroy()
		self.effects[effectName] = nil
	end
end

function superSonicController:onNewEvent(eventType: string)
	if eventType ~= "start" and eventType ~= "end" then
		return
	end

	local designatedTweenInfo = eventType == "start" and self.__vars.startTweenInfo or self.__vars.endTweenInfo
	local equalizerPayload = {
		HighGain = 0,
		MidGain = 0,
		LowGain = 0,
	}

	if self.endThread then
		task.cancel(self.endThread)
		self.endThread = nil
	end

	for tweenName, activeTween in self.tweens do
		activeTween:Cancel()
		self.tweens[tweenName] = nil
	end

	if eventType == "start" then
		self:cleanupEffects()

		equalizerPayload = {
			HighGain = -55,
			MidGain = -30,
			LowGain = -8,
		}

		self.targetShakeStrength = self.__vars.maxShakeStrength
		clientData.speedModifiers.superSonic = -speedPresets.walking / 2

		local colorCorrectionEffect = Instance.new("ColorCorrectionEffect")
		local blurEffect = Instance.new("BlurEffect")

		blurEffect.Size = 0

		blurEffect.Parent = currentCamera
		colorCorrectionEffect.Parent = currentCamera

		self.effects.colorCorrection = colorCorrectionEffect
		self.effects.blur = blurEffect
	else
		self.targetShakeStrength = 0
		clientData.speedModifiers.superSonic = nil

		if not self.effects.colorCorrection or not self.effects.blur then
			audioUtilities.applyEqualizerToSoundGroups({
				tweenInfo = designatedTweenInfo,
				equalizerId = "screamTest",
				properties = equalizerPayload,
			})
			return
		end
	end

	self.tweens.colorCorrection = tweenService:Create(self.effects.colorCorrection, designatedTweenInfo, {
		Saturation = eventType == "start" and self.__vars.startSaturation or 0,
	})

	self.tweens.blur = tweenService:Create(self.effects.blur, designatedTweenInfo, {
		Size = eventType == "start" and self.__vars.startBlurSize or 0,
	})

	for _, tween in self.tweens do
		tween:Play()
	end

	if eventType == "end" then
		self.endThread = task.delay(self.__vars.endDelayTime, function()
			self.endThread = nil
			if getmetatable(self) then
				self:cleanupEffects()
			end
		end)
	end

	audioUtilities.applyEqualizerToSoundGroups({
		tweenInfo = designatedTweenInfo,
		equalizerId = "screamTest",
		properties = equalizerPayload,
	})
end

function superSonicController:init()
	self.connections.updateSuperSonic = runService.RenderStepped:Connect(function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function superSonicController.new(ancestor)
	local self = setmetatable({}, superSonicController)

	self.shakeStrength = 0
	self.targetShakeStrength = 0
	self.shakeTime = 0

	self.effects = {}
	self.tweens = {}
	self.connections = ancestor.connections
	self.__vars = table.clone(superSonicController.__vars)

	task.defer(self.init, self)

	return self
end

function superSonicController:update(deltaTime: number)
	self.shakeTime = self.shakeTime + deltaTime

	local designatedLerpSpeed = self.targetShakeStrength > self.shakeStrength and self.__vars.shakeFadeInSpeed
		or self.__vars.shakeFadeOutSpeed

	local lerpAlpha = math.clamp(deltaTime * designatedLerpSpeed, 0, 1)
	self.shakeStrength = self.shakeStrength + (self.targetShakeStrength - self.shakeStrength) * lerpAlpha

	if self.shakeStrength <= 0.001 then
		return
	end

	currentCamera.CFrame *= mathUtilities.getCameraShake(self.shakeStrength, deltaTime)
end

function superSonicController:destroy()
	if self.endThread then
		task.cancel(self.endThread)
		self.endThread = nil
	end

	self.targetShakeStrength = 0
	self.shakeStrength = 0
	clientData.speedModifiers.superSonic = nil
	self:cleanupEffects()

	audioUtilities.applyEqualizerToSoundGroups({
		tweenInfo = TweenInfo.new(0),
		equalizerId = "screamTest",
		properties = {
			HighGain = 0,
			MidGain = 0,
			LowGain = 0,
		},
	})

	setmetatable(self, nil)
end

return superSonicController
