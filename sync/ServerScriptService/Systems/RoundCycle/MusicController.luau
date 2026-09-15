local contentProvider = game:GetService("ContentProvider")
local tweenService = game:GetService("TweenService")

local cycleConfig = require(script.Parent.CycleConfig)

local gameAudio = workspace.Audio
local gameMusicFolder = gameAudio.Music
local daytimeMusicFolder = gameMusicFolder.Daytime
local rareDaytimeTracks = daytimeMusicFolder.Rare:GetChildren()

local musicFadeInInfo = TweenInfo.new(cycleConfig.musicFadeInSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local musicFadeOutInfo = TweenInfo.new(cycleConfig.musicFadeOutSeconds)

local activeMusicTween: Tween? = nil
local currentMusicTrack: Sound? = nil

local musicController = {}

function musicController.preload()
	contentProvider:PreloadAsync(daytimeMusicFolder:GetChildren())
end

function musicController.fadeMusicTrack(musicTrack: Sound, shouldFadeIn: boolean)
	if activeMusicTween ~= nil then
		activeMusicTween:Cancel()
	end

	if musicTrack:GetAttribute("Volume") == nil then
		musicTrack:SetAttribute("Volume", musicTrack.Volume)
	end

	local savedVolume = musicTrack:GetAttribute("Volume")
	musicTrack.Volume = shouldFadeIn and 0 or savedVolume

	local tweenProperties = {
		Volume = shouldFadeIn and savedVolume or 0,
	}

	local tween = tweenService:Create(musicTrack, shouldFadeIn and musicFadeInInfo or musicFadeOutInfo, tweenProperties)
	activeMusicTween = tween
	tween:Play()
end

function musicController.playDaytimeTrack(climateStateName: string)
	local climateMusicTrack = daytimeMusicFolder:FindFirstChild(climateStateName)
	local fallbackMusicTrack = daytimeMusicFolder:FindFirstChild("Clear")
	currentMusicTrack = climateMusicTrack or fallbackMusicTrack

	if currentMusicTrack == nil then
		warn("[RoundCycle] No daytime music found for", climateStateName)
		return
	end

	if math.random(1, cycleConfig.rareMusicRollSize) == 1 and #rareDaytimeTracks > 0 then
		currentMusicTrack = rareDaytimeTracks[math.random(1, #rareDaytimeTracks)] or currentMusicTrack
	end

	if currentMusicTrack:IsA("Folder") then
		local availableThemes = currentMusicTrack:GetChildren()
		currentMusicTrack = availableThemes[math.random(1, #availableThemes)]
	end

	if currentMusicTrack ~= nil then
		musicController.fadeMusicTrack(currentMusicTrack, true)
		currentMusicTrack:Play()
	end
end

function musicController.fadeOutCurrent()
	if currentMusicTrack ~= nil then
		musicController.fadeMusicTrack(currentMusicTrack, false)
	end
end

function musicController.getCurrentTrackLength(): number
	return currentMusicTrack and (currentMusicTrack:GetAttribute("EndTimePosition") or currentMusicTrack.TimeLength)
		or 0

	--// idk why this is saying that there's an error lol
end

return musicController
