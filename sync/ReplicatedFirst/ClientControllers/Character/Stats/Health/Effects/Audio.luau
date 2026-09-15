local replicatedStorage = game:GetService("ReplicatedStorage")

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local healthAudioController = {}
healthAudioController.__index = healthAudioController

local heartBeatSound = workspace.Audio.Effects.Health.Heartbeat

function healthAudioController.new(config)
	local self = setmetatable({}, healthAudioController)
	self.config = config.audioConfig

	self.heartBeatSound = heartBeatSound
	self.heartBeatPlaying = false

	self:reset()
	return self
end

function healthAudioController:reset()
	local sound = self.heartBeatSound
	sound.Volume = 0
	sound.PlaybackSpeed = 1

	if self.heartBeatPlaying then
		sound:Stop()
		self.heartBeatPlaying = false
	end
end

function healthAudioController:update(deltaTime, health, maxHealth)
	local audioConfig = self.config

	local sound = self.heartBeatSound
	local thresholdHealth = maxHealth * audioConfig.healthMultiplier
	local isBelow = health <= thresholdHealth

	if isBelow then
		local thresholdAverage = math.clamp(1 - health / thresholdHealth, 0, 1)

		if not self.heartBeatPlaying then
			sound:Play()
			self.heartBeatPlaying = true
		end

		local heartBeatLerpAlpha = mathUtilities.exponentialAlpha(audioConfig.heartBeatLerpSpeed, deltaTime)
		local targetVolume = thresholdAverage * audioConfig.maxVolumeScale
		local targetSpeed = audioConfig.basePitch + thresholdAverage * 0.5

		sound.Volume = mathUtilities.lerp(sound.Volume, targetVolume, heartBeatLerpAlpha)
		sound.PlaybackSpeed = mathUtilities.lerp(sound.PlaybackSpeed, targetSpeed, heartBeatLerpAlpha)
	else
		local fadeLerpAlpha = mathUtilities.exponentialAlpha(audioConfig.fadeLerpSpeed, deltaTime)
		local currentVolume = sound.Volume

		sound.Volume = mathUtilities.lerp(currentVolume, 0, fadeLerpAlpha)
		sound.PlaybackSpeed = mathUtilities.lerp(sound.PlaybackSpeed, 1, fadeLerpAlpha)

		if currentVolume < audioConfig.volumeThreshold and self.heartBeatPlaying then
			sound:Stop()
			self.heartBeatPlaying = false
		end
	end

	local pulseLoudness = sound.PlaybackLoudness * sound.Volume * audioConfig.pulseMultiplier
	return math.clamp(pulseLoudness, 0, 1)
end

function healthAudioController:destroy()
	self:reset()
end

return healthAudioController
