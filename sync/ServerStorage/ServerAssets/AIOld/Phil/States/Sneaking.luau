local serverStorage = game:GetService("ServerStorage")

local baseState = require(serverStorage.ServerAssets.AI.BaseState)

local sneakingState = baseState.extend("Sneaking")

local cachedFoliageParts = nil
local lastFoliageCacheTime = 0
local foliageCacheRefreshSeconds = 5

local function getFoliageParts(): { Instance }
	local now = os.clock()

	if cachedFoliageParts and now - lastFoliageCacheTime < foliageCacheRefreshSeconds then
		return cachedFoliageParts
	end

	lastFoliageCacheTime = now

	local foliageParent = workspace:FindFirstChild("Foligen")
	local foliageContainer = foliageParent and foliageParent:FindFirstChild("Foliage")
	cachedFoliageParts = foliageContainer and foliageContainer:GetChildren() or {}

	return cachedFoliageParts
end

function sneakingState:enter()
	local speedController = self.controller.speedController
	local walkSpeeds = self.config.shared.walkSpeeds

	speedController:clearAll()
	speedController:setModifier("sneaking", walkSpeeds.sneak - walkSpeeds.idle)

	self.agent:SetAttribute("Sneaking", true)
	self.agent:SetAttribute("Chasing", false)
	self.controller:setCanAttack(true)
	self.controller:setEyeState(false)
end

function sneakingState:exit()
	self.agent:SetAttribute("Sneaking", false)
end

function sneakingState:getRandomFoliage(origin: BasePart, maximumDistance: number): BasePart?
	local possibleFoliage = {}

	for _, foliage in self.foliageParts do
		if not foliage:IsA("BasePart") then
			continue
		end

		local distanceToFoliage = vector.magnitude(origin.Position - foliage.Position)

		if maximumDistance and distanceToFoliage > maximumDistance then
			continue
		end

		table.insert(possibleFoliage, foliage)
	end

	if #possibleFoliage <= 0 then
		return nil
	end

	return possibleFoliage[math.random(1, #possibleFoliage)]
end

function sneakingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(sneakingState, controller, extraInfo)

	self.sharedConfig = self.config.shared
	self.foliageParts = getFoliageParts()

	self.canOrientate = false

	self.stopAndStaring = false
	self.walkingToFoliage = false
	self.currentFoliage = nil
	self.beingLookedAt = false

	self.orbitDirection = 1
	self.nextStareTime = os.clock() + math.random(15, 20)
	self.nextResetTime = 0

	self.awarenessTimer = 0
	self.sneakOpportunityTimer = 0

	self.screamThreshold = 4
	self.sneakAttackThreshold = 10

	self.trySneakAttack = false

	return self
end

function sneakingState:startStaring(nonBushOverride: boolean)
	self.stopAndStaring = true
	self.canOrientate = false
	self.foliageMoveTimeout = os.clock() + 5

	self.controller:stopTraversal()

	if not nonBushOverride and math.random() <= 0.5 then
		local foliage = self:getRandomFoliage(self.rootPart, self.sharedConfig.ranges.sneak)

		if foliage then
			self.walkingToFoliage = true
			self.currentFoliage = foliage

			self.controller:traverse(foliage.Position)

			return
		end
	else
		self.walkingToFoliage = false
		self.currentFoliage = nil
	end

	self.canOrientate = true
	self.nextResetTime = os.clock() + math.random(6, 9)
end

function sneakingState:stopStaring()
	self.stopAndStaring = false
	self.walkingToFoliage = false
	self.currentFoliage = nil

	self.canOrientate = false
	self.orbitDirection = self.orbitDirection * -1

	self.nextStareTime = os.clock() + math.random(15, 20)
end

function sneakingState:circleTarget()
	local controller = self.controller

	local currentTarget = self.target
	local targetRoot = currentTarget and currentTarget.root

	if targetRoot ~= nil then
		local targetPosition = targetRoot.Position
		local agentPosition = self.rootPart.Position

		local offset = agentPosition - targetPosition
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = vector.magnitude(flat)

		if distance > 0.001 then
			local directionFrom = flat.Unit
			local tangent = Vector3.new(-directionFrom.Z, 0, directionFrom.X) * self.orbitDirection

			local radiusError = distance - self.sharedConfig.ranges.strafeFar
			local correctionOffset = -directionFrom * radiusError * 0.15
			local moveDirection = (tangent + correctionOffset).Unit

			controller:traverse(agentPosition + moveDirection * 12)
		end
	end
end

function sneakingState:update(deltaTime: number)
	local controller = self.controller
	local targeting = controller.targeting
	local speedController = self.controller.speedController
	local walkSpeeds = self.config.shared.walkSpeeds
	local now = os.clock()

	self.target = targeting:getNearestTarget({
		range = self.sharedConfig.ranges.walk,
		canRaycast = false,
	})

	self.controller:setOrientationEnabled(self.canOrientate)

	if self.canOrientate and self.target and self.target.root then
		self.controller:turnToward(self.target.root.Position)
	end

	self.lastDistanceTo = self.target and vector.magnitude(self.target.root.Position - self.rootPart.Position) or nil

	if self.lastDistanceTo ~= nil then
		self.beingLookedAt = self.lastDistanceTo <= self.sharedConfig.ranges.sneak
			and not targeting:isTargetTurnedAway(self.target)
			and targeting:isTargetVisible(self.target, self.sharedConfig.ranges.sneak)

		local closeness = 1 - math.clamp(self.lastDistanceTo / self.sharedConfig.ranges.sneak, 0, 1)
		closeness = closeness ^ 2

		if self.beingLookedAt then
			local awarenessMultiplier = 1 + closeness * 5
			self.awarenessTimer += deltaTime * awarenessMultiplier

			self.sneakOpportunityTimer = 0
		else
			self.awarenessTimer = 0

			if not self.stopAndStaring then
				self.sneakOpportunityTimer += deltaTime
			end
		end

		if self.awarenessTimer >= self.screamThreshold then
			controller.stateMachine:change(controller.states.Running, {
				runAndScream = true,
			})

			return
		end

		if self.lastDistanceTo and self.lastDistanceTo <= 15 then
			if self.beingLookedAt then
				controller.stateMachine:change(controller.states.Running, {
					runAndScream = true,
				})

				return
			end

			if not self.startFakeChase then
				self.startFakeChase = true

				speedController:clearAll()
				speedController:setModifier("fakeChasing", walkSpeeds.run - walkSpeeds.idle)
			end

			return
		end

		if self.beingLookedAt then
			self.walkingToFoliage = false
			self.currentFoliage = nil

			if not self.stopAndStaring then
				self:startStaring(true)

				if math.random() <= 0.8 then
					self.trySneakAttack = false
				end

				self.nextResetTime = os.clock() + math.random(2, 3)
			end
		end
	end

	if self.walkingToFoliage and self.currentFoliage then
		local distanceToFoliage = vector.magnitude(self.rootPart.Position - self.currentFoliage.Position)
		local timedOut = now >= self.foliageMoveTimeout

		if distanceToFoliage <= self.sharedConfig.pathDistanceTolerance or timedOut then
			self.walkingToFoliage = false
			self.currentFoliage = nil

			self.canOrientate = true
			self.nextResetTime = now + math.random(6, 9)
		end

		return
	end

	if not self.stopAndStaring then
		if self.trySneakAttack then
			self.nextStareTime = now + math.random(15, 20)
		end

		if now >= self.nextStareTime then
			self:startStaring()
		end
	else
		if now >= self.nextResetTime then
			self:stopStaring()

			if not self.beingLookedAt and self.target and math.random() <= 0.55 then
				self.trySneakAttack = true
			end
		end

		return
	end

	if not self.trySneakAttack then
		self:circleTarget()
	else
		if not self.target then
			self.trySneakAttack = false
			return
		end

		self.pathfinder:Run(self.target.root.Position)
	end
end

return sneakingState
