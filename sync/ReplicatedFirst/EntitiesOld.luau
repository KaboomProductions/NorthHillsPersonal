local entitiesController = {}
local lightSourcesController = require(script.LightSources)
entitiesController.__index = entitiesController

entitiesController.visuals = {
	staticTransparency = {
		current = 1,
		target = 1,
		speed = 8,
	},

	vignetteTransparency = {
		current = 1,
		target = 1,
		speed = 8,
	},

	staticVolumes = {
		low = {
			current = 0,
			target = 0,
			speed = 6,
		},

		high = {
			current = 0,
			target = 0,
			speed = 6,
		},
	},

	chaseTheme = {
		fullVolume = 1,
		searchingVolumeMultiplier = 0.35,

		volume = {
			current = 1,
			target = 1,
			speed = 4,
		},
	},

	afterChaseTheme = {
		fullVolume = 0.5,

		volume = {
			current = 0,
			target = 0,
			speed = 1.1,
		},
	},

	combatTheme = {
		fullVolume = 1,
		searchingVolumeMultiplier = 0.35,

		volume = {
			current = 0,
			target = 0,
			speed = 6,
		},
	},

	distortion = {
		current = 0,
		target = 0,
		speed = 3,

		maxSquish = 0.08,
		maxShear = 0.04,
		wobbleSpeed = 2,
	},

	generalStatic = {
		minDistance = 10,
		maxDistance = 60,
		minTransparency = 0.3,
		crossfadeTolerance = 10,

		lowVolume = {
			min = 0,
			max = 1,
		},

		highVolume = {
			min = 0,
			max = 0.8,
		},
	},

	cameraShake = {
		current = 0,
		target = 0,
		speed = 8,

		minIntensity = 0.005,
		maxIntensity = 0.015,
	},

	chaseLookAt = {
		duration = 0.4,
		speed = 12,
		hoverCheckDistance = 500,
	},
}

entitiesController.threatLevels = {
	Phil = 2,
	Crawler = 1,
}

local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local player = players.LocalPlayer
local playerGui = player.PlayerGui
local currentCamera = workspace.CurrentCamera

local settingsConfig = player:WaitForChild("Settings", 3)
local photosensitivityModeSetting = settingsConfig.Gameplay:WaitForChild("Photosensitivity Mode", 1)

local interface = playerGui:WaitForChild("Interface")
local vignettesFrame = interface.Vignettes
local staticFrame = vignettesFrame.Static
local staticVignette = staticFrame.Vignette

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local mathUtilities = require(sharedUtilities.MathUtils)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)

local effects = sharedAssets.Effects
local sounds = effects.Sounds
local visualizerSounds = sounds.Visualizer

local staticSounds = visualizerSounds.Static
local mainStingers = visualizerSounds.Stingers:GetChildren()
local chaseEndStinger = visualizerSounds.ChaseEndStinger
local themes = visualizerSounds.Themes

local staticLowSound = staticSounds.Low
local staticHighSound = staticSounds.High

local components = workspace.Components
local entities = components.Entities

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

function entitiesController:preload()
	self:rebuildEntityList()
	self.rng = Random.new()
	self.lastStaticUpdate = os.clock()
	self.lightSourcesController = lightSourcesController.new(self)

	self.forcedLookAt = {
		active = false,
		startTime = 0,
		entity = nil,
	}
end

function entitiesController:rebuildEntityList()
	local currentEntities = {}
	local seen = {}

	for _, entity in entities:GetChildren() do
		if not entity:IsA("Model") or not entity.PrimaryPart then
			continue
		end
		if not entity:FindFirstChildOfClass("Humanoid") then
			continue
		end

		seen[entity] = true
		table.insert(currentEntities, entity)

		if not self.entityConnections[entity] then
			self.entityConnections[entity] = entity.Destroying:Once(function()
				if self.activeEntity == entity then
					self:killCurrentProfile(entity)
					self.activeEntity = nil
					self.forcedLookAt.active = false
				end
			end)
		end
	end

	for entity, connection in self.entityConnections do
		if not seen[entity] then
			connection:Disconnect()
			self.entityConnections[entity] = nil
		end
	end

	self.currentEntities = currentEntities
end

function entitiesController:lerpTransparency(data, deltaTime)
	data.current = data.current + (data.target - data.current) * math.min(data.speed * deltaTime, 1)

	return data.current
end

function entitiesController:lerp(a, b, t)
	return a + (b - a) * t
end

function entitiesController:getDistortionCFrame(intensity, time, allowWobble)
	if intensity <= 0.001 then
		return CFrame.new()
	end

	local config = self.visuals.distortion
	local wobble = (allowWobble and math.sin(time * config.wobbleSpeed) or 0) * intensity

	local squishY = 1 - (config.maxSquish * intensity)
	local shear = config.maxShear * wobble

	return CFrame.new(0, 0, 0, 1, shear, 0, shear, squishY, 0, 0, 0, 1)
end

function entitiesController:isCameraLookingAtEntity(entity)
	local origin = currentCamera.CFrame.Position
	local direction = currentCamera.CFrame.LookVector * self.visuals.chaseLookAt.hoverCheckDistance

	raycastParams.FilterDescendantsInstances = { entity }

	return workspace:Raycast(origin, direction, raycastParams) ~= nil
end

function entitiesController:getLowStaticAlpha(distance)
	local config = self.visuals.generalStatic
	local tolerance = config.crossfadeTolerance
	local innerBound = config.minDistance - tolerance
	local outerBound = config.maxDistance / 2 + tolerance

	if distance <= innerBound then
		return 0
	elseif distance <= config.maxDistance / 2 then
		local t = (distance - innerBound) / (config.maxDistance / 2 - innerBound)
		return self:lerp(0, 0.5, t)
	elseif distance <= outerBound then
		local t = (distance - config.maxDistance / 2) / tolerance
		return self:lerp(0.5, 1, t)
	else
		return 1
	end
end

function entitiesController:getDistanceToEntity(entity)
	local character = player.Character
	local root = character and character.PrimaryPart

	if not root or not entity.PrimaryPart then
		return math.huge
	end

	return (root.Position - entity.PrimaryPart.Position).Magnitude
end

function entitiesController:updateEffectsFromDistance(distanceStuds: number)
	local config = self.visuals.generalStatic

	local alpha = math.clamp((distanceStuds - config.minDistance) / (config.maxDistance - config.minDistance), 0, 1)
	self.visuals.vignetteTransparency.target = config.minTransparency + (1 - config.minTransparency) * alpha
	self.visuals.distortion.target = 1 - alpha

	local lowAlpha = self:getLowStaticAlpha(distanceStuds)

	self.visuals.staticVolumes.low.target = self:lerp(config.lowVolume.min, config.lowVolume.max, lowAlpha)
	self.visuals.staticVolumes.high.target = self:lerp(config.highVolume.min, config.highVolume.max, 1 - lowAlpha)

	local shake = self.visuals.cameraShake
	shake.target = self:lerp(shake.maxIntensity, shake.minIntensity, alpha)
end

function entitiesController:getHighestThreat()
	local bestEntity = nil
	local bestThreat = -math.huge

	for _, entity in self.currentEntities do
		if entity:GetAttribute("Chasing") then
			local targets = entity:FindFirstChild("Targets")
			local threat = entitiesController.threatLevels[entity.Name] or 0
			local playerIsTarget = targets and targets:FindFirstChild(player.UserId)

			if threat == 0 or not playerIsTarget then
				continue
			end

			if threat > bestThreat then
				bestThreat = threat
				bestEntity = entity
			end
		end
	end

	return bestEntity
end

function entitiesController:init()
	self:preload()

	self.connections.update = runService.RenderStepped:Connect(function(deltaTime: number)
		self:update(deltaTime)
	end)

	self.connections.childAdded = entities.ChildAdded:Connect(function()
		self:rebuildEntityList()
	end)

	self.connections.childRemoved = entities.ChildRemoved:Connect(function()
		self:rebuildEntityList()
	end)
end

function entitiesController.new()
	local self = setmetatable({}, entitiesController)

	self.connections = {}
	self.entityConnections = {}
	self.sinceChaseCache = {}
	self.activeEffectInstances = {}
	self.activeEffectTweens = {}
	self.combatMusicActive = false

	entitiesController.instance = self

	task.defer(self.init, self)

	return self
end

function entitiesController:destroy()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	for entity, connection in self.entityConnections do
		connection:Disconnect()
		self.entityConnections[entity] = nil
	end

	for activeTween in self.activeEffectTweens do
		activeTween:Cancel()
	end
	table.clear(self.activeEffectTweens)

	for effectInstance in self.activeEffectInstances do
		effectInstance:Destroy()
	end
	table.clear(self.activeEffectInstances)

	if self.lightSourcesController then
		self.lightSourcesController:destroy()
		self.lightSourcesController = nil
	end

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:clearChase()
	end

	local visuals = self.visuals
	visuals.staticTransparency.current = 1
	visuals.staticTransparency.target = 1
	visuals.vignetteTransparency.current = 1
	visuals.vignetteTransparency.target = 1
	visuals.cameraShake.current = 0
	visuals.cameraShake.target = 0
	visuals.distortion.current = 0
	visuals.distortion.target = 0
	visuals.staticVolumes.low.current = 0
	visuals.staticVolumes.low.target = 0
	visuals.staticVolumes.high.current = 0
	visuals.staticVolumes.high.target = 0
	visuals.chaseTheme.volume.current = 0
	visuals.chaseTheme.volume.target = 0
	visuals.afterChaseTheme.volume.current = 0
	visuals.afterChaseTheme.volume.target = 0
	visuals.combatTheme.volume.current = 0
	visuals.combatTheme.volume.target = 0

	staticFrame.ImageTransparency = 1
	staticVignette.ImageTransparency = 1
	for _, ownedSound in { staticLowSound, staticHighSound, themes.Chase, themes.AfterChase, themes.Combat } do
		ownedSound.Volume = 0
		ownedSound:Stop()
	end

	if entitiesController.instance == self then
		entitiesController.instance = nil
	end

	table.clear(self.sinceChaseCache)
	if self.currentEntities then
		table.clear(self.currentEntities)
	end
	setmetatable(self, nil)
end

function entitiesController:getEntities()
	return self.currentEntities
end

function entitiesController:updateChaseCooldown()
	if not self.coolingDownEntity then
		return
	end

	local lastChased = self.sinceChaseCache[self.coolingDownEntity] or 0

	if os.clock() - lastChased >= 15 then
		self.visuals.afterChaseTheme.volume.target = 0
		self.coolingDownEntity = nil
	end
end

function entitiesController:killCurrentProfile(entity)
	self.visuals.staticTransparency.target = 1
	self.visuals.vignetteTransparency.target = 1

	self.visuals.cameraShake.target = 0
	self.visuals.distortion.target = 0

	self.visuals.staticVolumes.low.target = 0
	self.visuals.staticVolumes.high.target = 0

	self.visuals.chaseTheme.volume.target = 0

	if entity then
		local entityId = entity.Name

		if not self.registeredKillProfile then
			self.registeredKillProfile = true
			themes.AfterChase:Play()
		end

		if entityId == "Phil" then
			self.coolingDownEntity = entityId
			self.visuals.afterChaseTheme.volume.target = self.visuals.afterChaseTheme.fullVolume
		else
			self.coolingDownEntity = nil
			self.visuals.afterChaseTheme.volume.target = 0
		end
	end
end

function entitiesController:swapProfile(entity)
	local entityId = entity.Name
	local randomStinger = mainStingers[math.random(1, #mainStingers)]
	randomStinger:Play()

	self.registeredKillProfile = false
	self.coolingDownEntity = nil
	self.combatMusicActive = false

	self.visuals.chaseTheme.volume.target = self.visuals.chaseTheme.fullVolume
	self.visuals.afterChaseTheme.volume.target = 0

	if entityId == "Phil" and not entity:GetAttribute("Searching") then
		self.visuals.staticTransparency.target = 0.7

		if (self.character and not self.character:GetAttribute("Sprinting")) or not self.character then
			self.forcedLookAt.active = true
			self.forcedLookAt.startTime = os.clock()
			self.forcedLookAt.entity = entity
		end

		local newColorCorrection = Instance.new("ColorCorrectionEffect")
		newColorCorrection.TintColor = Color3.fromRGB(255, 0, 0)

		if not photosensitivityModeSetting.Value then
			newColorCorrection.Contrast = 0.5
			newColorCorrection.Saturation = -4
			newColorCorrection.Brightness = 6
		end

		local newHighlight = Instance.new("Highlight")
		newHighlight.Adornee = entity
		newHighlight.OutlineTransparency = 1
		newHighlight.FillTransparency = 0.5
		newHighlight.FillColor = photosensitivityModeSetting.Value and Color3.fromRGB(80, 80, 80) or Color3.new(0, 0, 0)

		newColorCorrection.Parent = currentCamera
		newHighlight.Parent = entity

		local colorCorrectionTween1 = tweenService:Create(
			newColorCorrection,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Contrast = 0, Saturation = 0, Brightness = 0 }
		)

		local colorCorrectionTween2 = tweenService:Create(
			newColorCorrection,
			TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TintColor = Color3.new(1, 1, 1) }
		)

		local highlightTween = tweenService:Create(
			newHighlight,
			TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FillTransparency = 1 }
		)

		colorCorrectionTween1:Play()
		colorCorrectionTween2:Play()
		highlightTween:Play()

		self.activeEffectInstances[newColorCorrection] = true
		self.activeEffectInstances[newHighlight] = true
		self.activeEffectTweens[colorCorrectionTween1] = true
		self.activeEffectTweens[colorCorrectionTween2] = true
		self.activeEffectTweens[highlightTween] = true

		highlightTween.Completed:Once(function()
			self.activeEffectTweens[colorCorrectionTween1] = nil
			self.activeEffectTweens[colorCorrectionTween2] = nil
			self.activeEffectTweens[highlightTween] = nil
			self.activeEffectInstances[newColorCorrection] = nil
			self.activeEffectInstances[newHighlight] = nil

			if getmetatable(self) then
				self.visuals.staticTransparency.target = 1
				self.visuals.vignetteTransparency.target = 0.5
			end

			newColorCorrection:Destroy()
			newHighlight:Destroy()
		end)
	end

	if self.currentTheme then
		self.currentTheme:Stop()
	end

	self.currentTheme = themes.Chase
	self.currentTheme:Play()
end

function entitiesController:update(deltaTime: number)
	self.character = player.Character

	local bestEntity = self:getHighestThreat()
	local activeHaptics = haptics.getActiveHaptics()
	local shakeIntensity = self:lerpTransparency(self.visuals.cameraShake, deltaTime)
	local distortionIntensity = self:lerpTransparency(self.visuals.distortion, deltaTime)
	local inCombat = self.character and self.character:GetAttribute("Combat") == true
	local isSearching = bestEntity ~= nil and bestEntity:GetAttribute("Searching") == true

	if bestEntity and inCombat then
		self.combatMusicActive = true
	end

	local combatMultiplier = self.combatMusicActive and 0 or 1

	if bestEntity and self.activeEntity ~= bestEntity then
		self.activeEntity = bestEntity
		self:swapProfile(bestEntity)
	elseif not bestEntity and self.activeEntity then
		self:killCurrentProfile(self.activeEntity)
		self.activeEntity = nil
		self.forcedLookAt.active = false
		self.combatMusicActive = false

		chaseEndStinger:Play()
	end

	self:updateChaseCooldown()

	if bestEntity then
		self.sinceChaseCache[bestEntity.Name] = os.clock()
		local entityDistanceStuds = self:getDistanceToEntity(bestEntity)

		if activeHaptics then
			if inCombat then
				activeHaptics:setCombatChaseDistance(entityDistanceStuds, self.visuals.generalStatic.maxDistance)
			else
				activeHaptics:setChaseDistance(entityDistanceStuds, self.visuals.generalStatic.maxDistance)
			end
		end

		self.visuals.chaseTheme.volume.target = isSearching
				and self.visuals.chaseTheme.fullVolume * self.visuals.chaseTheme.searchingVolumeMultiplier
			or self.visuals.chaseTheme.fullVolume

		if self.forcedLookAt.active and self.forcedLookAt.entity == bestEntity then
			local elapsed = os.clock() - self.forcedLookAt.startTime
			local alreadyLookingAt = self:isCameraLookingAtEntity(bestEntity)

			if elapsed >= self.visuals.chaseLookAt.duration or alreadyLookingAt then
				self.forcedLookAt.active = false
			else
				currentCamera.CFrame = currentCamera.CFrame:Lerp(
					CFrame.lookAt(currentCamera.CFrame.Position, bestEntity:GetPivot().Position),
					math.min(self.visuals.chaseLookAt.speed * deltaTime, 1)
				)
			end
		end

		self:updateEffectsFromDistance(entityDistanceStuds)

		if isSearching then
			self.visuals.staticVolumes.low.current = self.visuals.generalStatic.lowVolume.max
			self.visuals.staticVolumes.low.target = self.visuals.staticVolumes.low.current

			self.visuals.staticVolumes.high.current = self.visuals.generalStatic.highVolume.min
			self.visuals.staticVolumes.high.target = self.visuals.staticVolumes.high.current
		end
	elseif activeHaptics then
		activeHaptics:clearChase()
	end

	if os.clock() - self.lastStaticUpdate > 1 / 60 then
		staticFrame.Size = UDim2.fromScale(self.rng:NextNumber(2, 2.5), self.rng:NextNumber(2, 2.5))
		staticFrame.Rotation = self.rng:NextNumber() < 0.5 and 0 or 180

		self.lastStaticUpdate = os.clock()
	end

	staticFrame.ImageTransparency = self:lerpTransparency(self.visuals.staticTransparency, deltaTime)
	staticVignette.ImageTransparency = self:lerpTransparency(self.visuals.vignetteTransparency, deltaTime)

	staticLowSound.Volume = self:lerpTransparency(self.visuals.staticVolumes.low, deltaTime)
	staticHighSound.Volume = self:lerpTransparency(self.visuals.staticVolumes.high, deltaTime)

	if self.currentTheme then
		self.currentTheme.Volume = self:lerpTransparency(self.visuals.chaseTheme.volume, deltaTime) * combatMultiplier

		if self.currentTheme.IsPlaying and self.visuals.chaseTheme.volume.current <= 0.01 then
			self.currentTheme:Stop()
		end
	end

	local combatFullVolume = isSearching
			and self.visuals.combatTheme.fullVolume * self.visuals.combatTheme.searchingVolumeMultiplier
		or self.visuals.combatTheme.fullVolume

	self.visuals.combatTheme.volume.target = (self.combatMusicActive and not self.registeredKillProfile and bestEntity)
			and combatFullVolume
		or 0

	themes.AfterChase.Volume = self:lerpTransparency(self.visuals.afterChaseTheme.volume, deltaTime) * combatMultiplier
	themes.Combat.Volume = self:lerpTransparency(self.visuals.combatTheme.volume, deltaTime)

	if self.combatMusicActive then
		if not themes.Combat.IsPlaying then
			themes.Combat:Play()
		end
	else
		if themes.Combat.IsPlaying and themes.Combat.Volume <= 0.01 then
			themes.Combat:Stop()
		end
	end

	if themes.AfterChase.IsPlaying and themes.AfterChase.Volume <= 0.01 then
		themes.AfterChase:Stop()
	end

	if distortionIntensity > 0.001 then
		currentCamera.CFrame = currentCamera.CFrame
			* self:getDistortionCFrame(distortionIntensity, os.clock(), not photosensitivityModeSetting.Value)
	end

	if shakeIntensity > 0.001 then
		currentCamera.CFrame = currentCamera.CFrame * mathUtilities.getCameraShake(shakeIntensity, deltaTime)
	end

	self.lightSourcesController:update(deltaTime)
end

return entitiesController
