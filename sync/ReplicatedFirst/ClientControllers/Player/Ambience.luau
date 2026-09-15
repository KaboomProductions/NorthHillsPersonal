local ambienceController = {}
ambienceController.__index = ambienceController

local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
local collectionService = game:GetService("CollectionService")
local httpService = game:GetService("HttpService")
local players = game:GetService("Players")

local player = players.LocalPlayer
local currentCamera = workspace.CurrentCamera

local gameValues = replicatedStorage.Values
local roundCycleValues = gameValues.RoundCycle
local timeCycleValues = roundCycleValues.TimeCycle
local nightTime = timeCycleValues.NightTime
local climateState = roundCycleValues.ClimateState

local sharedUtilities = replicatedStorage.SharedUtilities
local sharedAssets = replicatedStorage.SharedAssets
local networking = require(replicatedStorage.Communication.Networking)

local effects = sharedAssets.Effects
local soundGroups = sharedAssets.SoundGroups
local sounds = effects.Sounds
local revealStingers = sounds.RevealStingers

local regionParts = sharedAssets.Regions:GetDescendants()
local bucketUtilities = require(sharedUtilities.BucketUtils)
local audioUtilities = require(sharedUtilities.AudioUtils)
local precipitationType = require(sharedAssets.PrecipitationType)

local audio = workspace.Audio
local ambience = audio.Ambience
local ambienceCache = {}

local locationsAmbience = ambience.Locations
local climateAmbience = ambience.Climate
local dayAmbience = ambience.Day:GetDescendants()
local nightAmbience = ambience.Night:GetDescendants()
local randomAmbience = ambience.Random:GetChildren()

local heavyStormAmbience = climateAmbience.HeavyStormLoop
local lightRainAmbience = climateAmbience.LightRainLoop
local indoorRainAmbience = climateAmbience.IndoorRainLoop
local windLoop = climateAmbience.WindLoop

local revealStingerCooldown = 60
local revealStingerDirectories = {
	Tower = revealStingers["2"],
}

local randomAmbienceConfig = {
	minimumDelaySeconds = 20,
	maximumDelaySeconds = 40,
}

local muffleWhenOutdoorsByTag = {
	IsOutdoorAmb = false,
	IsIndoorAmb = true,
}

local equalizerConfig = {
	inactive = {
		HighGain = 0,
		LowGain = 0,
		MidGain = 0,
	},

	active = {
		HighGain = -80,
		LowGain = 5,
		MidGain = -15,
	},
}

function ambienceController:isNightActive(): boolean
	if self.authoritativeNightValue ~= nil then
		return self.authoritativeNightValue
	end

	return nightTime.Value
end

function ambienceController:trackTaggedInstances(tag: string): { Instance }
	local list = collectionService:GetTagged(tag)

	self.connections[tag .. "Added"] = collectionService:GetInstanceAddedSignal(tag):Connect(function(object: Instance)
		table.insert(list, object)

		local muffleWhenOutdoors = muffleWhenOutdoorsByTag[tag]

		if self.isOutdoors ~= nil and muffleWhenOutdoors ~= nil then
			self:applyMuffle({ object }, self.isOutdoors, muffleWhenOutdoors)
		end
	end)

	self.connections[tag .. "Removed"] = collectionService
		:GetInstanceRemovedSignal(tag)
		:Connect(function(object: Instance)
			local idx = table.find(list, object)

			if idx then
				table.remove(list, idx)
			end
		end)

	return list
end

function ambienceController:preload()
	local genericRevealStingers = {}
	local locationSpecificStingers = {}

	for _, sound in pairs(revealStingerDirectories) do
		locationSpecificStingers[sound] = true
	end

	revealStingers = revealStingers:GetChildren()

	for _, stinger in ipairs(revealStingers) do
		if not locationSpecificStingers[stinger] then
			table.insert(genericRevealStingers, stinger)
		end
	end

	self.genericRevealStingers = genericRevealStingers

	self.outdoorAmbSounds = self:trackTaggedInstances("IsOutdoorAmb")
	self.indoorAmbSounds = self:trackTaggedInstances("IsIndoorAmb")
	self.mimicOutsideAmbParts = self:trackTaggedInstances("MimicOutsideAmb")
	self.starterOutdoorAmbSounds = collectionService:GetTagged("IsOutdoorAmb")

	self:updateMimicAmbience()
	self:scheduleRefresh()
end

function ambienceController:fetchRegions()
	local activeRegions = {
		ambience = nil,
		reveals = {},
	}

	for _, region in regionParts do
		if not region:IsA("BasePart") then
			continue
		end

		if not region.Parent then
			continue
		end

		if not bucketUtilities.checkInRegion(region, currentCamera.CFrame.Position) then
			continue
		end

		local regionData = {
			root = region,
			id = region.Parent.Name,
			ambienceType = region:GetAttribute("AmbienceType") or "Ambience",
		}

		if regionData.ambienceType == "Ambience" then
			activeRegions.ambience = regionData
		elseif regionData.ambienceType == "Reveal" then
			table.insert(activeRegions.reveals, regionData)
		end
	end

	return activeRegions
end

function ambienceController:cancelSoundTween(sound: Sound)
	local soundTweens = self.soundTweens
	local activeTween = soundTweens[sound]

	if activeTween ~= nil then
		activeTween:Cancel()
		soundTweens[sound] = nil
	end
end

function ambienceController:tweenVolume(sound: Sound, isEnabled: boolean, tweenDuration: number?, shouldPlay: boolean?)
	tweenDuration = tweenDuration or 1

	if shouldPlay == nil then
		shouldPlay = true
	end

	if sound:GetAttribute("Volume") == nil then
		sound:SetAttribute("Volume", sound.Volume)
	end

	if shouldPlay and isEnabled and not sound.IsPlaying then
		sound:Play()
	end

	self:cancelSoundTween(sound)

	local soundTween = tweenService:Create(sound, TweenInfo.new(tweenDuration), {
		Volume = isEnabled and (sound:GetAttribute("Volume") or 0.5) or 0,
	})

	self.soundTweens[sound] = soundTween

	soundTween.Completed:Once(function()
		if self.soundTweens[sound] == soundTween then
			self.soundTweens[sound] = nil
		end
	end)

	soundTween:Play()
end

function ambienceController:setSoundGroup(soundGroup: { Instance }, isEnabled: boolean, shouldPlaySound: boolean?)
	for _, sound in pairs(soundGroup) do
		if sound:IsA("Sound") then
			self:tweenVolume(sound, isEnabled, nil, shouldPlaySound)
		end
	end
end

function ambienceController:cancelMuffleTween(sound: Sound)
	local muffleTweens = self.muffleTweens
	local activeTween = muffleTweens[sound]

	if activeTween ~= nil then
		activeTween:Cancel()
		muffleTweens[sound] = nil
	end
end

function ambienceController:applyMuffle(soundList: { Instance }, isOutdoors: boolean, muffleWhenOutdoors: boolean)
	local enabledState = isOutdoors == muffleWhenOutdoors

	for _, sound in soundList do
		if not sound:IsA("Sound") then
			continue
		end

		local equalizerEffect = sound:FindFirstChild("Muffle")

		if not equalizerEffect then
			equalizerEffect = Instance.new("EqualizerSoundEffect")
			equalizerEffect.Name = "Muffle"

			for propertyName, value in equalizerConfig.inactive do
				equalizerEffect[propertyName] = value
			end

			equalizerEffect.Parent = sound
		end

		self:cancelMuffleTween(sound)

		local muffleTween = tweenService:Create(
			equalizerEffect,
			TweenInfo.new(0.2),
			enabledState and equalizerConfig.active or equalizerConfig.inactive
		)

		self.muffleTweens[sound] = muffleTween

		muffleTween.Completed:Once(function()
			if self.muffleTweens[sound] == muffleTween then
				self.muffleTweens[sound] = nil
			end
		end)

		muffleTween:Play()
	end
end

function ambienceController:init()
	self:preload()

	task.spawn(function()
		while getmetatable(self) do
			self:update()
			task.wait(0.1)
		end
	end)

	self.connections.climateChanged = climateState:GetAttributeChangedSignal("PrecipitationType"):Connect(function()
		self:scheduleRefresh()
	end)

	self.connections.nightChanged = nightTime:GetPropertyChangedSignal("Value"):Connect(function()
		self.authoritativeNightValue = nightTime.Value
		self:scheduleRefresh()
	end)

	self.connections.cycleStateUpdate = networking.events.cycleStateUpdate.OnClientEvent:Connect(function(stateSnapshot)
		if type(stateSnapshot) ~= "table" or type(stateSnapshot.isNight) ~= "boolean" then
			return
		end

		self.authoritativeNightValue = stateSnapshot.isNight
		self:scheduleRefresh()
	end)
end

function ambienceController.new()
	local self = setmetatable({}, ambienceController)

	self.connections = {}
	self.currentRegion = {}
	self.soundTweens = {}
	self.revealCooldowns = {}
	self.activeRevealRegions = {}
	self.muffleTweens = {}
	self.mimicVolumeState = {}
	self.mimicSounds = {}
	self.currentAmbienceRegionId = nil
	self.lastUpdate = 0
	self.lastRandomSoundTime = 0
	self.nextRandomDelaySeconds = 0

	task.defer(self.init, self)

	return self
end

function ambienceController:destroy()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	for sound, muffleTween in self.muffleTweens do
		muffleTween:Cancel()
		self.muffleTweens[sound] = nil
	end

	for sound, soundTween in self.soundTweens do
		soundTween:Cancel()
		self.soundTweens[sound] = nil
	end

	if self.musicMuffleThread then
		task.cancel(self.musicMuffleThread)
		self.musicMuffleThread = nil

		audioUtilities.applyEqualizerToSoundGroups({
			tweenInfo = TweenInfo.new(0),
			equalizerId = "locationReveal",
			groups = {
				soundGroups.Music,
				soundGroups.MusicDay,
			},
			properties = equalizerConfig.inactive,
		})
	end

	for part, soundsById in self.mimicSounds do
		for soundId, mimicSound in soundsById do
			mimicSound:Destroy()
			soundsById[soundId] = nil
		end

		self.mimicSounds[part] = nil
	end

	table.clear(self.activeRevealRegions)
	table.clear(self.mimicVolumeState)
	table.clear(self.revealCooldowns)
	setmetatable(self, nil)
end

function ambienceController:onCycleChanged()
	local isNight = self:isNightActive()
	self:setSoundGroup(dayAmbience, not isNight)
	self:setSoundGroup(nightAmbience, isNight)
	self:setSoundGroup(randomAmbience, isNight and self.isOutdoors, false)
end

function ambienceController:onClimateChanged()
	local newPrecipitationType = climateState:GetAttribute("PrecipitationType")
	local isWindy = climateState:HasTag("Windy")

	self:tweenVolume(
		indoorRainAmbience,
		newPrecipitationType >= precipitationType.Rain and (self.isOutdoors ~= nil and not self.isOutdoors)
	)

	self:tweenVolume(lightRainAmbience, newPrecipitationType == precipitationType.Rain)
	self:tweenVolume(heavyStormAmbience, newPrecipitationType == precipitationType.Storm)
	self:tweenVolume(windLoop, isWindy)
end

function ambienceController:scheduleRefresh()
	self:onClimateChanged()
	self:onCycleChanged()
end

function ambienceController:getNextRandomDelaySeconds(): number
	return math.random(randomAmbienceConfig.minimumDelaySeconds, randomAmbienceConfig.maximumDelaySeconds)
end

function ambienceController:updateRandomAmbience()
	if self:isNightActive() then
		if self.nextRandomDelaySeconds <= 0 then
			self.nextRandomDelaySeconds = self:getNextRandomDelaySeconds()
		end

		if os.clock() - self.lastRandomSoundTime >= self.nextRandomDelaySeconds then
			local randomSound = randomAmbience[math.random(1, #randomAmbience)]
			randomSound:Play()
			self.lastRandomSoundTime = os.clock()
			self.nextRandomDelaySeconds = randomSound.TimeLength + self:getNextRandomDelaySeconds()
		end
	else
		self.lastRandomSoundTime = os.clock()
		self.nextRandomDelaySeconds = 0
	end
end

function ambienceController:updateMimicAmbience()
	for _, part in ipairs(self.mimicOutsideAmbParts) do
		self.mimicSounds[part] = self.mimicSounds[part] or {}

		for _, outdoorSound in self.starterOutdoorAmbSounds do
			if not outdoorSound:IsA("Sound") then
				continue
			end

			if not outdoorSound:GetAttribute("AmbienceId") then
				outdoorSound:SetAttribute("AmbienceId", httpService:GenerateGUID())
			end

			local soundId = outdoorSound:GetAttribute("AmbienceId")
			local clone = self.mimicSounds[part][soundId]

			if not clone then
				clone = outdoorSound:Clone()
				clone:RemoveTag("IsOutdoorAmb")
				clone:RemoveTag("IsIndoorAmb")
				clone.Parent = part
				clone.Volume = 0
				clone:Play()

				self.mimicSounds[part][soundId] = clone
			end

			local disabled = self.isOutdoors or part:HasTag("Disabled") or not outdoorSound.IsPlaying
			local targetVolume = disabled and 0 or outdoorSound.Volume

			self.mimicVolumeState[clone] = self.mimicVolumeState[clone] or 0
			self.mimicVolumeState[clone] = self.mimicVolumeState[clone]
				+ (targetVolume - self.mimicVolumeState[clone]) * 0.12

			clone.Volume = self.mimicVolumeState[clone]

			if outdoorSound.IsPlaying and not clone.IsPlaying then
				clone:Play()
			elseif not outdoorSound.IsPlaying and clone.IsPlaying then
				clone:Stop()
			end
		end
	end
end

function ambienceController:onAmbienceRegionChanged(newRegionId)
	local isOutdoors = newRegionId == nil
	self.isOutdoors = isOutdoors

	if self.currentAmbienceRegionId and ambienceCache[self.currentAmbienceRegionId] then
		self:tweenVolume(ambienceCache[self.currentAmbienceRegionId], false, 0.5)
	end

	if newRegionId then
		if not ambienceCache[newRegionId] then
			local folder = locationsAmbience:FindFirstChild(newRegionId) or locationsAmbience.Default

			if folder then
				ambienceCache[newRegionId] = folder
			end
		end

		if ambienceCache[newRegionId] then
			self:tweenVolume(ambienceCache[newRegionId], self:isNightActive(), 4)
		end
	end

	self:applyMuffle(self.outdoorAmbSounds, isOutdoors, muffleWhenOutdoorsByTag.IsOutdoorAmb)
	self:applyMuffle(self.indoorAmbSounds, isOutdoors, muffleWhenOutdoorsByTag.IsIndoorAmb)

	self.currentAmbienceRegionId = newRegionId

	self:onClimateChanged()
	self:onCycleChanged()
end

function ambienceController:onRevealEntered(regionId)
	local stinger = revealStingerDirectories[regionId]

	if not stinger and self.genericRevealStingers and #self.genericRevealStingers > 0 then
		stinger = self.genericRevealStingers[math.random(1, #self.genericRevealStingers)]
	end

	if not stinger then
		return
	end

	local currentTime = os.clock()
	local lastPlayed = self.revealCooldowns[regionId] or -revealStingerCooldown

	if currentTime - lastPlayed < revealStingerCooldown then
		return
	end

	self.revealCooldowns[regionId] = currentTime

	stinger:Play()

	if self.musicMuffleThread then
		task.cancel(self.musicMuffleThread)
		self.musicMuffleThread = nil
	end

	audioUtilities.applyEqualizerToSoundGroups({
		tweenInfo = TweenInfo.new(2.5),
		equalizerId = "locationReveal",

		groups = {
			soundGroups.Music,
			soundGroups.MusicDay,
		},

		properties = {
			HighGain = -55,
			MidGain = -30,
			LowGain = -8,
		},
	})

	self.musicMuffleThread = task.delay(stinger.TimeLength / 1.3, function()
		audioUtilities.applyEqualizerToSoundGroups({
			tweenInfo = TweenInfo.new(5),
			equalizerId = "locationReveal",

			groups = {
				soundGroups.Music,
				soundGroups.MusicDay,
			},

			properties = {
				HighGain = 0,
				MidGain = 0,
				LowGain = 0,
			},
		})
	end)
end

function ambienceController:update()
	local now = os.clock()

	if now - self.lastUpdate < 0.1 then
		return
	end

	self.lastUpdate = now

	local regions = self:fetchRegions()
	local currentlyInsideRevealRegions = {}
	local ambienceRegion = regions.ambience
	local ambienceRegionId = ambienceRegion and ambienceRegion.id

	local isNight = self:isNightActive()
	if ambienceRegionId ~= self.currentAmbienceRegionId or self.previousNightValue ~= isNight then
		self.previousNightValue = isNight
		self:onAmbienceRegionChanged(ambienceRegionId)
	end

	if not player:GetAttribute("InMenu") then
		for _, revealRegion in regions.reveals do
			currentlyInsideRevealRegions[revealRegion.root] = true

			if self.activeRevealRegions[revealRegion.root] then
				self.revealCooldowns[revealRegion.id] = now
			else
				self:onRevealEntered(revealRegion.id)
			end
		end

		self.activeRevealRegions = currentlyInsideRevealRegions
	end

	self:updateMimicAmbience()
	self:updateRandomAmbience()
end

return ambienceController
