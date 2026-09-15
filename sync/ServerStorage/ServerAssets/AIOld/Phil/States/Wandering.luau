local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")

local serverAssets = serverStorage.ServerAssets
local playerMemoryController = require(serverAssets.PlayerMemory)

local bucketUtilities = require(replicatedStorage.SharedUtilities.BucketUtils)
local noiseDetection = require(serverAssets.AI.NoiseDetection)

local baseState = require(serverStorage.ServerAssets.AI.BaseState)
local wanderingState = baseState.extend("Wandering")

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = { workspace.Ignore }
raycastParams.CollisionGroup = "Reposition"

function wanderingState:enter()
	local speedController = self.controller.speedController
	speedController:clearAll()
	speedController:setLock("wandering", true)

	self.controller.targeting:clearTargetCache()

	self.controller:setOrientationEnabled(false)
	self.controller:setFlag("hasScreamedThisChase", false)
	self.agent:SetAttribute("Chasing", false)
	self.lastTargetSeenTime = os.clock()
	self.isInvestigatingUrgentSound = false

	self.connections.onFinished = self.pathfinder.Reached:Connect(function()
		if self.isRedirecting then
			return
		end

		if self.isInvestigatingUrgentSound then
			self.isInvestigatingUrgentSound = false
		end

		if self.lastTrack then
			self.lastTrack:Stop()
			self.lastTrack = nil
		end

		self.lastTrack = self.isInvestigatingUrgentSound and self.aggressiveSearchTrack or self.casualSearchTrack

		self:_playSearchAnimation(self.lastTrack, function()
			if not self.isRedirecting then
				self:beginWanderPath()
			end
		end)
	end)

	self.connections.onError = self.pathfinder.Error:Connect(function()
		if self.isRedirecting then
			return
		end

		self:beginWanderPath()
	end)

	self.noiseDetection:connect()
	self:beginWanderPath()
end

function wanderingState:exit()
	self.controller.speedController:clearLock("wandering")
	self.isInvestigatingUrgentSound = false

	if self.connections.onError then
		self.connections.onError:Disconnect()
		self.connections.onError = nil
	end

	if self.connections.onFinished then
		self.connections.onFinished:Disconnect()
		self.connections.onFinished = nil
	end

	if self.lastTrack then
		self.lastTrack:Stop()
		self.lastTrack = nil
	end

	self.noiseDetection:disconnect()
end

function wanderingState:_playSearchAnimation(track, onComplete)
	if not track then
		onComplete()
		return
	end

	track:Play()

	self.connections.onSearchTrackEnded = track.Stopped:Once(function()
		if self.connections.onSearchTrackEnded then
			self.connections.onSearchTrackEnded:Disconnect()
			self.connections.onSearchTrackEnded = nil
		end

		onComplete()
	end)
end

function wanderingState:canAcquireTarget(target)
	if not target then
		return false
	end

	local controller = self.controller
	local sharedConfig = self.config.shared

	local timeSinceLastChaseActivity = os.clock() - controller:getActionTime("chase")
	local isWithinChaseRecoveryGrace = timeSinceLastChaseActivity < self.searchRecoverySeconds

	if isWithinChaseRecoveryGrace then
		local isInFieldOfView = controller.targeting:isTargetInFieldOfView(target, sharedConfig.detectionFov)

		if not isInFieldOfView then
			return false
		end

		return controller.targeting:isTargetVisible(target)
	end

	return true
end

function wanderingState:beginWanderPath()
	local timeSinceChase = os.clock() - self.controller:getActionTime("chase")
	local hasRecentChaseExpired = timeSinceChase > self.config.wandering.trackTargetCooldownSeconds

	local nearestTarget = self.controller.targeting:getNearestTarget({
		range = 10000,
		canRaycast = false,
	})

	local buildings = playerMemoryController:getAllBuildings()
	local buildingCandidates = {}

	for _, building in buildings do
		if building.name ~= self.previousBuilding then
			table.insert(buildingCandidates, building)
		end
	end

	local chosenBuilding = (#buildingCandidates > 0) and buildingCandidates[math.random(1, #buildingCandidates)]
		or buildings[math.random(1, #buildings)]

	-- use the same floor-mapped room source Searching uses, instead of chosenBuilding.rooms
	local availableRooms = playerMemoryController:getBuildingRooms(chosenBuilding.name)
	local roomCandidates = {}

	for _, room in availableRooms do
		if room ~= self.previousRoom then
			table.insert(roomCandidates, room)
		end
	end

	local chosenRoom = (#roomCandidates > 0) and roomCandidates[math.random(1, #roomCandidates)]
		or availableRooms[math.random(1, #availableRooms)]

	local shouldWanderToRoom = not hasRecentChaseExpired or not nearestTarget or math.random(1, 5) ~= 1

	if shouldWanderToRoom then
		local floorParts = playerMemoryController:getRoomFloorParts(chosenBuilding.name, chosenRoom.Name)
		local goalPart = (floorParts and floorParts[math.random(1, #floorParts)]) or chosenRoom

		self.currentGoal = bucketUtilities.getRandomPositionInPart(goalPart) + Vector3.yAxis * 1.5
		self.previousBuilding = chosenBuilding.name
		self.previousRoom = chosenRoom
	else
		self.currentGoal = nearestTarget.root.Position
	end

	self.pathfinder:Run(self.currentGoal)
end

function wanderingState:_onNoiseDetected(eventInfo, detector)
	local buildingToSearch = self.controller:isGoalInBuilding(detector.lastKnownPosition)

	if buildingToSearch then
		self.controller.stateMachine:change(self.controller.states.Searching, {
			lastKnownPosition = detector.lastKnownPosition,
			buildingToSearch = buildingToSearch,
		})
		return
	end

	if eventInfo.priority >= 2 then
		self.isInvestigatingUrgentSound = true
	end

	self.isRedirecting = true
	self.currentGoal = detector.lastKnownPosition
	self.pathfinder:Run(self.currentGoal)
	self.isRedirecting = false
end

function wanderingState:update(_deltaTime: number)
	local controller = self.controller
	local sharedConfig = self.config.shared

	local rangesConfig = sharedConfig.ranges
	local walkSpeeds = sharedConfig.walkSpeeds

	local nearestTarget = controller.targeting:getNearestTarget({
		range = sharedConfig.ranges.walk,
		canRaycast = false,
	})

	if self:canAcquireTarget(nearestTarget) then
		controller.stateMachine:change(controller.states.Walking)
		return
	end

	if os.clock() - self.lastTargetSeenTime >= 75 then
		controller.stateMachine:change(controller.states.Transporting, {
			transportType = "fastTravelEnter",
		})

		return
	end

	if self.currentGoal then
		self.distanceToGoal = vector.magnitude(self.rootPart.Position - self.currentGoal)
	end

	local shouldRun = self.isInvestigatingUrgentSound
		or (self.distanceToGoal and self.distanceToGoal > rangesConfig.strafeFar)

	self.humanoid.WalkSpeed = shouldRun and walkSpeeds.run or walkSpeeds.idle
end

function wanderingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(wanderingState, controller, extraInfo)

	self.allRooms = playerMemoryController:getAllBuildingRooms()
	self.searchRecoverySeconds = self.config.wandering.searchRecoverySeconds or 12
	self.isInvestigatingUrgentSound = false

	self.searchTracks = self.tracks.search
	self.casualSearchTrack = self.searchTracks.casual
	self.aggressiveSearchTrack = self.searchTracks.aggressive

	self.noiseDetection = noiseDetection.new({
		rootPart = self.rootPart,
		cooldownSeconds = self.config.wandering.noiseSoundReactionCooldown or 2,
		minPriority = self.config.wandering.noiseReactionPriority or 0,
		onDetect = function(eventInfo, detector)
			self:_onNoiseDetected(eventInfo, detector)
		end,
	})

	return self
end

return wanderingState
