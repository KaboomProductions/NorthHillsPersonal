local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtilities = require(replicatedStorage.SharedUtilities.ItemUtils)

local baseState = require(serverStorage.ServerAssets.AI.StateMachine.StateMachine.BaseState)
local runningState = baseState.extend("Running")

local function isTargetCharging(targetAgent)
	local tool = itemUtilities.checkForTool(targetAgent)
	return tool ~= nil and tool:GetAttribute("Charging") == true
end

function runningState:updateOrbitOrientation()
	local now = os.clock()

	if now >= self.nextOrientationToggle then
		self.orientationEnabled = not self.orientationEnabled
		self.nextOrientationToggle = now + math.random(2, 3)

		self.controller:setOrientationEnabled(self.orientationEnabled)
	end
end

function runningState:updateOrbitDirection()
	local now = os.clock()

	if now >= self.nextOrbitFlip then
		self.orbitDirection = self.orbitDirection * -1
		self.nextOrbitFlip = now + math.random(2, 5)
	end
end

function runningState:updateStrafeJitter()
	local now = os.clock()

	if now >= (self.nextStrafeJitterTime or 0) then
		self.strafeJitterOffset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
		self.nextStrafeJitterTime = now + math.random(0.4, 0.7)
	end
end

function runningState:handleMovement(nearestTarget, deltaTime)
	local now = os.clock()

	local controller = self.controller
	local sharedConfig = self.config.shared
	local combatConfig = self.config.combat

	local targetRoot = nearestTarget.root
	local targetAgent = nearestTarget.agent
	local isCrowdControl = self.agent:GetAttribute("CrowdControl")

	local selfPosition = self.rootPart.Position
	local targetPosition = targetRoot.Position

	local offset = selfPosition - targetPosition
	local distance = vector.magnitude(offset)

	local tool = itemUtilities.checkForTool(targetAgent)
	local isCharging = tool and tool:GetAttribute("Charging")
	local chargeStrength = (tool and tool:GetAttribute("ChargeStrength")) or 0

	self.distanceStruggleTime = (distance >= sharedConfig.ranges.strafeClose)
			and (self.distanceStruggleTime or 0) + deltaTime
		or 0

	local shouldAvoidTarget = not self.isRushing
		and distance <= sharedConfig.ranges.strafeClose + 10
		and isCharging
		and not isCrowdControl

	self.isStrafing = shouldAvoidTarget

	if self.isStrafing and self.distanceStruggleTime >= (combatConfig.forcedRushStruggleTime or 4) then
		if controller:isActionReady("rush", combatConfig.rushCooldownSeconds) then
			self.isRushing = true
			self.rushEndTime = now + combatConfig.rushDuration

			controller:recordActionTime("rush")

			controller.speedController:setModifier(
				"rushing",
				combatConfig.rushSpeedBonus or (self.config.shared.walkSpeeds.run * 0.5)
			)

			self.distanceStruggleTime = 0
		end
	end

	if shouldAvoidTarget then
		self:updateOrbitOrientation()
		self:updateOrbitDirection()
		self:updateStrafeJitter()

		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		local flatDistance = vector.magnitude(flatOffset)

		if flatDistance <= 0.001 then
			return true
		end

		local awayDirection = flatOffset.Unit
		local tangentDirection = Vector3.new(-awayDirection.Z, 0, awayDirection.X) * self.orbitDirection
		local radiusError = flatDistance - sharedConfig.ranges.strafeClose

		local correction = -awayDirection * radiusError * 0.15
		local moveDirection = (tangentDirection + correction).Unit
		local randomOffset = Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))

		local horizontalOffset = Vector3.new(moveDirection.X, 0, moveDirection.Z) * 12
			+ Vector3.new(randomOffset.X, 0, randomOffset.Z)
		local horizontalDistance = horizontalOffset.Magnitude

		if horizontalDistance > 0.001 then
			local castDirection = horizontalOffset.Unit
			local visibilityParams = controller.targeting.visibilityRaycastParams
			local obstruction =
				workspace:Raycast(selfPosition, castDirection * (horizontalDistance + 3), visibilityParams)

			if obstruction then
				local clampedDistance = math.clamp(obstruction.Distance - 3, 2, horizontalDistance)
				horizontalOffset = castDirection * clampedDistance
			end
		end

		if chargeStrength > 0.75 and controller:isActionReady("rush", combatConfig.rushCooldownSeconds) then
			if math.random() <= combatConfig.rushChance then
				self.isRushing = true
				self.rushEndTime = now + combatConfig.rushDuration

				controller:recordActionTime("rush")

				self.controller.speedController:setModifier(
					"rushing",
					combatConfig.rushSpeedBonus or (self.config.shared.walkSpeeds.run * 0.5)
				)
			end
		end

		local destination = selfPosition + Vector3.new(horizontalOffset.X, randomOffset.Y, horizontalOffset.Z)

		controller:traverse(destination)
		controller:turnToward(targetPosition)

		return true
	end

	if self.orientationEnabled and not self.agent:GetAttribute("CrowdControl") then
		self.orientationEnabled = false
		self.controller:setOrientationEnabled(false)
	end

	return false
end

function runningState:enter()
	local extraInfo = self.extraInfo
	local speedController = self.controller.speedController
	local walkSpeeds = self.config.shared.walkSpeeds

	speedController:clearAll()
	speedController:setModifier("running", walkSpeeds.run - walkSpeeds.idle)

	self.agent:SetAttribute("Sneaking", false)
	self.agent:SetAttribute("Lunging", false)
	self.agent:SetAttribute("Screaming", false)
	self.agent:SetAttribute("Chasing", true)
	self.rootPart:AddTag("InterfereWithLights")

	self.controller:setOrientationEnabled(false)

	if extraInfo and extraInfo.hasScreamedThisChase ~= nil then
		self.controller:setFlag("hasScreamedThisChase", extraInfo.hasScreamedThisChase)
	end

	self.lastTarget = extraInfo and extraInfo.priorTarget or nil
	self.lastKnownPosition = extraInfo and extraInfo.lastKnownPosition or nil
	self.lastKnownInBuilding = extraInfo and extraInfo.lastKnownInBuilding or false

	self.trackedPosition = self.lastKnownPosition
	self.trackedInBuilding = self.lastKnownInBuilding
	self.buildingEntryUnseenTimer = 0
	self.buildingEntrySearchDelay = self.config.shared.buildingEntrySearchDelay or 1.5

	self.searchReacquireGraceDuration = self.config.shared.searchReacquireGraceDuration or 1
	self.searchReacquireGraceEndTime = extraInfo and extraInfo.searchReacquireGraceEndTime or 0

	self.lastSeenTime = os.clock()
	self.visibilityGraceDuration = 2.5

	self.lastLostTargetPosition = nil
	self.lostTargetPursuitStart = nil
	self.lastDistanceToKnownPosition = nil
	self.stalledPursuitTime = 0

	self.maxLostTargetPursuitTime = 3
	self.stalledPursuitThreshold = 0.15
	self.maxStalledPursuitTime = 1

	self.pursuitTimeBuffer = self.config.shared.lostTargetPursuitBuffer or 1.5
	self.pursuitSpeedEstimate = walkSpeeds.run or 16

	self.stallCheckInterval = self.config.shared.stallCheckInterval or 0.5
	self.nextStallCheck = 0
	self.distanceAtLastStallCheck = nil

	self.orbitDirection = math.random() <= 0.5 and -1 or 1
	self.nextOrbitFlip = 0
	self.orientationEnabled = false
	self.nextOrientationToggle = 0

	self.isRushing = false
	self.rushEndTime = 0
	self.isStrafing = false
end

function runningState:exit()
	self.agent:SetAttribute("NearTarget", false)
	self.rootPart:RemoveTag("InterfereWithLights")

	self.controller.speedController:clearModifier("rushing")
	self.controller:toggleIKControl(false)
end

function runningState:update(deltaTime: number)
	local controller = self.controller
	local sharedConfig = self.config.shared
	local combatConfig = self.config.combat

	local nearestTarget = controller.targeting:getNearestTarget({
		range = sharedConfig.ranges.run,
		useTargetCache = true,
	})

	local isInSearchReacquireGrace = os.clock() < self.searchReacquireGraceEndTime
	local timeSinceLastSeen = os.clock() - self.lastSeenTime
	local hasRecentVisualMemory = timeSinceLastSeen <= self.visibilityGraceDuration

	local detectionFov = hasRecentVisualMemory and 360 or sharedConfig.detectionFov
	local inFieldOfView = nearestTarget ~= nil
		and controller.targeting:isTargetInFieldOfView(nearestTarget, detectionFov)

	local isCombatOmniscient = nearestTarget ~= nil
		and (self.lastDistanceTo and self.lastDistanceTo <= sharedConfig.ranges.strafeClose + 10)
		and (self.isStrafing or self.isRushing or isTargetCharging(nearestTarget.agent))

	local canSeeTarget = isCombatOmniscient or (inFieldOfView and controller.targeting:isTargetVisible(nearestTarget))
	local isCrowdControlled = self.agent:GetAttribute("CrowdControl") == true

	if self.isRushing and os.clock() >= self.rushEndTime or self.agent:GetAttribute("CrowdControl") then
		self.isRushing = false
		self.controller.speedController:clearModifier("rushing")
	end

	if controller:getFlag("rushInterruptedByHit") then
		controller:setFlag("rushInterruptedByHit", false)

		if self.isRushing then
			self.isRushing = false
			self.rushEndTime = 0
			controller.speedController:clearModifier("rushing")
		end
	end

	if nearestTarget then
		self.trackedPosition = nearestTarget.root.Position
		self.trackedInBuilding = controller:isGoalInBuilding(self.trackedPosition)
	end

	if self.trackedInBuilding and not canSeeTarget and not isCrowdControlled then
		if not isInSearchReacquireGrace then
			self.buildingEntryUnseenTimer = self.buildingEntryUnseenTimer + deltaTime
		end
	else
		self.buildingEntryUnseenTimer = 0
	end

	if
		not isCrowdControlled
		and self.trackedPosition
		and self.buildingEntryUnseenTimer >= self.buildingEntrySearchDelay
	then
		self.lastKnownPosition = self.trackedPosition
		self.lastKnownInBuilding = self.trackedInBuilding

		controller.stateMachine:change(controller.states.Searching, {
			priorTarget = self.lastTarget or nearestTarget,
			buildingToSearch = self.lastKnownInBuilding,
			lastKnownPosition = self.lastKnownPosition,
			lastKnownInBuilding = self.lastKnownInBuilding,
		})

		return
	end

	local canScream = canSeeTarget
		and not controller:getFlag("hasScreamedThisChase")
		and controller:isActionReady("scream", combatConfig.screamCooldownSeconds)

	if canSeeTarget then
		self.lastSeenTime = os.clock()
		self.lastTarget = nearestTarget
	end

	if canScream and nearestTarget then
		controller:recordActionTime("scream")
		controller.stateMachine:change(controller.states.Screaming, {
			runAndScream = self.runAndScream,
		})

		return
	end

	controller:recordActionTime("chase")
	controller:setCanAttack(true)

	if nearestTarget and (canSeeTarget or isCrowdControlled) then
		self.lastKnownPosition = nearestTarget.root.Position
		self.lastKnownInBuilding = controller:isGoalInBuilding(self.lastKnownPosition)

		self.agent:SetAttribute(
			"NearTarget",
			self.lastDistanceTo and self.lastDistanceTo <= sharedConfig.ranges.nearTarget
		)

		if not self.agent:GetAttribute("CrowdControl") then
			controller:toggleIKControl(true, nearestTarget.agent:FindFirstChild("Head"))
		end

		if not nearestTarget.isRagdolled then
			if not self:handleMovement(nearestTarget, deltaTime) then
				controller:traverse(self.lastKnownPosition)
			end
		else
			controller:stopTraversal()
		end

		return
	else
		self.agent:SetAttribute("NearTarget", false)
	end

	if not self.lastKnownPosition then
		if nearestTarget then
			self.lastKnownPosition = nearestTarget.root.Position
		else
			return
		end
	end

	self.lastDistanceTo = vector.magnitude(self.rootPart.Position - self.lastKnownPosition)

	if self.lastLostTargetPosition ~= self.lastKnownPosition then
		self.lastLostTargetPosition = self.lastKnownPosition
		self.lostTargetPursuitStart = os.clock()
		self.lastDistanceToKnownPosition = self.lastDistanceTo
		self.stalledPursuitTime = 0
		self.nextStallCheck = 0
		self.distanceAtLastStallCheck = nil

		self.maxLostTargetPursuitTime =
			math.max(2, self.lastDistanceTo / self.pursuitSpeedEstimate + self.pursuitTimeBuffer)
	end

	local now = os.clock()
	if now >= self.nextStallCheck then
		if self.distanceAtLastStallCheck then
			local improvement = self.distanceAtLastStallCheck - self.lastDistanceTo

			if improvement < self.stalledPursuitThreshold then
				self.stalledPursuitTime = self.stalledPursuitTime + self.stallCheckInterval
			else
				self.stalledPursuitTime = 0
			end
		end

		self.distanceAtLastStallCheck = self.lastDistanceTo
		self.nextStallCheck = now + self.stallCheckInterval
	end

	self.lastDistanceToKnownPosition = self.lastDistanceTo

	local pursuitElapsed = self.lostTargetPursuitStart and os.clock() - self.lostTargetPursuitStart or 0
	local reachedLastKnownPosition = self.lastDistanceTo <= 7.5
	local pursuitTimedOut = pursuitElapsed >= self.maxLostTargetPursuitTime
	local pursuitStalled = self.stalledPursuitTime >= self.maxStalledPursuitTime

	if
		not isCrowdControlled
		and ((not hasRecentVisualMemory and reachedLastKnownPosition) or pursuitTimedOut or pursuitStalled)
	then
		self.lastKnownPosition = self.trackedPosition or self.lastKnownPosition
		self.lastKnownInBuilding = self.trackedInBuilding

		controller.stateMachine:change(controller.states.Searching, {
			priorTarget = self.lastTarget,
			buildingToSearch = self.lastKnownInBuilding,
			lastKnownPosition = self.lastKnownPosition,
			lastKnownInBuilding = self.lastKnownInBuilding,
		})

		return
	end

	controller:traverse(self.lastKnownPosition)
end

function runningState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(runningState, controller, extraInfo)

	local safeExtraInfo = extraInfo or {}
	self.runAndScream = safeExtraInfo.runAndScream

	return self
end

return runningState
