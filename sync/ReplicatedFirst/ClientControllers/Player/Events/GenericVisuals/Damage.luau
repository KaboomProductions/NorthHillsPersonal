local damageController = {}
damageController.__index = damageController
damageController.__vars = {
	fadeInSpeed = 10,
	fadeOutSpeed = 4,

	maxTintStrength = 0.45,

	shakeFadeInSpeed = 18,
	shakeFadeOutSpeed = 8,

	maxShakeStrength = 0.1,
	shakeDuration = 0.15,
}

local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local currentCamera = workspace.CurrentCamera

local sharedUtilities = replicatedStorage.SharedUtilities
local mathUtilities = require(sharedUtilities.MathUtils)

local function lerp(a, b, t)
	return a + (b - a) * t
end

function damageController:onNewEvent()
	self.targetTintStrength = self.__vars.maxTintStrength
	self.targetShakeStrength = self.__vars.maxShakeStrength

	self.shakeTime = self.__vars.shakeDuration
end

function damageController:init()
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.TintColor = Color3.new(1, 1, 1)
	colorCorrection.Parent = currentCamera

	self.effects.colorCorrection = colorCorrection

	table.insert(
		self.connections,
		runService.RenderStepped:Connect(function(deltaTime)
			self:update(deltaTime)
		end)
	)
end

function damageController:update(deltaTime: number)
	if self.shakeTime > 0 then
		self.shakeTime = self.shakeTime - deltaTime

		if self.shakeTime <= 0 then
			self.targetTintStrength = 0
			self.targetShakeStrength = 0
		end
	end

	local shakeLerpSpeed = self.targetShakeStrength > self.shakeStrength and self.__vars.shakeFadeInSpeed
		or self.__vars.shakeFadeOutSpeed

	local tintLerpSpeed = self.targetTintStrength > self.tintStrength and self.__vars.fadeInSpeed
		or self.__vars.fadeOutSpeed

	local tintAlpha = math.clamp(deltaTime * tintLerpSpeed, 0, 1)
	local shakeAlpha = math.clamp(deltaTime * shakeLerpSpeed, 0, 1)

	self.tintStrength = lerp(self.tintStrength, self.targetTintStrength, tintAlpha)
	self.effects.colorCorrection.TintColor = Color3.new(1, 1 - self.tintStrength, 1 - self.tintStrength)

	self.shakeStrength = lerp(self.shakeStrength, self.targetShakeStrength, shakeAlpha)

	if self.shakeStrength > 0.001 then
		currentCamera.CFrame *= mathUtilities.getCameraShake(self.shakeStrength, deltaTime)
	end
end

function damageController:destroy()
	if self.effects.colorCorrection then
		self.effects.colorCorrection:Destroy()
		self.effects.colorCorrection = nil
	end

	setmetatable(self, nil)
end

function damageController.new(ancestor)
	local self = setmetatable({}, damageController)

	self.shakeStrength = 0
	self.targetShakeStrength = 0

	self.tintStrength = 0
	self.targetTintStrength = 0

	self.shakeTime = 0

	self.effects = {}
	self.connections = ancestor.connections
	self.__vars = table.clone(damageController.__vars)

	task.defer(self.init, self)

	return self
end

return damageController
