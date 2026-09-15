local replicatedStorage = game:GetService("ReplicatedStorage")

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local visual = {}
visual.__index = visual

local function getOrCreateEffect(name: string, className: string, parent: Instance): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end

	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = parent
	return effect
end

local function fetchEffects(): (BlurEffect, ColorCorrectionEffect)
	local currentCamera = workspace.CurrentCamera

	local blur = getOrCreateEffect("HealthBlur", "BlurEffect", currentCamera)
	blur.Size = 0

	local colorCorrection = getOrCreateEffect("HealthColor", "ColorCorrectionEffect", currentCamera)
	colorCorrection.Brightness = 0
	colorCorrection.TintColor = Color3.new(1, 1, 1)

	return blur, colorCorrection
end

function visual.new(newInfo)
	local self = setmetatable({}, visual)

	self.config = newInfo.config
	self.bloodShot = newInfo.bloodShot
	self.baseSize = self.bloodShot.Size
	self.originalPosition = self.bloodShot.Position
	self.originalRotation = self.bloodShot.Rotation
	self.currentShakeOffset = Vector2.zero
	self.currentShakeRotation = 0
	self.bloodShotPulse = 0

	local blurEffect, colorEffect = fetchEffects()
	self.blurEffect = blurEffect
	self.colorEffect = colorEffect
	self.currentBlur = 0
	self.currentBrightness = 0
	self.currentTint = Color3.new(1, 1, 1)
	self.startHealthInverse = 1 / self.config.shakeConfig.startHealth
	self.pulseScale = 5

	self:reset()

	return self
end

function visual:reset()
	local bloodShot = self.bloodShot

	bloodShot.ImageTransparency = 1
	bloodShot.Size = self.baseSize
	bloodShot.Position = self.originalPosition
	bloodShot.Rotation = self.originalRotation

	if self.blurEffect then
		self.blurEffect.Size = 0
	end

	if self.colorEffect then
		self.colorEffect.Brightness = 0
		self.colorEffect.TintColor = Color3.new(1, 1, 1)
	end

	self.currentShakeOffset = Vector2.zero
	self.currentShakeRotation = 0
	self.bloodShotPulse = 0
	self.currentBlur = 0
	self.currentBrightness = 0
	self.currentTint = Color3.new(1, 1, 1)
end

function visual:update(deltaTime: number, healthAverage: number, pulse: number)
	local config = self.config
	local bloodShot = self.bloodShot
	local uiAlpha = mathUtilities.exponentialAlpha(config.lerpSpeed.userInterface, deltaTime)

	local targetTransparency = math.clamp(
		healthAverage + config.bloodShotConfig.minTransparency,
		config.bloodShotConfig.minTransparency,
		config.bloodShotConfig.maxTransparency
	)
	bloodShot.ImageTransparency = mathUtilities.lerp(bloodShot.ImageTransparency, targetTransparency, uiAlpha)

	local pulseAlpha = mathUtilities.exponentialAlpha(config.lerpSpeed.pulse, deltaTime)
	self.bloodShotPulse = mathUtilities.lerp(self.bloodShotPulse, pulse, pulseAlpha)

	local healthPercent = healthAverage * 100
	local healthDifference = config.shakeConfig.startHealth - healthPercent
	local shakeIntensity = math.clamp(healthDifference * self.startHealthInverse, 0, 1) ^ 2

	local positionStrength = config.shakeConfig.maxPosition * shakeIntensity
	local rotationStrength = config.shakeConfig.maxRotation * shakeIntensity
	local targetShakeOffset =
		Vector2.new((math.random() - 0.5) * 2 * positionStrength, (math.random() - 0.5) * 2 * positionStrength)
	local targetShakeRotation = (math.random() - 0.5) * 2 * rotationStrength
	local shakeAlpha = mathUtilities.exponentialAlpha(config.shakeConfig.shakeSpeed, deltaTime)
	local returnAlpha = mathUtilities.exponentialAlpha(config.shakeConfig.returnSpeed, deltaTime)

	self.currentShakeOffset = mathUtilities.lerp(self.currentShakeOffset, targetShakeOffset, shakeAlpha)
	self.currentShakeOffset = mathUtilities.lerp(self.currentShakeOffset, Vector2.zero, returnAlpha)
	self.currentShakeRotation = mathUtilities.lerp(self.currentShakeRotation, targetShakeRotation, shakeAlpha)
	self.currentShakeRotation = mathUtilities.lerp(self.currentShakeRotation, 0, returnAlpha)

	local shakeZoom = config.bloodShotConfig.maxShakeZoom * shakeIntensity
	local totalZoom = self.bloodShotPulse + shakeZoom

	--// Scale zoom to cover edges exposed by shake offset.
	local offsetMagnitude = self.currentShakeOffset.Magnitude
	local edgeCoverZoom = (offsetMagnitude / config.shakeConfig.maxPosition)
		* config.bloodShotConfig.edgeCoverZoom
		* shakeIntensity

	bloodShot.Size = self.baseSize + UDim2.fromScale(totalZoom + edgeCoverZoom, totalZoom + edgeCoverZoom)
	bloodShot.Position = self.originalPosition + UDim2.fromOffset(self.currentShakeOffset.X, self.currentShakeOffset.Y)
	bloodShot.Rotation = self.originalRotation + self.currentShakeRotation

	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		currentCamera.CFrame = currentCamera.CFrame
			* mathUtilities.getCameraShake(shakeIntensity * config.shakeConfig.screenShakeMultiplier, deltaTime / 5)
	end

	local blurIntensity = ((1 - healthAverage) / 2) ^ 2
	local targetBlur = config.blurConfig.maxBlur * blurIntensity
		+ config.blurConfig.pulseBlur * (self.bloodShotPulse * self.pulseScale)
	local blurAlpha = mathUtilities.exponentialAlpha(config.blurConfig.lerpSpeed, deltaTime)

	self.currentBlur = mathUtilities.lerp(self.currentBlur, targetBlur, blurAlpha)
	self.blurEffect.Size = self.currentBlur

	local targetBrightness = -(
		config.colorConfig.maxDarken * blurIntensity
		+ config.colorConfig.pulseDarken * (self.bloodShotPulse * self.pulseScale)
	)
	local colorAlpha = mathUtilities.exponentialAlpha(config.colorConfig.lerpSpeed, deltaTime)

	self.currentBrightness = mathUtilities.lerp(self.currentBrightness, targetBrightness, colorAlpha)
	self.colorEffect.Brightness = self.currentBrightness

	local redAmount = math.clamp(
		config.colorConfig.redTint * blurIntensity
			+ config.colorConfig.pulseRed * (self.bloodShotPulse * self.pulseScale),
		0,
		1
	)
	local targetTint = Color3.new(1, 1 - redAmount, 1 - redAmount)

	self.currentTint = self.currentTint:Lerp(targetTint, colorAlpha)
	self.colorEffect.TintColor = self.currentTint
end

function visual:destroy()
	self:reset()

	if self.blurEffect then
		self.blurEffect:Destroy()
		self.blurEffect = nil
	end

	if self.colorEffect then
		self.colorEffect:Destroy()
		self.colorEffect = nil
	end
end

return visual
