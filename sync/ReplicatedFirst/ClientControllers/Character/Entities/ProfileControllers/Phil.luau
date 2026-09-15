local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

local player = players.LocalPlayer
local currentCamera = workspace.CurrentCamera

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local mathUtilities = require(sharedUtilities.MathUtils)
local bucketUtilities = require(sharedUtilities.BucketUtils)

local effects = sharedAssets.Effects
local sounds = effects.Sounds
local entitySounds = sounds.Entities

local themeSounds = entitySounds.Themes
local philThemeSounds = themeSounds.Phil
local chaseThemeSound = philThemeSounds.Chase
local afterChaseThemeSound = philThemeSounds.AfterChase
local combatThemeSound = philThemeSounds.Combat
local chaseEndStingerSound = entitySounds.ChaseEndStinger
local stingerSounds = entitySounds.Stingers:GetChildren()

local philProfileController = {}
philProfileController.__index = philProfileController
philProfileController.__vars = {
	properties = {
		colorCorrection = {
			start = {
				TintColor = Color3.new(1, 1, 0),
				Contrast = 2,
				Saturation = 40,
				Brightness = 1,
			},

			stop = {
				TintColor = Color3.new(1, 1, 1),
				Contrast = 0,
				Saturation = 0,
				Brightness = 0,
			},
		},
	},

	fadeSpeeds = {
		[chaseThemeSound] = 2,
		[combatThemeSound] = 2.5,
		[afterChaseThemeSound] = 0.5,
	},

	afterChaseLength = 15,
	maxFadeTime = 0.5,
}

function philProfileController:getFadeSpeed(sound: Sound)
	return self.__vars.fadeSpeeds[sound]
end

function philProfileController.new()
	local self = setmetatable({}, philProfileController)

	self.state = "idle"
	self.lastProfile = nil
	self.currentTheme = nil
	self.activeFadeOuts = {}

	return self
end

function philProfileController:handleStinger()
	local entity = self.entity
	local rootPart = entity and (entity.PrimaryPart or entity:FindFirstChild("HumanoidRootPart"))
	local lensFlareBone = rootPart and rootPart:FindFirstChild("LensFlareBone")

	local newPointLight = nil
	local newColorCorrection = Instance.new("ColorCorrectionEffect")
	bucketUtilities.applyPropertiesToInstance(newColorCorrection, self.__vars.properties.colorCorrection.start)
	newColorCorrection.Parent = currentCamera

	if lensFlareBone then
		lensFlareBone = lensFlareBone.Value

		newPointLight = Instance.new("PointLight")
		newPointLight:AddTag("LensFlare")
		newPointLight:SetAttribute("IgnoreDisabled", true)
		newPointLight:SetAttribute("LensFlareStrength", 1)
		newPointLight:SetAttribute("LensFlareSizeMultiplier", 0.4)
		newPointLight.Parent = lensFlareBone
	end

	local colorCorrectionFadeOutTween = tweenService:Create(
		newColorCorrection,
		TweenInfo.new(self.__vars.maxFadeTime),
		self.__vars.properties.colorCorrection.stop
	)

	colorCorrectionFadeOutTween:Play()

	local randomStingerSound = stingerSounds[math.random(1, #stingerSounds)]
	randomStingerSound:Play()

	colorCorrectionFadeOutTween.Completed:Once(function()
		newColorCorrection:Destroy()

		if newPointLight then
			newPointLight:Destroy()
		end
	end)
end

function philProfileController:setTheme(newTheme: Sound?)
	if self.currentTheme == newTheme then
		return
	end

	if self.currentTheme then
		if not self.currentTheme:GetAttribute("Volume") then
			self.currentTheme:SetAttribute("Volume", self.currentTheme.Volume)
		end

		self.activeFadeOuts[self.currentTheme] = true
	end

	self.currentTheme = newTheme

	if newTheme then
		self.activeFadeOuts[newTheme] = nil

		if not newTheme:GetAttribute("Volume") then
			newTheme:SetAttribute("Volume", newTheme.Volume)
		end

		if not newTheme.IsPlaying then
			newTheme.Volume = 0
			newTheme:Play()
		end
	end
end

function philProfileController:start(profile: { any }, entity: Model?)
	self.lastProfile = profile
	self.entity = entity
	self.state = "chasing"
	self:handleStinger()
	self:setTheme(chaseThemeSound)
end

function philProfileController:loadAfterProfile()
	self.afterChaseElapsed = 0
	self.state = "afterChase"
	self:setTheme(afterChaseThemeSound)

	chaseEndStingerSound:Play()
end

function philProfileController:cancelAfterProfile()
	if self.state ~= "afterChase" then
		return
	end

	self.state = "idle"

	if self.currentTheme == afterChaseThemeSound then
		self.currentTheme = nil
	end

	self.activeFadeOuts[afterChaseThemeSound] = true
end

function philProfileController:update(deltaTime: number)
	self.character = player.Character

	if self.state == "afterChase" then
		self.afterChaseElapsed = self.afterChaseElapsed + deltaTime

		if self.afterChaseElapsed >= self.__vars.afterChaseLength then
			self:cancelAfterProfile()
		end
	else
		if self.state == "chasing" then
			if self.character:GetAttribute("Combat") and self.currentTheme ~= combatThemeSound then
				self:setTheme(combatThemeSound)
			end
		end
	end

	if self.currentTheme then
		local fadeSpeed = self:getFadeSpeed(self.currentTheme)
		local alpha = math.clamp(deltaTime * fadeSpeed, 0, 1)

		self.currentTheme.Volume =
			mathUtilities.lerp(self.currentTheme.Volume, self.currentTheme:GetAttribute("Volume"), alpha)
	end

	for sound in self.activeFadeOuts do
		local fadeSpeed = self:getFadeSpeed(sound)
		local alpha = math.clamp(deltaTime * fadeSpeed, 0, 1)

		sound.Volume = mathUtilities.lerp(sound.Volume, 0, alpha)

		if sound.Volume <= 0.01 then
			sound.Volume = 0
			sound:Stop()

			self.activeFadeOuts[sound] = nil
		end
	end
end

function philProfileController:stop()
	self.state = "idle"
	self:cancelAfterProfile()

	self.activeFadeOuts[afterChaseThemeSound] = true

	if self.currentTheme then
		self.activeFadeOuts[self.currentTheme] = true
		self.currentTheme = nil
	end

	self.entity = nil
end

return philProfileController
