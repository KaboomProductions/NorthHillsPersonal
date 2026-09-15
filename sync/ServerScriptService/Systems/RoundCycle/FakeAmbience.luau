local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local gameValues = replicatedStorage.Values
local roundCycleValues = gameValues.RoundCycle
local timeCycleValues = roundCycleValues.TimeCycle
local isNightTime = timeCycleValues.NightTime

local mathUtilities = require(sharedUtilities.MathUtils)

local effects = sharedAssets.Effects
local sounds = effects.Sounds
local fakeAmbienceSounds = sounds.FakeAmbience:GetChildren()

local components = workspace.Components
local entities = components.Entities

local ignoreFolder = workspace.Ignore
local otherFolder = ignoreFolder.Other

local ambienceController = {}
ambienceController.__index = ambienceController
ambienceController.availableEntities = {}
ambienceController.__vars = {
	minInterval = 60,
	maxInterval = 80,

	clusterRadius = 20,

	enemyDetectionRadius = 70,
	enemyRedirectChance = 0.55,

	cycleTickInterval = 2,
}

local lastClusterCueTime = {}
local lastClusterDelay = {}

local function buildPlayerClusters()
	local clusters = {}
	local characters = {}
	local used = {}

	for _, sendingPlayer in players:GetPlayers() do
		local character = sendingPlayer.Character
		local rootPart = character and character.PrimaryPart

		if rootPart then
			table.insert(characters, {
				player = sendingPlayer,
				origin = rootPart.Position,
			})
		end
	end

	for i, entry in characters do
		if not used[i] then
			local cluster = {
				center = entry.origin,
				key = tostring(entry.player.UserId),
				members = {
					entry.player,
				},
			}

			used[i] = true

			for j = i + 1, #characters do
				if not used[j] then
					local other = characters[j]

					if vector.magnitude(other.origin - entry.origin) <= ambienceController.__vars.clusterRadius then
						table.insert(cluster.members, other.player)
						used[j] = true
					end
				end
			end

			table.insert(clusters, cluster)
		end
	end

	return clusters
end

local function grabCloseByEntity(from: Vector3 | vector): Model
	local closestEntity = nil
	local previousDistance = math.huge

	for _, entity in ambienceController.availableEntities do
		if not entity:IsA("Model") or not entity.PrimaryPart then
			continue
		end

		if not entity:GetAttribute("Sneaking") then
			continue
		end

		local distanceTo = vector.magnitude(entity.PrimaryPart.Position - from)

		if distanceTo <= ambienceController.__vars.enemyDetectionRadius and distanceTo < previousDistance then
			closestEntity = entity
			previousDistance = distanceTo
		end
	end

	return closestEntity
end

local function createSoundCue(origin: Vector3 | vector): BasePart
	local newCuePart = Instance.new("Part")
	newCuePart.Transparency = 1
	newCuePart.Anchored = true
	newCuePart.CanCollide = false
	newCuePart.CanQuery = false
	newCuePart.Position = origin
	newCuePart.Parent = otherFolder

	local newCueSound = fakeAmbienceSounds[math.random(1, #fakeAmbienceSounds)]:Clone()
	newCueSound.Parent = newCuePart
	newCueSound:Play()

	newCueSound.Ended:Once(function()
		newCuePart:Destroy()
	end)

	return newCuePart
end

function ambienceController:runCycle()
	local now = os.clock()
	local clusters = buildPlayerClusters()

	for _, cluster in clusters do
		local closestEnemy = grabCloseByEntity(cluster.center)
		local lastTime = lastClusterCueTime[cluster.key]
		local delay = lastClusterDelay[cluster.key] or ambienceController.__vars.minInterval

		if closestEnemy then
			delay = delay / 2
		end

		if not lastTime or (now - lastTime) >= delay then
			local usesEnemy = false

			if closestEnemy and math.random() <= ambienceController.__vars.enemyRedirectChance then
				usesEnemy = true
				createSoundCue(closestEnemy.PrimaryPart.Position)
			end

			if not usesEnemy then
				createSoundCue(cluster.center + mathUtilities.getCircularOffset(30))
			end

			lastClusterCueTime[cluster.key] = now
			lastClusterDelay[cluster.key] =
				math.random(ambienceController.__vars.minInterval, ambienceController.__vars.maxInterval)
		end
	end
end

function ambienceController:updateEntities()
	ambienceController.availableEntities = entities:GetChildren()
end

function ambienceController:init()
	self:updateEntities()

	task.spawn(function()
		while true do
			if isNightTime.Value then
				self:runCycle()
			end

			task.wait(ambienceController.__vars.cycleTickInterval)
		end
	end)

	entities.ChildAdded:Connect(self.updateEntities, self)
	entities.ChildRemoved:Connect(self.updateEntities, self)
end

return ambienceController
