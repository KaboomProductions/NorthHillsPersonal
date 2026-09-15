local replicatedStorage = game:GetService("ReplicatedStorage")

local currentCamera = workspace.CurrentCamera

local sharedUtilities = replicatedStorage.SharedUtilities
local mathUtilities = require(sharedUtilities.MathUtils)

local cameraShakeEffectController = {}
cameraShakeEffectController.__index = cameraShakeEffectController
cameraShakeEffectController.__vars = {
	speed = 8,
	minIntensity = 0.005,
	maxIntensity = 0.015,
}

function cameraShakeEffectController.new()
	local self = setmetatable({}, cameraShakeEffectController)

	self.target = 0
	self.current = 0
	self.active = false

	return self
end

function cameraShakeEffectController:start(_profile: { any })
	self.active = true
end

function cameraShakeEffectController:update(deltaTime: number, intensity: number)
	self.target = self.active and mathUtilities.lerp(self.__vars.minIntensity, self.__vars.maxIntensity, intensity) or 0
	self.current = mathUtilities.exponentialLerp(self.current, self.target, self.__vars.speed, deltaTime)

	if self.current > 0.001 then
		currentCamera.CFrame = currentCamera.CFrame * mathUtilities.getCameraShake(self.current, deltaTime)
	end
end

function cameraShakeEffectController:stop()
	self.active = false
end

return cameraShakeEffectController
