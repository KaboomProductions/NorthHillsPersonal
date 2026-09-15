local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedUtilities = replicatedStorage.SharedUtilities
local bucketUtilities = require(sharedUtilities.BucketUtils)

local serverAssets = serverStorage.ServerAssets
local playerMemoryController = require(serverAssets.PlayerMemory)
local noiseDetection = require(serverAssets.AI.StateMachine.NoiseDetection)

local baseState = require(serverAssets.AI.StateMachine.StateMachine.BaseState)
local searchingState = baseState.extend("Searching")

local function findGroundedPoint(candidate: Vector3, raycastParams: RaycastParams)
	local origin = candidate + Vector3.new(0, 15, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -30, 0), raycastParams)

	if not result then
		return nil
	end

	if result.Normal.Y < 0.7 then
		return nil
	end

	return result.Position + Vector3.new(0, 0.1, 0)
end

local function isPointClear(point: Vector3, overlapParams: OverlapParams)
	local size = Vector3.new(3, 5, 3)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(point), size, overlapParams)

	for _, part in parts do
		if part.CanCollide then
			return false
		end
	end

	return true
end

function searchingState:_scoreRoom(room, expectedDistance, sigma)
	local toRoom = room.Position - self.lastKnownPosition
	local distance = vector.magnitude(toRoom)

	local distanceDelta = distance - expectedDistance
	local distanceScore = math.exp(-(distanceDelta * distanceDelta) / (2 * sigma * sigma))
	local directionScore = 1

	if distance > 0.01 and self.lastKnownDirection then
		local alignment = toRoom.Unit:Dot(self.lastKnownDirection)
		directionScore = 0.35 + 0.65 * ((alignment + 1) / 2)
	end

	local recencyScore = 1
	local lastSearchedAt = self.recentlySearched[room]

	if lastSearchedAt then
		local sinceSearched = os.clock() - lastSearchedAt
		recencyScore = math.clamp(sinceSearched / 15, 0.1, 1)
	end

	local memoryWeight = 1
	if self.priorTarget then
		memoryWeight = playerMemoryController:getRoomWeight(self.priorTarget, self.buildingToSearch, room.Name)
	end

	return distanceScore * directionScore * recencyScore * memoryWeight
end

function searchingState:_weightedRandomPick(weighted)
	local totalWeight = 0
	for _, entry in weighted do
		totalWeight = totalWeight + entry.weight
	end

	if totalWeight <= 0 then
		return weighted[math.random(1, #weighted)]
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, entry in weighted do
		cumulative = cumulative + entry.weight

		if roll <= cumulative then
			return entry
		end
	end

	return weighted[#weighted]
end

function searchingState:_getBuildingAt(position)
	if not position then
		return nil
	end

	return self.controller:isGoalInBuilding(position) or nil
end

function searchingState:_chooseRoom()
	if #self.allRooms == 0 then
		return nil
	end

	local containingRoom = self:_findContainingRoom()
	if containingRoom and (self.roomSearchCounts[containingRoom] or 0) == 0 then
		return containingRoom
	end

	local elapsed = os.clock() - self.searchStartTime
	local assumedSpeed = self.config.shared.searchAssumedPlayerSpeed or 16

	local rawExpectedDistance = assumedSpeed * elapsed
	local expectedDistance = math.min(rawExpectedDistance, self.maxRoomDistance)

	local baseSigma = self.config.shared.searchDistanceSigma or 25
	local sigmaGrowthPerSecond = self.config.shared.searchSigmaGrowth or 4
	local sigma = baseSigma + sigmaGrowthPerSecond * elapsed

	local unsearched = {}
	local searched = {}

	for _, room in self.allRooms do
		local weight

		if self.lastKnownPosition then
			weight = self:_scoreRoom(room, expectedDistance, sigma)
		else
			weight = 1
		end

		local searchCount = self.roomSearchCounts[room] or 0

		local entry = {
			room = room,
			weight = weight,
		}

		if searchCount == 0 then
			table.insert(unsearched, entry)
		else
			table.insert(searched, entry)
		end
	end

	if #unsearched > 0 then
		local picked = self:_weightedRandomPick(unsearched)
		return picked and picked.room
	end

	if self.revisitCount >= self.maxRevisits then
		return nil
	end

	local picked = self:_weightedRandomPick(searched)
	if picked then
		self.revisitCount = self.revisitCount + 1
		return picked.room
	end

	return nil
end

function searchingState:_findContainingRoom()
	if not self.lastKnownPosition then
		return nil
	end

	for _, room in self.allRooms do
		if bucketUtilities.checkInRegion(room, self.lastKnownPosition) then
			return room
		end
	end

	return nil
end

function searchingState:_playSearchAnimation(onComplete)
	self.searchTrack:Play()

	self.connections.onSearchTrackEnded = self.searchTrack.Stopped:Once(function()
		if self.connections.onSearchTrackEnded then
			self.connections.onSearchTrackEnded:Disconnect()
			self.connections.onSearchTrackEnded = nil
		end

		onComplete()
	end)
end

function searchingState:_updateOutdoorGoal()
	local baseRadius = self.config.shared.outdoorSearchBaseRadius or 15
	local radiusStep = self.config.shared.outdoorSearchRadiusStep or 10

	local minRadius = baseRadius + (self.outdoorLegsCompleted * radiusStep)
	local maxRadius = minRadius + radiusStep

	local point = self:_pickOutdoorSearchPoint(self.searchOrigin, minRadius, maxRadius)
		or self:_pickOutdoorSearchPoint(self.searchOrigin, baseRadius, maxRadius + radiusStep)

	if not point then
		self.outdoorConsecutiveFailures += 1

		if self.outdoorConsecutiveFailures >= (self.config.shared.outdoorSearchMaxFailures or 3) then
			self:_stopSearching("noValidOutdoorPointsFound")
		else
			task.defer(function()
				if not self.searchEnding then
					self:_updateGoal()
				end
			end)
		end

		return
	end

	self.outdoorConsecutiveFailures = 0
	self.outdoorLegsCompleted += 1
	self.totalOutdoorLegsAttempted += 1
	self.currentGoal = point
	self.pathfinder:Run(self.currentGoal)
end

function searchingState:_reconcileSearchContext(newPosition)
	local detectedBuilding = self:_getBuildingAt(newPosition)

	if detectedBuilding ~= self.pendingContextBuilding then
		self.pendingContextBuilding = detectedBuilding
		self.pendingContextStreak = 1
		return
	end

	self.pendingContextStreak = (self.pendingContextStreak or 0) + 1

	if self.pendingContextStreak < 2 then
		return
	end

	if detectedBuilding == self.buildingToSearch then
		return
	end

	self:_setSearchContext(detectedBuilding)
end

function searchingState:_setSearchContext(newBuildingToSearch)
	self.buildingToSearch = newBuildingToSearch
	self.isOutdoorSearch = not newBuildingToSearch

	if self.isOutdoorSearch then
		self.allRooms = {}
		self.outdoorLegsCompleted = 0
		self.outdoorConsecutiveFailures = 0
		self.searchOrigin = self.lastKnownPosition
	else
		self.allRooms = playerMemoryController:getBuildingRooms(self.buildingToSearch)
		self.maxRoomDistance = 1

		if self.lastKnownPosition then
			for _, room in self.allRooms do
				self.maxRoomDistance =
					math.max(self.maxRoomDistance, vector.magnitude(room.Position - self.lastKnownPosition))
			end
		end

		self.roomSearchCounts = {}
		self.recentlySearched = {}
		self.uniqueRoomsSearched = 0
		self.revisitCount = 0
	end

	self.pendingRoom = nil
end

function searchingState:_creditRoomSearched(room)
	local previousSearchCount = self.roomSearchCounts[room] or 0

	if previousSearchCount == 0 then
		self.uniqueRoomsSearched = self.uniqueRoomsSearched + 1
	end

	self.roomSearchCounts[room] = previousSearchCount + 1
	self.recentlySearched[room] = os.clock()
end

function searchingState:_updateGoal()
	if self.searchEnding then
		return
	end

	local shouldStop, reason = self:_shouldStopSearching()
	if shouldStop then
		self:_stopSearching(reason)
		return
	end

	if self.isOutdoorSearch then
		self:_updateOutdoorGoal()
		return
	end

	local chosenRoom = self:_chooseRoom()
	if not chosenRoom then
		self:_stopSearching("noValidRoomsRemaining")
		return
	end

	self.pendingRoom = chosenRoom

	local floorParts = playerMemoryController:getRoomFloorParts(self.buildingToSearch, chosenRoom.Name)
	local goalPart = (floorParts and floorParts[math.random(1, #floorParts)]) or chosenRoom

	self.currentGoal = bucketUtilities.getRandomPositionInPart(goalPart) + Vector3.yAxis * 1.5
	self.pathfinder:Run(self.currentGoal)
end

function searchingState:handleTrapped()
	if not self.controller:isActionReady("flashstep", self.config.shared.flashstepCooldownSeconds or 1) then
		return false
	end

	self.controller:recordActionTime("flashstep")

	local lookVector = self.rootPart.CFrame.LookVector
	self.agent:PivotTo(CFrame.new(self.currentGoal, self.currentGoal + lookVector))

	self.pathfinder:Run(self.currentGoal)

	return true
end

function searchingState:_shouldStopSearching()
	local elapsed = os.clock() - self.searchStartTime

	if elapsed >= self.maxSearchDuration then
		return true, "timedOut"
	end

	if elapsed < self.minimumSearchDuration then
		return false
	end

	if self.pathFailureCount >= self.maxPathFailures then
		return true, "tooManyPathFailures"
	end

	if self.isOutdoorSearch then
		local maxLegs = self.config.shared.outdoorSearchMaxLegs or 12

		if self.totalOutdoorLegsAttempted >= maxLegs then
			return true, "outdoorLegsExhausted"
		end

		return false
	end

	local roomCount = #self.allRooms
	if roomCount == 0 then
		return true, "noRooms"
	end

	local coverage = self.uniqueRoomsSearched / roomCount
	if coverage >= self.requiredCoverage then
		return true, "coverageComplete"
	end

	if self.uniqueRoomsSearched >= roomCount then
		return true, "allRoomsSearched"
	end

	return false
end

function searchingState:_onNoiseDetected(eventInfo, detector)
	if self.searchEnding then
		return
	end

	self.lastKnownPosition = detector.lastKnownPosition
	self.lastKnownDirection = detector.lastKnownDirection

	self:_reconcileSearchContext(self.lastKnownPosition)

	if self.investigatePosition then
		self.investigatePosition = nil
	end

	self.pendingRoom = nil

	local extension = self.config.shared.searchSoundExtensionSeconds or 8
	self.maxSearchDuration = math.max(self.maxSearchDuration, (os.clock() - self.searchStartTime) + extension)

	if self.isOutdoorSearch then
		self.searchOrigin = self.lastKnownPosition
		self.outdoorLegsCompleted = 0
	else
		self.maxRoomDistance = 1
		for _, room in self.allRooms do
			self.maxRoomDistance =
				math.max(self.maxRoomDistance, vector.magnitude(room.Position - self.lastKnownPosition))
		end
	end

	self.investigatePosition = self.lastKnownPosition
	self.currentGoal = self.investigatePosition
	self.pathfinder:Run(self.currentGoal)

	if eventInfo.priority >= 2 then
		local walkSpeeds = self.config.shared.walkSpeeds
		self.controller.speedController:setModifier("running", walkSpeeds.run - walkSpeeds.idle)
		self.isInvestigatingUrgentSound = true
	end
end

function searchingState:_pickOutdoorSearchPoint(center: Vector3, minRadius: number, maxRadius: number)
	local raycastParams = self.controller.targeting.visibilityRaycastParams

	for _ = 1, 12 do
		local angle = math.random() * math.pi * 2
		local radius = math.random() * (maxRadius - minRadius) + minRadius
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local candidate = center + offset

		local grounded = findGroundedPoint(candidate, raycastParams)
		if grounded and isPointClear(grounded + Vector3.new(0, 3, 0), self.outdoorOverlapParams) then
			local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
			local distance = horizontalOffset.Magnitude

			if distance <= 0.1 then
				return grounded
			end

			local blocked = workspace:Raycast(center + Vector3.new(0, 2, 0), horizontalOffset, raycastParams)
			if not blocked or blocked.Distance >= distance - 3 then
				return grounded
			end
		end
	end

	return nil
end

function searchingState:enter()
	local speedController = self.controller.speedController
	local walkSpeeds = self.config.shared.walkSpeeds

	speedController:clearAll()
	speedController:setModifier("running", walkSpeeds.run - walkSpeeds.idle)

	self.controller:setOrientationEnabled(false)
	self.controller:toggleIKControl(false)

	self.rootPart:AddTag("InterfereWithLights")
	self.agent:SetAttribute("Searching", true)

	self.connections.onFinished = self.pathfinder.Reached:Connect(function()
		if self.searchEnding then
			return
		end

		self.pathFailureCount = 0

		if self.investigatePosition then
			self.investigatePosition = nil

			if self.isInvestigatingUrgentSound then
				self.isInvestigatingUrgentSound = false

				if not self.isOutdoorSearch then
					self.controller.speedController:clearAll()
				end
			end
		elseif self.pendingRoom then
			self:_creditRoomSearched(self.pendingRoom)
			self.pendingRoom = nil
		end

		self:_playSearchAnimation(function()
			if not self.searchEnding then
				self:_updateGoal()
			end
		end)
	end)

	self.connections.onError = self.pathfinder.Error:Connect(function()
		if self.searchEnding then
			return
		end

		self.pathFailureCount = self.pathFailureCount + 1
		self.pendingRoom = nil

		task.defer(function()
			if not self.searchEnding then
				self:_updateGoal()
			end
		end)
	end)

	self.connections.onTrapped = self.pathfinder.Trapped:Connect(function()
		if self.searchEnding then
			return
		end

		if self:handleTrapped() then
			return
		end

		self.pathFailureCount = self.pathFailureCount + 1

		task.defer(function()
			if not self.searchEnding then
				self:_updateGoal()
			end
		end)
	end)

	self.noiseDetection:connect()
end

function searchingState:exit()
	self.agent:SetAttribute("Searching", false)
	self.rootPart:RemoveTag("InterfereWithLights")
	self.searchTrack:Stop()
	self.noiseDetection:disconnect()
end

function searchingState:_stopSearching(reason)
	if self.searchEnding then
		return
	end

	self.searchEnding = true

	if self.isOutdoorSearch then
		print(
			("stopped searching (outdoor): %s | %.1fs | %d legs"):format(
				reason or "unknown",
				os.clock() - self.searchStartTime,
				self.outdoorLegsCompleted
			)
		)
	else
		print(
			("stopped searching: %s | %.1fs | %d/%d rooms"):format(
				reason or "unknown",
				os.clock() - self.searchStartTime,
				self.uniqueRoomsSearched,
				#self.allRooms
			)
		)
	end

	self.controller.stateMachine:change(self.controller.states.Wandering)
end

function searchingState:update(deltaTime: number)
	local controller = self.controller
	local sharedConfig = self.config.shared

	if self.searchEnding then
		return
	end

	local sightHeld = false
	local nearestTarget = controller.targeting:getNearestTarget({
		range = sharedConfig.ranges.run,
		useTargetCache = true,
	})

	if not self.isOutdoorSearch and self.uniqueRoomsSearched >= 2 and not self.isSoftSearching then
		self.isSoftSearching = true
		controller.speedController:clearAll()
	end

	controller:recordActionTime("chase")
	controller:toggleIKControl(false)

	if nearestTarget then
		local distanceToTarget = vector.magnitude(self.rootPart.Position - nearestTarget.root.Position)
		local closeRangeRadius = sharedConfig.ranges.searchCloseRangeDetection or sharedConfig.ranges.nearTarget or 8

		local isCloseRangeOmniscient = distanceToTarget <= closeRangeRadius
		local reacquireDelay = sharedConfig.searchReacquireDelay or 0.8

		local inFieldOfView = isCloseRangeOmniscient
			or controller.targeting:isTargetInFieldOfView(nearestTarget, sharedConfig.detectionFov * 1.5)

		local canSeeTarget = inFieldOfView and controller.targeting:isTargetVisible(nearestTarget)

		if canSeeTarget then
			self.sightConfirmTime = (self.sightConfirmTime or 0) + deltaTime
		else
			self.sightConfirmTime = 0
		end

		if isCloseRangeOmniscient then
			reacquireDelay = sharedConfig.searchCloseRangeReacquireDelay or 0.1
		end

		sightHeld = self.sightConfirmTime >= reacquireDelay

		if sightHeld then
			self.searchEnding = true

			controller.stateMachine:change(controller.states.Running, {
				priorTarget = nearestTarget,
				hasScreamedThisChase = controller:getFlag("hasScreamedThisChase"),
				lastKnownPosition = nearestTarget.root.Position,
				lastKnownVelocity = nearestTarget.root.AssemblyLinearVelocity,
				searchReacquireGraceEndTime = os.clock() + (sharedConfig.searchReacquireGraceDuration or 1),
			})

			return
		end

		if canSeeTarget then
			controller:turnToward(nearestTarget.root.Position)
			self.isHoldingSight = true
			return
		end
	end

	self.isHoldingSight = false

	local shouldStop, reason = self:_shouldStopSearching()

	if shouldStop then
		self:_stopSearching(reason)
		return
	end

	if not self.currentGoal then
		self:_updateGoal()
	end
end

function searchingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(searchingState, controller, extraInfo)

	local searchingConfig = self.config.searching
	local safeExtraInfo = extraInfo or {}

	self.priorTarget = safeExtraInfo.priorTarget
	self.buildingToSearch = safeExtraInfo.buildingToSearch

	self.lastKnownPosition = safeExtraInfo.lastKnownPosition

	local rawVelocity = safeExtraInfo.lastKnownVelocity
	self.lastKnownVelocity = rawVelocity and Vector3.new(rawVelocity.X, rawVelocity.Y, rawVelocity.Z) or nil
	self.lastKnownDirection = (self.lastKnownVelocity and vector.magnitude(self.lastKnownVelocity) > 0.01)
			and self.lastKnownVelocity.Unit
		or nil

	self.searchStartTime = os.clock()
	self.searchEnding = false
	self.searchTrack = self.tracks.search.aggressive

	self.recentlySearched = {}
	self.roomSearchCounts = {}

	self.investigatePosition = nil
	self.isInvestigatingUrgentSound = false
	self.pendingRoom = nil

	self.uniqueRoomsSearched = 0
	self.revisitCount = 0
	self.pathFailureCount = 0

	self.minimumSearchBeforeReacquire = searchingConfig.minimumSearchBeforeReacquire or 2.5
	self.maxSearchDuration = searchingConfig.searchMaxDuration or 35
	self.minimumSearchDuration = searchingConfig.searchMinimumDuration or 8
	self.requiredCoverage = searchingConfig.searchCoverageRequired or 0.75
	self.maxRevisits = searchingConfig.searchMaxRevisits or 2
	self.maxPathFailures = searchingConfig.searchFailureLimit or 5

	self.isOutdoorSearch = not self.buildingToSearch
	self.outdoorLegsCompleted = 0
	self.outdoorConsecutiveFailures = 0
	self.totalOutdoorLegsAttempted = 0

	if self.isOutdoorSearch then
		self.allRooms = {}
		self.outdoorOverlapParams = OverlapParams.new()
		self.outdoorOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
		self.outdoorOverlapParams.FilterDescendantsInstances = { self.agent }
	else
		self.allRooms = playerMemoryController:getBuildingRooms(self.buildingToSearch)
		self.maxRoomDistance = 1

		if self.lastKnownPosition then
			for _, room in self.allRooms do
				local distance = vector.magnitude(room.Position - self.lastKnownPosition)
				self.maxRoomDistance = math.max(self.maxRoomDistance, distance)
			end
		end
	end

	self.searchOrigin = self.lastKnownPosition

	self.noiseDetection = noiseDetection.new({
		rootPart = self.rootPart,
		cooldownSeconds = self.config.shared.searchSoundReactionCooldown or 1.5,
		onDetect = function(eventInfo, detector)
			self:_onNoiseDetected(eventInfo, detector)
		end,
	})

	return self
end

return searchingState
