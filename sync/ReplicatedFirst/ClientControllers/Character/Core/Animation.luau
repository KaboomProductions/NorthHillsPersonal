local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local config = require(script.Config)
local stateManagerModule = require(script.StateManager)
local trackLoader = require(script.TrackLoader)
local trackUtils = require(script.TrackUtils)

local clientConfig = require(replicatedFirst.ClientData.ClientConfig)
local networking = require(replicatedStorage.Communication.Networking)

local transitionTag = "MovesetTransition"

local animationController = {}
animationController.__index = animationController
local activeController = nil

animationController.__vars = {
	activeVariantName = nil,
	lastFootstepTime = 0,
	lastMovementCyclePhase = 0,
	lastMovementCycleTimestamp = 0,
	layerLingerExpireTime = 0,
	locomotionBlendAlpha = 0,
	sprintBlendAlpha = nil,
	transitionVersion = 0,
}

function animationController:bindCharacter(character: Model)
	local player = players.LocalPlayer
	character = character or player.Character or player.CharacterAdded:Wait()

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
	local rootPart = humanoid.RootPart or character:WaitForChild("HumanoidRootPart")

	self.runtime.transitionVersion += 1

	for index, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[index] = nil
	end

	self.player = player
	self.character = character
	self.humanoid = humanoid
	self.animator = animator
	self.rootPart = rootPart

	self.tracks = trackLoader.load(self.animator, config)

	self.runtime.activeDirectionalTracks = {}
	self.runtime.smoothedDirectionWeights = {}
	self.runtime.locomotionBlendAlpha = 0
	self.runtime.sprintBlendAlpha = nil
	self.runtime.lastFootstepTime = 0
	self.runtime.lastMovementCyclePhase = 0
	self.runtime.lastMovementCycleTimestamp = 0
	self.runtime.layerLingerExpireTime = 0

	self.stateManager = stateManagerModule.new(self, config.states, "healthy")
	local initialStateSnapshot = self:getStateSnapshot()
	self.stateManager:initialize(initialStateSnapshot)
	local activeState = self.stateManager:getCurrentState()
	self.runtime.activeVariantName = activeState and activeState:resolveVariant(initialStateSnapshot) or nil

	self:bindFootstepMarkers()
end

function animationController:getStateSnapshot()
	return {
		crouching = self.character:GetAttribute("Crouching") == true,
		injuredLevel = self.character:GetAttribute("Injured") or 0,
		sprinting = self.character:GetAttribute("Sprinting") == true,
	}
end

function animationController:getCurrentStateTracks()
	return self.stateManager and self.stateManager:getCurrentTracks() or nil
end

function animationController:getMovementCyclePhase(): number?
	return trackUtils.getDirectionalPlaybackSyncPhase(self.runtime.activeDirectionalTracks)
end

function animationController.getActiveController()
	return activeController
end

function animationController:bindFootstepMarkers()
	for _, stateTrackGroup in pairs(self.tracks.states) do
		for _, variantTrackGroup in pairs(stateTrackGroup.variants or {}) do
			trackUtils.bindMarkerSignals(variantTrackGroup.movement, "Step", function()
				local currentTime = os.clock()
				if currentTime - self.runtime.lastFootstepTime < config.footstepCooldown then
					return
				end

				self.runtime.lastFootstepTime = currentTime

				networking.events.reportFootstep:FireServer({
					sprinting = self.character:GetAttribute("Sprinting"),
					crouching = self.character:GetAttribute("Crouching"),
				})
			end, self.connections)
		end
	end
end

function animationController:playTransition(
	previousState,
	previousVariantName: string?,
	nextState,
	nextVariantName: string?
)
	local character = self.character
	if character:HasTag(transitionTag) then
		return false
	end

	local previousMovementTracks = previousState and previousState:getMovementTracks(previousVariantName) or nil
	local nextMovementTracks = nextState and nextState:getMovementTracks(nextVariantName) or nil
	local previousIdleTrack = previousState and previousState:getIdleTrack(previousVariantName) or nil
	local previousExitTransitionTrack = previousState and previousState:getExitTransition(previousVariantName) or nil
	local nextEnterTransitionTrack = nextState and nextState:getEnterTransition(nextVariantName) or nil

	character:AddTag(transitionTag)
	trackUtils.stopDirectionalTracks(self.runtime.activeDirectionalTracks, config.fadeTime)
	trackUtils.stopTree(previousMovementTracks, config.fadeTime)
	trackUtils.stopTree(nextMovementTracks, config.fadeTime)
	trackUtils.stopTrack(previousIdleTrack, config.fadeTime)
	trackUtils.stopTrack(self.tracks.defaultIdle, config.fadeTime)

	local transitionUnlockTracks = {}

	local function queueTransitionTrack(transitionTrack: AnimationTrack?)
		if not transitionTrack then
			return
		end

		trackUtils.stopTrack(transitionTrack, config.fadeTime)
		transitionTrack:Play(config.fadeTime)
		table.insert(transitionUnlockTracks, transitionTrack)
	end

	queueTransitionTrack(previousExitTransitionTrack)
	queueTransitionTrack(nextEnterTransitionTrack)

	if #transitionUnlockTracks == 0 then
		character:RemoveTag(transitionTag)
		return false
	end

	self.runtime.transitionVersion += 1
	local expectedTransitionVersion = self.runtime.transitionVersion

	task.spawn(function()
		for _, transitionTrack in ipairs(transitionUnlockTracks) do
			trackUtils.awaitUnlock(transitionTrack, config.fadeTime)
		end

		if self.runtime.transitionVersion ~= expectedTransitionVersion then
			return
		end

		if self.character and self.character.Parent and self.character:HasTag(transitionTag) then
			self.character:RemoveTag(transitionTag)
		end
	end)

	return true
end

function animationController:applyMovementLayerSpeeds(activeState, movementLayers)
	local speedPresets = clientConfig.movement.speedPresets

	for _, movementLayer in ipairs(movementLayers) do
		local movementTracks = movementLayer.tracks
		local variantName = movementLayer.variantName

		if movementTracks == nil or variantName == nil then
			continue
		end

		local movementSpeedKey = activeState:getSpeedKey(variantName)
		local referenceWalkSpeed = speedPresets[movementSpeedKey] or speedPresets.walking or 1
		referenceWalkSpeed = math.max(referenceWalkSpeed, 0.01)

		local playbackSpeed = math.clamp(self.humanoid.WalkSpeed / referenceWalkSpeed, 0.5, 2)
		trackUtils.adjustTreeSpeed(movementTracks, playbackSpeed)
	end
end

function animationController:getTargetSprintBlendAlpha(activeState, activeVariantName: string?): number
	if not activeState:hasVariant("walking") or not activeState:hasVariant("sprinting") then
		return 0
	end

	if activeVariantName == "sprinting" then
		return 1
	end

	if activeVariantName == "walking" then
		return 0
	end

	local speedPresets = clientConfig.movement.speedPresets
	local walkingSpeedKey = activeState:getSpeedKey("walking")
	local sprintingSpeedKey = activeState:getSpeedKey("sprinting")
	local walkingSpeed = speedPresets[walkingSpeedKey] or speedPresets.walking or 0
	local sprintingSpeed = speedPresets[sprintingSpeedKey] or walkingSpeed
	local speedRange = sprintingSpeed - walkingSpeed

	if speedRange <= 0 then
		return self.character:GetAttribute("Sprinting") == true and 1 or 0
	end

	return math.clamp((self.humanoid.WalkSpeed - walkingSpeed) / speedRange, 0, 1)
end

function animationController:updateSprintBlendAlpha(activeState, activeVariantName: string?, deltaTime: number): number
	if not activeState:hasVariant("walking") or not activeState:hasVariant("sprinting") then
		self.runtime.sprintBlendAlpha = 0
		return 0
	end

	local targetSprintBlendAlpha = self:getTargetSprintBlendAlpha(activeState, activeVariantName)
	local currentSprintBlendAlpha = self.runtime.sprintBlendAlpha

	if currentSprintBlendAlpha == nil then
		self.runtime.sprintBlendAlpha = targetSprintBlendAlpha
		return targetSprintBlendAlpha
	end

	if targetSprintBlendAlpha == currentSprintBlendAlpha then
		return currentSprintBlendAlpha
	end

	local movementBlendTimes = config.movementBlendTimes
	local movementBlendTime = targetSprintBlendAlpha > currentSprintBlendAlpha and movementBlendTimes.walkingToSprinting
		or movementBlendTimes.sprintingToWalking
	movementBlendTime = movementBlendTime or movementBlendTimes.default or 0

	if movementBlendTime <= 0 then
		self.runtime.sprintBlendAlpha = targetSprintBlendAlpha
		return targetSprintBlendAlpha
	end

	local blendStep = deltaTime / movementBlendTime
	if targetSprintBlendAlpha > currentSprintBlendAlpha then
		currentSprintBlendAlpha = math.min(currentSprintBlendAlpha + blendStep, targetSprintBlendAlpha)
	else
		currentSprintBlendAlpha = math.max(currentSprintBlendAlpha - blendStep, targetSprintBlendAlpha)
	end

	self.runtime.sprintBlendAlpha = currentSprintBlendAlpha
	return currentSprintBlendAlpha
end

function animationController:getMovementLayers(activeState, activeVariantName: string?, sprintBlendAlpha: number?)
	local activeMovementTracks = activeState:getMovementTracks(activeVariantName)
	if activeMovementTracks == nil then
		return {}
	end

	if
		activeVariantName == "crouching"
		or not activeState:hasVariant("walking")
		or not activeState:hasVariant("sprinting")
	then
		return {
			{
				name = activeVariantName or activeState:getDefaultVariantName(),
				variantName = activeVariantName,
				tracks = activeMovementTracks,
				weight = 1,
			},
		}
	end

	local blendAlpha: number = sprintBlendAlpha or 0
	local movementLayers = {}

	local blendEpsilon = config.movementBlendEpsilon
	local currentTime = os.clock()
	if blendAlpha > blendEpsilon and blendAlpha < 1 - blendEpsilon then
		self.runtime.layerLingerExpireTime = currentTime + config.movementLayerLingerTime
	end
	local isLingerActive = currentTime < self.runtime.layerLingerExpireTime
	local lingerWeightFloor = 0.001

	if blendAlpha < 1 - blendEpsilon or isLingerActive then
		table.insert(movementLayers, {
			name = "walking",
			variantName = "walking",
			tracks = activeState:getMovementTracks("walking"),
			weight = math.max(1 - blendAlpha, lingerWeightFloor),
		})
	end

	if blendAlpha > blendEpsilon or isLingerActive then
		table.insert(movementLayers, {
			name = "sprinting",
			variantName = "sprinting",
			tracks = activeState:getMovementTracks("sprinting"),
			weight = math.max(blendAlpha, lingerWeightFloor),
		})
	end

	if #movementLayers == 0 then
		table.insert(movementLayers, {
			name = activeVariantName or activeState:getDefaultVariantName(),
			variantName = activeVariantName,
			tracks = activeMovementTracks,
			weight = 1,
		})
	end

	return movementLayers
end

function animationController:shouldBlendLocomotionVariants(
	didStateChange: boolean,
	previousState,
	previousVariantName: string?,
	activeState,
	activeVariantName: string?
): boolean
	if didStateChange or previousState ~= activeState then
		return false
	end

	if previousVariantName == activeVariantName then
		return false
	end

	local isWalkingSprintPair = (previousVariantName == "walking" and activeVariantName == "sprinting")
		or (previousVariantName == "sprinting" and activeVariantName == "walking")

	return isWalkingSprintPair
		and activeState
		and activeState:hasVariant("walking")
		and activeState:hasVariant("sprinting")
end

function animationController:stopMovement(activeMovementTracks)
	local movementBlendTime = config.movementBlendTimes.default
	trackUtils.stopDirectionalTracks(self.runtime.activeDirectionalTracks, movementBlendTime)
	trackUtils.stopTree(activeMovementTracks, movementBlendTime)
end

function animationController:cacheCurrentMovementCyclePhase()
	local currentPhase = trackUtils.getDirectionalPlaybackSyncPhase(self.runtime.activeDirectionalTracks)
	if currentPhase == nil then
		return
	end

	self.runtime.lastMovementCyclePhase = currentPhase
	self.runtime.lastMovementCycleTimestamp = os.clock()
end

function animationController:getRestartPlaybackSyncPhase(): number?
	if next(self.runtime.activeDirectionalTracks) ~= nil then
		return nil
	end

	local timeSinceLastMovementCycle = os.clock() - self.runtime.lastMovementCycleTimestamp
	if timeSinceLastMovementCycle > config.movementRestartSyncWindow then
		return nil
	end

	return self.runtime.lastMovementCyclePhase
end

function animationController:updateVelocity()
	local worldVelocity = self.rootPart.AssemblyLinearVelocity
	local localVelocity = self.rootPart.CFrame:VectorToObjectSpace(worldVelocity)

	self.runtime.movement.forwardVelocity = localVelocity.Z
	self.runtime.movement.lateralVelocity = localVelocity.X
	self.runtime.movement.speedMagnitude = worldVelocity.Magnitude
end

function animationController:updateLocomotionBlend(isMovementInputActive: boolean, deltaTime: number): number
	local targetAlpha = isMovementInputActive and 1 or 0
	local currentAlpha = self.runtime.locomotionBlendAlpha
	local blendSpeed = isMovementInputActive and config.locomotionBlendSpeed.enter or config.locomotionBlendSpeed.exit

	local alpha = 1 - math.exp(-blendSpeed * deltaTime)
	local newAlpha = currentAlpha + (targetAlpha - currentAlpha) * alpha

	--// Snap to target when close enough to avoid lingering near-zero weights
	if math.abs(newAlpha - targetAlpha) < 0.005 then
		newAlpha = targetAlpha
	end

	self.runtime.locomotionBlendAlpha = newAlpha
	return newAlpha
end

function animationController:updateDirectionWeights(deltaTime: number): { [string]: number }
	local targetWeights = trackUtils.computeDirectionWeights(self.runtime.movement)
	local smoothedWeights = self.runtime.smoothedDirectionWeights
	local blendAlpha = 1 - math.exp(-config.directionBlendSpeed * deltaTime)

	local allDirectionNames = {}
	for directionName in pairs(smoothedWeights) do
		allDirectionNames[directionName] = true
	end
	for directionName in pairs(targetWeights) do
		allDirectionNames[directionName] = true
	end

	local nextWeights = {}
	for directionName in pairs(allDirectionNames) do
		local currentWeight = smoothedWeights[directionName] or 0
		local targetWeight = targetWeights[directionName] or 0
		local newWeight = currentWeight + (targetWeight - currentWeight) * blendAlpha

		if newWeight < 0.001 then
			newWeight = 0
		end

		if newWeight > 0 then
			nextWeights[directionName] = newWeight
		end
	end

	self.runtime.smoothedDirectionWeights = nextWeights
	return nextWeights
end

function animationController:updateMovement(deltaTime: number)
	local character = self.character
	if character:HasTag(transitionTag) then
		return
	end

	local stateSnapshot = self:getStateSnapshot()
	local didStateChange, previousState, activeState = self.stateManager:update(stateSnapshot)

	activeState = self.stateManager:getCurrentState()
	if not activeState then
		return
	end

	local previousVariantName = self.runtime.activeVariantName
	local activeVariantName = activeState:resolveVariant(stateSnapshot)
	local didVariantChange = previousVariantName ~= activeVariantName

	local shouldBlendLocomotionVariants = self:shouldBlendLocomotionVariants(
		didStateChange,
		previousState,
		previousVariantName,
		activeState,
		activeVariantName
	)

	if (didStateChange or didVariantChange) and not shouldBlendLocomotionVariants then
		local transitionSourceState = didStateChange and previousState or activeState
		local didStartTransition =
			self:playTransition(transitionSourceState, previousVariantName, activeState, activeVariantName)

		self.runtime.activeVariantName = activeVariantName

		if didStartTransition then
			return
		end
	end

	self.runtime.activeVariantName = activeVariantName

	local activeMovementTracks = activeState:getMovementTracks(activeVariantName)
	local sprintBlendAlpha = self:updateSprintBlendAlpha(activeState, activeVariantName, deltaTime)
	local movementLayers = self:getMovementLayers(activeState, activeVariantName, sprintBlendAlpha)

	local isMovementInputActive = self.runtime.movement.speedMagnitude > config.moveThreshold
		and self.humanoid.MoveDirection.Magnitude > 0
	local activeIdleTrack = activeState:getIdleTrack(activeVariantName)

	local locomotionBlendAlpha = self:updateLocomotionBlend(isMovementInputActive, deltaTime)

	if locomotionBlendAlpha < 1 then
		if activeIdleTrack then
			if not activeIdleTrack.IsPlaying then
				activeIdleTrack:Play(config.fadeTime)
			end

			trackUtils.setTrackWeight(activeIdleTrack, 1 - locomotionBlendAlpha)
		end
	else
		trackUtils.stopTrack(activeIdleTrack, config.fadeTime)
		trackUtils.stopTrack(self.tracks.defaultIdle, config.fadeTime)
	end

	if locomotionBlendAlpha > 0 then
		local blendedMovementLayers = {}
		for _, movementLayer in ipairs(movementLayers) do
			table.insert(blendedMovementLayers, {
				name = movementLayer.name,
				variantName = movementLayer.variantName,
				tracks = movementLayer.tracks,
				weight = movementLayer.weight * locomotionBlendAlpha,
			})
		end

		if isMovementInputActive then
			self:applyMovementLayerSpeeds(activeState, blendedMovementLayers)
		else
			--// Freeze at current pose while blend fades out so legs don't keep cycling
			for _, animationTrack in pairs(self.runtime.activeDirectionalTracks) do
				if animationTrack.IsPlaying then
					trackUtils.setTrackSpeed(animationTrack, 0)
				end
			end
		end

		local restartSyncPhase = self:getRestartPlaybackSyncPhase()
		local directionalWeights = self:updateDirectionWeights(deltaTime)
		self.runtime.activeDirectionalTracks = trackUtils.playMovementLayers(
			blendedMovementLayers :: { any },
			directionalWeights,
			self.runtime.activeDirectionalTracks,
			config.movementBlendTimes.default,
			restartSyncPhase
		)
	else
		self:cacheCurrentMovementCyclePhase()
		self:stopMovement(activeMovementTracks)
		self.runtime.smoothedDirectionWeights = {}
	end
end

function animationController:init()
	self:bindCharacter(players.LocalPlayer.Character)

	self.connections.characterAdded = players.LocalPlayer.CharacterAdded:Connect(function(character)
		self:bindCharacter(character)
	end)

	runService:UnbindFromRenderStep("Animations")
	runService:BindToRenderStep("Animations", Enum.RenderPriority.Character.Value, function(deltaTime)
		if not self.rootPart or not self.rootPart.Parent then
			return
		end

		self:updateVelocity()
		self:updateMovement(deltaTime)
	end)
end

function animationController.new()
	local self = setmetatable({}, animationController)
	self.connections = {}
	self.__vars = table.clone(animationController.__vars)
	self.runtime = self.__vars
	self.runtime.activeDirectionalTracks = {}
	self.runtime.smoothedDirectionWeights = {}
	self.runtime.movement = {
		forwardVelocity = 0,
		lateralVelocity = 0,
		speedMagnitude = 0,
	}

	activeController = self

	task.defer(self.init, self)

	return self
end

function animationController:destroy()
	runService:UnbindFromRenderStep("Animations")
	if activeController == self then
		activeController = nil
	end

	for index, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[index] = nil
	end

	setmetatable(self, nil)
end

return animationController
