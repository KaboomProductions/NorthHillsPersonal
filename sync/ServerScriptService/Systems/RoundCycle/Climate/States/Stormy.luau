local replicatedStorage = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")
local players = game:GetService("Players")

local networking = require(replicatedStorage.Communication.Networking)
local precipitationType = require(replicatedStorage.SharedAssets.PrecipitationType)

local sharedAssets = replicatedStorage.SharedAssets
local effectsFolder = sharedAssets.Effects
local soundsFolder = effectsFolder.Sounds
local climateSoundsFolder = soundsFolder.Climate
local thunderSounds = climateSoundsFolder.Thunder:GetChildren()

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local timeValues = cycleValues.TimeCycle
local climateStateValue = cycleValues.ClimateState
local transitionStateValue = timeValues.TransitionState

local thunderSpawnDistanceStuds = 1000
local minimumThunderIntervalSeconds = 10
local maximumThunderIntervalSeconds = 40
local maximumThunderDelaySeconds = 5
local emitterCleanupDelaySeconds = 30

local timeSinceLastThunder = 0
local currentThunderIntervalSeconds = minimumThunderIntervalSeconds
local activeEmitters = {}

local stormyState = {}
stormyState.__config = {
	cloudProperties = {
		Cover = 1,
		Density = 0.2,
		Color = Color3.fromRGB(202, 199, 235),
	},

	globalWindProperties = {
		minStrength = 25,
		maxStrength = 30,
	},
}

local function sendThunderToReadyPlayers(distanceSeconds: number)
	for _, player in ipairs(players:GetPlayers()) do
		if player:GetAttribute("RoundCycleEventsReady") then
			networking.events.thunder:FireClient(player, distanceSeconds)
		end
	end
end

function stormyState.getPositionForThunder(distanceStuds: number): Vector3
	local angle = math.random() * math.pi * 2
	local offsetX = math.sin(angle) * distanceStuds
	local offsetZ = math.cos(angle) * distanceStuds
	return Vector3.new(offsetX, 0, offsetZ)
end

function stormyState.getFakeDelaySeconds(): number
	return math.random() * maximumThunderDelaySeconds
end

function stormyState.createThunder()
	if transitionStateValue.Value then
		return
	end

	if os.clock() - timeSinceLastThunder < currentThunderIntervalSeconds then
		return
	end

	timeSinceLastThunder = os.clock()
	currentThunderIntervalSeconds = math.random(minimumThunderIntervalSeconds, maximumThunderIntervalSeconds)
	climateStateValue:AddTag("ActiveThundering")

	local origin = vector.zero + Vector3.yAxis * thunderSpawnDistanceStuds
	local offset = stormyState.getPositionForThunder(thunderSpawnDistanceStuds)
	local finalPosition = origin + offset

	local emitterModel = Instance.new("Model")
	emitterModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	emitterModel.Name = "ThunderCache"
	emitterModel.Parent = workspace.Ignore

	local emitterPart = Instance.new("Part")
	emitterPart.Parent = emitterModel
	emitterPart.Anchored = true
	emitterPart.Position = finalPosition

	table.insert(activeEmitters, emitterPart)
	debris:AddItem(emitterPart, emitterCleanupDelaySeconds)

	local delaySeconds = stormyState.getFakeDelaySeconds()
	sendThunderToReadyPlayers(delaySeconds)

	task.delay(delaySeconds, function()
		local thunderSound = thunderSounds[math.random(1, #thunderSounds)]:Clone()
		thunderSound.Parent = emitterPart
		thunderSound:Play()

		thunderSound.Ended:Once(function()
			emitterModel:Destroy()
			climateStateValue:RemoveTag("ActiveThundering")
		end)
	end)
end

function stormyState.enter()
	timeSinceLastThunder = 0
	currentThunderIntervalSeconds = minimumThunderIntervalSeconds

	climateStateValue:AddTag("Windy")
	climateStateValue:SetAttribute("PrecipitationType", precipitationType.Storm)
end

function stormyState.exit()
	for _, emitter in ipairs(activeEmitters) do
		emitter:Destroy()
	end
	table.clear(activeEmitters)
	climateStateValue:RemoveTag("ActiveThundering")
end

function stormyState.update()
	stormyState.createThunder()
end

return stormyState
