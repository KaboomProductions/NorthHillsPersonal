local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local player = players.LocalPlayer
local playerGui = player.PlayerGui

local interface = playerGui:WaitForChild("Interface")
local vignettesFrame = interface.Vignettes

local staticFrame = vignettesFrame.Static
local staticVignette = staticFrame.Vignette

local sharedUtilities = replicatedStorage.SharedUtilities
local mathUtilities = require(sharedUtilities.MathUtils)

local staticEffectController = {}
staticEffectController.__index = staticEffectController
staticEffectController.__vars = {
	imageSpeed = 8,
	imageMinIntensity = 0.3,
	imageMaxIntensity = 1,
}

function staticEffectController.new()
	local self = setmetatable({}, staticEffectController)

	self.imageCurrent = 1
	self.imageTarget = 1
	self.active = false
	self.lastUpdate = os.clock()
	self.rng = Random.new()

	return self
end

function staticEffectController:start(_profile: { any })
	self.active = true
end

function staticEffectController:update(deltaTime: number, intensity: number)
	self.imageTarget = self.active
			and mathUtilities.lerp(self.__vars.imageMaxIntensity, self.__vars.imageMinIntensity, intensity)
		or 1

	self.imageCurrent =
		mathUtilities.exponentialLerp(self.imageCurrent, self.imageTarget, self.__vars.imageSpeed, deltaTime)

	if os.clock() - self.lastUpdate > 1 / 60 then
		staticFrame.Size = UDim2.fromScale(self.rng:NextNumber(2, 2.5), self.rng:NextNumber(2, 2.5))
		staticFrame.Rotation = self.rng:NextNumber() < 0.5 and 0 or 180

		self.lastUpdate = os.clock()
	end

	staticVignette.ImageTransparency = self.imageCurrent
end

function staticEffectController:stop()
	self.active = false
end

return staticEffectController
