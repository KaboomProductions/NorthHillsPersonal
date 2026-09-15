local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)
local serverStorage = game:GetService("ServerStorage")

local soundEvents = require(serverStorage.ServerUtilities.SoundEvents)
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local networking = require(replicatedStorage.Communication.Networking)

local footstepSoundsFolder = replicatedStorage.SharedAssets.Effects.Sounds.Footsteps.Player
local footstepMaterialMap = require(serverStorage.ServerAssets.Dictionaries.Footsteps)

local footstepController = {}
local footstepHistoryCache = setmetatable({}, { __mode = "k" })

local baseRadius = 35
local baseLoudness = 0.4

local movementModifiers = {
	crouching = { radius = 0.25, loudness = 0.3 },
	walking = { radius = 1.0, loudness = 1.0 },
	sprinting = { radius = 1.6, loudness = 1.5 },
}

local loudnessModifiers: { [string]: number } = {
	Grass = 0.75,
	Carpet = 0.55,
	Wood = 1.0,
	Tile = 1.2,
	Metal = 1.4,
	Concrete = 1.15,
	Water = 1.3,
}

type footstepPayload = {
	isCrouching: boolean,
	isSprinting: boolean,
}

local function getMovementModifier(isCrouching: boolean, isSprinting: boolean)
	if isCrouching then
		return movementModifiers.crouching
	elseif isSprinting then
		return movementModifiers.sprinting
	else
		return movementModifiers.walking
	end
end

function footstepController._computeNoiseProfile(
	receivedPayload: footstepPayload,
	humanoid: Humanoid,
	materialName: string
)
	local movementMod = getMovementModifier(receivedPayload.isCrouching, receivedPayload.isSprinting)
	local materialMod = loudnessModifiers[materialName] or 1

	local baselineWalkSpeed = humanoid:GetAttribute("BaseWalkSpeed") or 16
	local speedRatio = baselineWalkSpeed > 0 and (humanoid.WalkSpeed / baselineWalkSpeed) or 1
	speedRatio = math.clamp(speedRatio, 0.5, 2)

	local loudness = baseLoudness * movementMod.loudness * materialMod * speedRatio
	local radius = baseRadius * movementMod.radius * speedRatio

	loudness = math.clamp(loudness, 0, 1.5)
	radius = math.clamp(radius, 0, 60)

	return radius, loudness
end

function footstepController.playFootstepSound(player: Player, character: Model?, receivedPayload: footstepPayload)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local rootPart = humanoid.RootPart or (character and character:FindFirstChild("HumanoidRootPart"))
	if not rootPart then
		return
	end

	local materialName = footstepMaterialMap[humanoid.FloorMaterial] or "Grass"
	local materialFolder = footstepSoundsFolder:FindFirstChild(materialName)
	if not materialFolder then
		return
	end

	local walkFolder = materialFolder:FindFirstChild("Walk")
	if not walkFolder then
		return
	end

	local soundHistory = footstepHistoryCache[character]
	if soundHistory == nil then
		soundHistory = audioUtilities.createSoundUsageHistory()
		footstepHistoryCache[character] = soundHistory
	end

	local newSound: Sound? = audioUtilities.fetchLeastUsedSound({
		dictionary = walkFolder:GetChildren(),
		history = soundHistory,
	})
	if not newSound then
		return
	end

	local radius, loudness = footstepController._computeNoiseProfile(receivedPayload, humanoid, materialName)

	soundEvents.createEvent({
		position = rootPart.Position,
		radius = radius,
		loudness = loudness,
		player = player,
		priority = 2,
		tag = "footstep",
	})

	audioUtilities.playSound({
		sound = newSound,
		volume = receivedPayload.isCrouching and newSound.Volume / 2 or newSound.Volume,
		parent = rootPart,
	})
end

function footstepController.init()
	networking.events.reportFootstep.OnServerEvent:Connect(function(player: Player, rawPayload: any)
		if typeof(rawPayload) ~= "table" or typeof(rawPayload.crouching) ~= "boolean"
			or typeof(rawPayload.sprinting) ~= "boolean" or not remoteGuard.allow(player, "footstep", 8, 1) then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 or humanoid.RootPart == nil
			or (humanoid.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude < 0.5 then
			return
		end
		footstepController.playFootstepSound(player, player.Character, {
			isCrouching = rawPayload.crouching == true,
			isSprinting = rawPayload.sprinting == true,
		})
	end)
end

return footstepController
