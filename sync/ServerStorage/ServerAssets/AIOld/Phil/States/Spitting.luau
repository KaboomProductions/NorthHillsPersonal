local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local serverScriptService = game:GetService("ServerScriptService")

local sharedAssets = replicatedStorage.SharedAssets
local effects = sharedAssets.Effects
local particles = effects.Particles

local gameValues = replicatedStorage.Values
local roundCycleValues = gameValues.RoundCycle
local climateState = roundCycleValues.ClimateState

local projectiles = particles.Projectiles
local spitballProjectiles = projectiles.Spitballs
local acidSpitPreset = spitballProjectiles.Acid
local fireSpitPreset = spitballProjectiles.Fire

local serverAssets = serverStorage.ServerAssets
local serverEffects = serverAssets.Effects
local chargePrefabs = serverEffects.SpitCharges

local projectilesController = require(serverScriptService.Controllers.Projectiles)

local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local _mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)
local baseState = require(serverAssets.AI.StateMachine.StateMachine.BaseState)

local ignoreFolder = workspace.Ignore
local otherFolder = ignoreFolder.Other
local _wellNodes = otherFolder.WellNodes:GetChildren()

local spittingState = baseState.extend("Spawning")

local function applySpread(direction: Vector3, spreadRadians: number)
	if spreadRadians <= 0 then
		return direction
	end

	local randomAxis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
	local randomAngle = (math.random() - 0.5) * 2 * spreadRadians

	return CFrame.fromAxisAngle(randomAxis, randomAngle) * direction
end

function spittingState:isDirectionBlocked(origin, direction, distance)
	local result = workspace:Raycast(origin, direction * distance, self.controller.targeting.visibilityRaycastParams)
	return result ~= nil
end

function spittingState:handleMovement(nearestTarget)
	local spittingConfig = self.config.spitting
	local minDistance = spittingConfig.minDistance
	local maxDistance = spittingConfig.maxDistance
	local tolerance = spittingConfig.tolerance

	local currentTime = os.clock()
	local rootOrigin = self.rootPart.Position

	local toTarget = self.lastTargetPosition - rootOrigin
	local distance = vector.magnitude(toTarget)

	local direction = toTarget.Unit
	local strafeDirection = Vector3.new(-direction.Z, 0, direction.X)

	self.strafeSignal = self.strafeSignal or (math.random(1, 2) == 1 and -1 or 1)
	self.nextStrafeSwitch = self.nextStrafeSwitch or 0

	if currentTime >= self.nextStrafeSwitch then
		self.strafeSignal = -self.strafeSignal
		self.nextStrafeSwitch = currentTime + math.random(1, 3)
	end

	if distance < minDistance then
		self.moveVector = -direction
	elseif distance > maxDistance then
		self.moveVector = direction
	else
		self.moveVector = strafeDirection * self.strafeSignal
	end

	if self:isDirectionBlocked(rootOrigin, self.moveVector, tolerance) then
		local alternateVector = -self.moveVector

		if not self:isDirectionBlocked(rootOrigin, alternateVector, tolerance) then
			self.moveVector = alternateVector
		else
			if not self:isDirectionBlocked(rootOrigin, direction, tolerance) then
				self.moveVector = direction
			else
				self.moveVector = Vector3.zero
			end
		end
	end

	self.controller:traverse(
		self.controller.targeting:isTargetVisible(nearestTarget) and rootOrigin + self.moveVector * 10 or nearestTarget
	)
end

function spittingState:enter()
	local speedController = self.controller.speedController
	local walkSpeeds = self.config.shared.walkSpeeds

	local isDryState = climateState.Value == "Dry"

	local lowerJawBone = self.rootPart:FindFirstChild("LowerJaw", true)

	local acidLights = lowerJawBone.AcidLights
	local chosenAcidLight = isDryState and acidLights.Fire or acidLights.Acid
	local acidLightTween = tweenService:Create(chosenAcidLight, TweenInfo.new(1), {
		Brightness = 15,
	})

	acidLightTween:Play()

	local newChargeParticle = isDryState and chargePrefabs.Fire or chargePrefabs.Acid
	newChargeParticle = newChargeParticle:Clone()
	newChargeParticle.Parent = lowerJawBone

	local tracks = self.tracks
	local spitTracks = tracks.spit

	local chosenTrack = self.isCrowdControl and spitTracks.crowdControl or spitTracks.regular
	chosenTrack:Play()

	speedController:clearAll()
	speedController:setModifier("spitting", walkSpeeds.spit - walkSpeeds.idle)

	self.agent:SetAttribute("Spitting", true)

	self.controller:recordActionTime("spit")
	self.controller:setOrientationEnabled(true)
	self.controller:setCanStun(false)
	self.controller:setCanAttack(false)

	self.connections.onSpit = chosenTrack:GetMarkerReachedSignal("Spit"):Connect(function()
		acidLightTween:Cancel()

		tweenService
			:Create(chosenAcidLight, TweenInfo.new(0.03), {
				Brightness = 0,
			})
			:Play()

		local aimDirection = (self.lastTargetPosition - lowerJawBone.WorldPosition).Unit
		local distance = vector.magnitude(self.lastTargetPosition - lowerJawBone.WorldPosition)
		local scaledSpread = self.config.spitting.aimSpread * math.clamp(distance / 30, 0.5, 2)

		projectilesController.createProjectile({
			origin = lowerJawBone.WorldPosition,
			direction = applySpread(aimDirection, scaledSpread),
			projectileObject = isDryState and fireSpitPreset or acidSpitPreset,
			velocity = 100,
			projectileId = "Spit",

			specialInfo = {
				isFire = isDryState,
			},
		})

		audioUtilities.playSound({
			sound = self.sounds.Spit.Fire,
			parent = self.rootPart,
		})

		task.spawn(function()
			local currentLifetime = 0
			local chargeParticles = newChargeParticle:GetDescendants()

			for _, particle: ParticleEmitter in chargeParticles do
				if not particle:IsA("ParticleEmitter") then
					continue
				end

				if particle.Lifetime.Max > currentLifetime then
					currentLifetime = particle.Lifetime.Max
				end

				particle.Enabled = false
			end

			task.delay(currentLifetime, function()
				newChargeParticle:Destroy()
			end)
		end)
	end)

	chosenTrack.Ended:Once(function()
		self.controller:setCanStun(true)
		self.controller:setMidAction(false)
		self.controller:setOrientationEnabled(false)
		self.controller.stateMachine:change(self.controller.states.Running)
	end)
end

function spittingState:exit()
	self.agent:SetAttribute("Spitting", false)
end

function spittingState:update(_deltaTime)
	local nearestTarget = self.controller.targeting:getNearestTarget({
		range = 100,
		canRaycast = false,
	})

	if nearestTarget ~= nil then
		local targetHead = nearestTarget.agent:FindFirstChild("Head")
		self.lastTargetPosition = targetHead and targetHead.Position or nearestTarget.root.Position + Vector3.yAxis * 4

		self:handleMovement(nearestTarget)
	end

	self.controller:turnToward(self.lastTargetPosition)
end

function spittingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(spittingState, controller, extraInfo)
	self.isCrowdControl = self.agent:GetAttribute("CrowdControl")

	return self
end

return spittingState
