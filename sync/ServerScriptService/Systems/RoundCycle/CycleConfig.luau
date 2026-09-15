local replicatedStorage = game:GetService("ReplicatedStorage")

local cycleSettings = replicatedStorage.Settings.RoundCycle

local cycleConfig = {
	nightLengthSeconds = cycleSettings.NightLength.Value,
	transitionLengthSeconds = cycleSettings.TransitionLength.Value,

	resultDelayTime = 15,

	musicFadeInSeconds = 5,
	musicFadeOutSeconds = 20,
	transitionOverlapMultiplier = 1.5,
	rareMusicRollSize = 50,
}

return table.freeze(cycleConfig)
