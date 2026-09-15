local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local footstepMaterialMap = require(serverStorage.ServerAssets.Dictionaries.Footsteps)

local sharedAssets = replicatedStorage.SharedAssets
local effects = sharedAssets.Effects
local sounds = effects.Sounds
local footstepSounds = sounds.Footsteps
local philFootstepSounds = footstepSounds.Phil

local moveSetAnimator = {}
moveSetAnimator.__index = moveSetAnimator
moveSetAnimator.strafeThreshold = 1
moveSetAnimator.minFootstepInterval = 0.075

function moveSetAnimator:getMoveDirection(rootPart: BasePart, velocity: Vector3)
	return rootPart.CFrame:VectorToObjectSpace(velocity)
end

function moveSetAnimator:setTrackPlaying(track: AnimationTrack, shouldPlay: boolean)
	if shouldPlay then
		if not track.IsPlaying then
			track:Play()
		end
	else
		track:Stop(0)
	end
end

function moveSetAnimator:getMoveState(localVel: Vector3)
	local x = localVel.X
	local z = localVel.Z

	if math.abs(x) > math.abs(z) then
		if x > self.strafeThreshold then
			return "right"
		elseif x < -self.strafeThreshold then
			return "left"
		end
	else
		if z > self.strafeThreshold then
			return "backward"
		elseif z < -self.strafeThreshold then
			return "forward"
		end
	end

	return "forward"
end

function moveSetAnimator:cancelAllTracks()
	if self.currentMovementTrack then
		self.currentMovementTrack:Stop(0)
		self.currentMovementTrack = nil
	end

	self.moveSetTracks.idle:Stop()
end

function moveSetAnimator:handleFootstep()
	local now = os.clock()

	if self.lastFootstepTime and (now - self.lastFootstepTime) < self.minFootstepInterval then
		return
	end

	self.lastFootstepTime = now

	local materialName = footstepMaterialMap[self.humanoid.FloorMaterial] or "Grass"
	local materialFolder = philFootstepSounds:FindFirstChild(materialName) or philFootstepSounds.Grass

	if not materialFolder then
		return
	end

	local newSound: Sound? = audioUtilities.fetchLeastUsedSound({
		dictionary = materialFolder:GetChildren(),
		history = self.footstepSoundHistory,
	})

	if not newSound then
		return
	end

	audioUtilities.playSound({
		sound = newSound,
		volume = 1,
		parent = self.rootPart,
		useAcousticSimulation = false,
	})

end

function moveSetAnimator:update()
	local agent = self.agent
	local rootPart = self.rootPart
	local humanoid = self.humanoid
	local moveSetTracks = self.moveSetTracks
	local sharedConfig = self.sharedConfig

	local velocity = rootPart:GetVelocityAtPosition(rootPart.Position)
	local isMoving = vector.magnitude(velocity) >= sharedConfig.minimumMoveVelocity
	local canAnimate = not agent:GetAttribute("MidAction") and not self.controller:isInactive()

	if not canAnimate then
		self:cancelAllTracks()
		return
	end

	local walkSpeeds = sharedConfig.walkSpeeds
	local currentSpeed = humanoid.WalkSpeed
	local isRunning = currentSpeed >= walkSpeeds.run - 1

	self:setTrackPlaying(moveSetTracks.idle, not isMoving)

	if isMoving then
		local localVelocity = self:getMoveDirection(rootPart, velocity)
		local direction = self:getMoveState(localVelocity)
		local group = isRunning and moveSetTracks.run or moveSetTracks.walk
		local desiredTrack = group[direction]

		if
			(isRunning and direction == "forward" and self.agent:GetAttribute("NearTarget"))
			and group.nearTargetForward
		then
			desiredTrack = group.nearTargetForward
		end

		if
			(not isRunning and direction == "forward" and self.agent:GetAttribute("Searching")) and group.searchForward
		then
			desiredTrack = group.searchForward
		end

		if self.currentMovementTrack ~= desiredTrack then
			if self.currentMovementTrack then
				self.currentMovementTrack:Stop(0)
			end

			if desiredTrack then
				desiredTrack:Play(0)
			end

			self.currentMovementTrack = desiredTrack
		end

		local base = isRunning and walkSpeeds.run or walkSpeeds.idle
		local scale = base > 0 and (currentSpeed / base) or 1

		for _, track in pairs(group) do
			if track and track.AdjustSpeed then
				track:AdjustSpeed(scale)
			end
		end
	else
		if self.currentMovementTrack then
			self.currentMovementTrack:Stop()
			self.currentMovementTrack = nil
		end

		self:setTrackPlaying(moveSetTracks.idle, true)
	end
end

function moveSetAnimator:inititalize()
	for tableName, trackTable in self.moveSetTracks do
		if typeof(trackTable) ~= "table" then
			continue
		end

		for trackName, track in trackTable do
			self.connections[tableName .. "_" .. trackName .. "_Step"] = track
				:GetMarkerReachedSignal("Step")
				:Connect(function()
					self:handleFootstep()
				end)
		end
	end
end

function moveSetAnimator.new(controller: {
	agent: Model,
	rootPart: BasePart,
	humanoid: Humanoid,
	tracks: any,
	config: any,
	[string]: any,
})
	local self = setmetatable({}, moveSetAnimator)

	self.controller = controller
	self.connections = {}
	self.agent = controller.agent
	self.rootPart = controller.rootPart
	self.humanoid = controller.humanoid
	self.moveSetTracks = controller.tracks.moveSet
	self.sharedConfig = controller.config.shared
	self.footstepSoundHistory = audioUtilities.createSoundUsageHistory()

	task.spawn(self.inititalize, self)

	return self
end

function moveSetAnimator:destroy()
	self:cancelAllTracks()

	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end
end

return moveSetAnimator
