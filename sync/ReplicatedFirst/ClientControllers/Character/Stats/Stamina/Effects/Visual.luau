local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local clientData = require(replicatedFirst.ClientData)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local player = players.LocalPlayer

local config = {
	startStamina = 40,
	maxBlur = 12,
	maxDesaturation = -0.6,
	maxVignetteTransparency = 0.5,
	lerpSpeed = 8,

	exhaustion = {
		fovReduction = 8,
		fovLerpSpeed = 3,
		pulseSpeed = 0.8,
		pulseBlurAmount = 4,
		pulseSaturationAmount = 0.15,
		pulseFovAmount = 2,
	},
}

local visualEffectsController = {}
visualEffectsController.__index = visualEffectsController

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

function visualEffectsController:bindCharacter(character: Model?)
	self.character = character
end

function visualEffectsController:reset()
	self.currentIntensity = 0
	self.currentFovOffset = 0
	self.pulseTime = 0

	if self.blurEffect then
		self.blurEffect.Size = 0
	end

	if self.colorEffect then
		self.colorEffect.Saturation = 0
	end

	if self.vignette then
		self.vignette.ImageTransparency = 1
	end

	clientData.fieldOfViewModifiers.staminaExhaustion = 0
end

function visualEffectsController:update(deltaTime: number)
	local character = self.character
	if character == nil or character.Parent == nil then
		return
	end

	local stamina = character:GetAttribute("Stamina")
	local staminaMax = character:GetAttribute("StaminaMax")
	if type(stamina) ~= "number" or type(staminaMax) ~= "number" or staminaMax <= 0 then
		return
	end

	local isExhausted = character:GetAttribute("Exhausted") == true

	local staminaPercent = (stamina / staminaMax) * 100
	local staminaDifference = config.startStamina - staminaPercent
	local targetIntensity = math.clamp(staminaDifference / config.startStamina, 0, 1) ^ 1.5

	local alpha = mathUtilities.exponentialAlpha(config.lerpSpeed, deltaTime)
	self.currentIntensity = mathUtilities.lerp(self.currentIntensity, targetIntensity, alpha)

	local intensity = self.currentIntensity
	local exhaustionConfig = config.exhaustion

	--// Pulse while exhausted.
	local pulseValue = 0
	if isExhausted then
		self.pulseTime += deltaTime * exhaustionConfig.pulseSpeed
		pulseValue = (math.sin(self.pulseTime * math.pi * 2) + 1) / 2
	else
		self.pulseTime = 0
	end

	local pulseBlur = pulseValue * exhaustionConfig.pulseBlurAmount * intensity
	local pulseSaturation = pulseValue * exhaustionConfig.pulseSaturationAmount * intensity
	local pulseFov = pulseValue * exhaustionConfig.pulseFovAmount * intensity

	self.blurEffect.Size = config.maxBlur * intensity + pulseBlur
	self.colorEffect.Saturation = config.maxDesaturation * intensity - pulseSaturation

	local vignetteTransparency = 1 - (1 - config.maxVignetteTransparency) * intensity
	self.vignette.ImageTransparency = vignetteTransparency

	--// FOV zoom-in while exhausted — uses the shared modifier system so other FOV
	--// sources (Movement, AI standoff, etc.) compose correctly.
	local targetFovOffset = isExhausted and -exhaustionConfig.fovReduction or 0
	local fovAlpha = mathUtilities.exponentialAlpha(exhaustionConfig.fovLerpSpeed, deltaTime)
	self.currentFovOffset = mathUtilities.lerp(self.currentFovOffset, targetFovOffset, fovAlpha)

	clientData.fieldOfViewModifiers.staminaExhaustion = self.currentFovOffset - pulseFov
end

function visualEffectsController.new(parentController)
	local self = setmetatable({}, visualEffectsController)

	self.character = parentController.character
	self.currentIntensity = 0
	self.currentFovOffset = 0
	self.pulseTime = 0

	local currentCamera = workspace.CurrentCamera

	self.blurEffect = getOrCreateEffect("StaminaBlur", "BlurEffect", currentCamera)
	self.blurEffect.Size = 0

	self.colorEffect = getOrCreateEffect("StaminaColor", "ColorCorrectionEffect", currentCamera)
	self.colorEffect.Saturation = 0

	local interface = player.PlayerGui:WaitForChild("Interface")
	local vignettes = interface:WaitForChild("Vignettes")
	local defaultVignette = vignettes:WaitForChild("Default")

	local vignette: ImageLabel = defaultVignette:Clone()
	vignette.Name = "Exhaustion"
	vignette.ImageColor3 = Color3.new(1, 1, 1)
	vignette.ImageTransparency = 1
	vignette.ZIndex = 0
	vignette.Parent = vignettes
	self.vignette = vignette

	return self
end

function visualEffectsController:destroy()
	self:reset()

	if self.blurEffect then
		self.blurEffect:Destroy()
		self.blurEffect = nil
	end

	if self.colorEffect then
		self.colorEffect:Destroy()
		self.colorEffect = nil
	end

	if self.vignette then
		self.vignette:Destroy()
		self.vignette = nil
	end

	setmetatable(self, nil)
end

return visualEffectsController
