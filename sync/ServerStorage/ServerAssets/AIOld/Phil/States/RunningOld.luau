local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtilities = require(replicatedStorage.SharedUtilities.ItemUtils)
local baseState = require(serverStorage.ServerAssets.AI.StateMachine.StateMachine.BaseState)

local runningState = baseState.extend("Running")

function runningState:enter()
	local speedController = self.controller.speedController
	local walkSpeeds = self.config.shared.walkSpeeds

	speedController:clearAll()
	speedController:setModifier("running", walkSpeeds.run - walkSpeeds.idle)

	self.orbitDirection = math.random() <= 0.5 and -1 or 1
	self.nextOrbitFlip = 0

	self.agent:SetAttribute("Sneaking", false)
	self.agent:SetAttribute("Lunging", false)
	self.agent:SetAttribute("Screaming", false)
	self.agent:SetAttribute("Chasing", true)

	self.controller:setEyeState(true)
	self.controller:setOrientationEnabled(false)
	self.controller:setMidAction(false)
end

function runningState:exit()
	self.controller:toggleIKControl(false)
	self.agent:SetAttribute("NearTarget", false)
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

function runningState:handleMovement(nearestTarget)
	local controller = self.controller
	local sharedConfig = self.config.shared
	local combatConfig = self.config.combat
	local visibilityParams = controller.targeting.visibilityRaycastParams

	local targetRoot = nearestTarget.root
	local targetAgent = nearestTarget.agent

	local selfPosition = self.rootPart.Position
	local targetPosition = targetRoot.Position

	local offset = selfPosition - targetPosition
	local distance = vector.magnitude(offset)

	local tool = itemUtilities.checkForTool(targetAgent)
	local isCharging = tool and tool:GetAttribute("Charging")
	local chargeStrength = (tool and tool:GetAttribute("ChargeStrength")) or 0

	local now = os.clock()

	if self.isRushing and now >= self.rushEndTime then
		self.isRushing = false
	end

	if not self.isRushing and isCharging and chargeStrength > 0.5 then
		if controller:isActionReady("rush", combatConfig.rushCooldownSeconds) then
			if math.random() <= combatConfig.rushChance then
				self.isRushing = true
				self.rushEndTime = now + combatConfig.rushDuration
				controller:recordActionTime("rush")
			end
		end
	end

	local shouldAvoidTarget = not self.isRushing and distance <= sharedConfig.ranges.strafeClose + 10 and isCharging

	if shouldAvoidTarget then
		self:updateOrbitOrientation()
	else
		if self.orientationEnabled then
			self.orientationEnabled = false
			self.controller:setOrientationEnabled(false)
		end
	end

	if shouldAvoidTarget then
		self:updateOrbitDirection()

		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		distance = vector.magnitude(flatOffset)

		if distance <= 0.001 then
			return
		end

		local awayDirection = flatOffset.Unit
		local tangentDirection = Vector3.new(-awayDirection.Z, 0, awayDirection.X) * self.orbitDirection
		local radiusError = distance - sharedConfig.ranges.strafeClose

		local correction = -awayDirection * radiusError * 0.15
		local moveDirection = (tangentDirection + correction).Unit
		local randomOffset = Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))

		controller:traverse(selfPosition + moveDirection * 12 + randomOffset)
		controller:turnToward(targetPosition)

		return
	end

	local velocity = targetRoot.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local predictedPosition = targetPosition

	if speed > 0.1 then
		local moveDirection = velocity.Unit
		local facingFactor = (targetPosition - selfPosition).Unit:Dot(moveDirection) > 0 and 1 or 0
		local predictionDistance = math.clamp(speed, 5, 20) * facingFactor

		predictedPosition = predictedPosition + moveDirection * predictionDistance
	end

	local displacement = predictedPosition - selfPosition
	local obstruction = workspace:Raycast(selfPosition, displacement, visibilityParams)

	local goalPosition = obstruction and targetPosition or predictedPosition
	local groundResult = workspace:Raycast(goalPosition, Vector3.yAxis * -1, visibilityParams)

	if groundResult then
		goalPosition = groundResult.Position
	end

	controller:traverse(goalPosition)
end

function runningState:update(_deltaTime: number)
	local controller = self.controller
	local sharedConfig = self.config.shared
	local combatConfig = self.config.combat

	local targetInfo = {
		range = sharedConfig.ranges.run,
		canRaycast = false,
		useTargetCache = true,
	}

	local nearestTarget = controller.targeting:getNearestTarget(targetInfo)
	local targetsInRange = controller.targeting:getAllTargetsInRange(targetInfo)

	local canSpit = not self.agent:GetAttribute("CrowdControl")
		and controller:isActionReady("spit", combatConfig.spitCooldownSeconds)
		and #targetsInRange >= combatConfig.spitMinimumTargets
	local canScream = not controller:getFlag("hasScreamedThisChase")
		and controller:isActionReady("scream", combatConfig.screamCooldownSeconds)

	if canScream and nearestTarget then
		controller:recordActionTime("scream")

		controller.stateMachine:change(controller.states.Screaming, {
			runAndScream = self.runAndScream,
		})

		return
	end

	controller:setCanAttack(true)

	if nearestTarget then
		local targetRoot = nearestTarget.root
		local distanceToTarget = vector.magnitude(self.rootPart.Position - targetRoot.Position)

		if canSpit then
			controller.stateMachine:change(controller.states.Spitting)
			return
		end

		self.agent:SetAttribute("NearTarget", distanceToTarget <= sharedConfig.ranges.nearTarget)

		controller:toggleIKControl(true, nearestTarget.agent:FindFirstChild("Head"))
		controller:recordActionTime("chase")
		self:handleMovement(nearestTarget)
	else
		controller.stateMachine:change(controller.states.Wandering)
	end
end

function runningState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(runningState, controller, extraInfo)

	self.orbitDirection = math.random() <= 0.5 and -1 or 1
	self.nextOrbitFlip = 0

	self.orientationEnabled = false
	self.nextOrientationToggle = 0

	local safeExtraInfo = extraInfo or {}
	self.runAndScream = safeExtraInfo.runAndScream

	return self
end

return runningState
