type SoundSource = Instance | { Instance }

type FetchRandomSoundContext = {
	dictionary: SoundSource?,
	lastSound: Sound?,
}

type SoundHistoryKey = Sound | string

type SoundUsageHistory = {
	usageCounts: { [SoundHistoryKey]: number },
	lastSoundKey: SoundHistoryKey?,
}

type FetchLeastUsedSoundContext = {
	dictionary: SoundSource?,
	history: SoundUsageHistory,
}

type CreatePlayerContext = {
	sound: Sound,
	parent: Instance?,
	volume: number?,
	playbackSpeed: number?,
}

type CreateWireContext = {
	emitter: AudioEmitter,
	player: AudioPlayer,
}

type PlaySoundContext = {
	sound: Sound?,
	parent: Instance?,
	volume: number?,
	playbackSpeed: number?,
	useAcousticSimulation: boolean?,
	canClean: boolean?,
}

type PlayableAudio = AudioPlayer | Sound
type SoundGroupList = { SoundGroup }

local audioFunctions = {}
audioFunctions.soundGroupTweens = {}

local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")

local sharedAssets = replicatedStorage.SharedAssets
local soundGroups = sharedAssets.SoundGroups:GetChildren() :: SoundGroupList

local rng = Random.new()

local function resolveSoundDictionary(dictionarySource: SoundSource?): { Sound }
	if dictionarySource == nil then
		return {}
	end

	local resolvedDictionary: { Sound } = {}

	if typeof(dictionarySource) == "Instance" then
		for _, child in ipairs(dictionarySource:GetChildren()) do
			if child:IsA("Sound") then
				table.insert(resolvedDictionary, child)
			end
		end
	else
		for _, child in ipairs(dictionarySource) do
			if child:IsA("Sound") then
				table.insert(resolvedDictionary, child)
			end
		end
	end

	return resolvedDictionary
end

local function getOrCreateEmitter(parent: Instance): AudioEmitter
	local existingEmitter = parent:FindFirstChildOfClass("AudioEmitter")
	if existingEmitter and existingEmitter:IsA("AudioEmitter") then
		return existingEmitter
	end

	local emitter = Instance.new("AudioEmitter")
	emitter.Parent = parent

	return emitter
end

local function playAndCleanupPlayer(player: AudioPlayer, wire: Wire)
	player.Destroying:Once(function()
		wire:Destroy()
	end)

	player.Ended:Once(function()
		player:Destroy()
	end)

	player:Play()
end

local function playAndCleanupSound(sound: Sound, canClean: boolean?)
	sound:Play()

	if not canClean then
		return
	end

	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function stopSound(sound: Sound)
	sound:Stop()
end

local function stopAudioPlayer(player: AudioPlayer)
	player:Stop()
end

function audioFunctions.fetchRandomSound(info: FetchRandomSoundContext): Sound?
	local dictionary = resolveSoundDictionary(info.dictionary)
	if #dictionary <= 0 then
		return nil
	end

	if #dictionary == 1 then
		local onlySound = dictionary[1]
		if onlySound == info.lastSound then
			return nil
		end
		return onlySound
	end

	local chosenSound: Sound? = nil
	local lastSound = info.lastSound
	local randomGenerator: Random = rng

	if lastSound ~= nil then
		repeat
			chosenSound = dictionary[randomGenerator:NextInteger(1, #dictionary)]
		until chosenSound ~= nil and chosenSound ~= lastSound
	else
		chosenSound = dictionary[randomGenerator:NextInteger(1, #dictionary)]
	end

	return chosenSound
end

function audioFunctions.createSoundUsageHistory(): SoundUsageHistory
	return {
		usageCounts = {},
		lastSoundKey = nil,
	}
end

function audioFunctions.fetchLeastUsedSound(info: FetchLeastUsedSoundContext): Sound?
	local dictionary = resolveSoundDictionary(info.dictionary)
	if #dictionary <= 0 then
		return nil
	end

	local soundsByKey: { [SoundHistoryKey]: Sound } = {}
	local soundKeys: { SoundHistoryKey } = {}

	for _, sound in dictionary do
		--// Count duplicate asset instances as the same audible footstep.
		local soundKey: SoundHistoryKey = if sound.SoundId ~= "" then sound.SoundId else sound
		if soundsByKey[soundKey] == nil then
			soundsByKey[soundKey] = sound
			table.insert(soundKeys, soundKey)
		end
	end

	local minimumUsage = math.huge
	local leastUsedKeys: { SoundHistoryKey } = {}
	local canAvoidLastSound = #soundKeys > 1

	for _, soundKey in soundKeys do
		if canAvoidLastSound and soundKey == info.history.lastSoundKey then
			continue
		end

		local usageCount = info.history.usageCounts[soundKey] or 0
		if usageCount < minimumUsage then
			minimumUsage = usageCount
			table.clear(leastUsedKeys)
			table.insert(leastUsedKeys, soundKey)
		elseif usageCount == minimumUsage then
			table.insert(leastUsedKeys, soundKey)
		end
	end

	local selectedKey = leastUsedKeys[rng:NextInteger(1, #leastUsedKeys)]
	info.history.usageCounts[selectedKey] = (info.history.usageCounts[selectedKey] or 0) + 1
	info.history.lastSoundKey = selectedKey

	return soundsByKey[selectedKey]
end

function audioFunctions.createPlayer(info: CreatePlayerContext): AudioPlayer
	local player = Instance.new("AudioPlayer")
	player.Volume = info.volume or info.sound.Volume or 0.5
	player.PlaybackSpeed = info.playbackSpeed or 1
	player.Asset = info.sound.SoundId
	player.Name = info.sound.Name
	player.Parent = info.parent

	return player
end

function audioFunctions.createWire(info: CreateWireContext): Wire
	local wire = Instance.new("Wire")
	wire.Parent = info.emitter
	wire.SourceInstance = info.player
	wire.TargetInstance = info.emitter

	return wire
end

function audioFunctions.applyEqualizerToSoundGroups(info: {
	groups: SoundGroupList?,
	equalizerId: string,
	properties: {},
	tweenInfo: TweenInfo,
})
	local groups = info.groups or soundGroups

	for _, soundGroup in groups do
		audioFunctions.soundGroupTweens[soundGroup] = audioFunctions.soundGroupTweens[soundGroup] or {}

		local equalizerEffect = soundGroup:FindFirstChild(info.equalizerId)

		local activeTweens = audioFunctions.soundGroupTweens[soundGroup]
		local activeTween = activeTweens[info.equalizerId]

		if not equalizerEffect then
			equalizerEffect = Instance.new("EqualizerSoundEffect")
			equalizerEffect.Name = info.equalizerId
			equalizerEffect.Parent = soundGroup

			equalizerEffect.HighGain = 0
			equalizerEffect.MidGain = 0
			equalizerEffect.LowGain = 0
		end

		if activeTween then
			activeTween:Cancel()
			activeTweens[info.equalizerId] = nil
		end

		local tween = tweenService:Create(equalizerEffect, info.tweenInfo, info.properties)
		activeTweens[info.equalizerId] = tween

		tween:Play()
	end
end

function audioFunctions.playSound(info: PlaySoundContext): PlayableAudio?
	if not info.sound or not info.parent then
		return nil
	end

	local sound = info.sound
	local parent = info.parent
	local volume = info.volume or sound.Volume
	local playbackSpeed = info.playbackSpeed
	local useAcousticSimulation = info.useAcousticSimulation ~= false

	if info.canClean == nil then
		info.canClean = true
	end

	if useAcousticSimulation then
		local emitter = getOrCreateEmitter(parent)
		local player = audioFunctions.createPlayer({
			sound = sound,
			parent = parent,
			volume = volume,
			playbackSpeed = playbackSpeed,
		})

		local wire = audioFunctions.createWire({
			emitter = emitter,
			player = player,
		})

		playAndCleanupPlayer(player, wire)
		return player
	end

	local newSound = sound:Clone() :: Sound
	newSound.PlaybackSpeed = playbackSpeed or newSound.PlaybackSpeed
	newSound.Volume = volume
	newSound.Parent = parent

	playAndCleanupSound(newSound, info.canClean)
	return newSound
end

function audioFunctions.stopSound(playableAudio: PlayableAudio)
	if playableAudio == nil then
		return
	end

	pcall(function()
		if playableAudio:IsA("Sound") then
			stopSound(playableAudio)
		elseif playableAudio:IsA("AudioPlayer") then
			stopAudioPlayer(playableAudio)
		end
	end)

	if playableAudio.Parent ~= nil then
		playableAudio:Destroy()
	end
end

return audioFunctions
