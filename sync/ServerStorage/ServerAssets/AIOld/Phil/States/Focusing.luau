local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local baseState = require(serverStorage.ServerAssets.AI.StateMachine.StateMachine.BaseState)

local focusingState = baseState.extend("Focusing")

function focusingState:setMovementLocked(isLocked: boolean)
	self.controller.speedController:setLock("focusing", isLocked or nil)
end

function focusingState:stopMovement()
	local humanoid = self.humanoid
	local pathfinder = self.pathfinder
	local rootPart = self.rootPart

	pathfinder:Stop()
	humanoid:MoveTo(rootPart.Position)
end

function focusingState:getNearestFoliage(maximumDistance: number?): BasePart?
	local chosenFoliage = nil
	local closestDistance = math.huge

	for _, foliage in self.foliageParts do
		if not foliage:IsA("BasePart") then
			continue
		end

		local distanceToFoliage = vector.magnitude(self.rootPart.Position - foliage.Position)

		if maximumDistance and distanceToFoliage > maximumDistance then
			continue
		end

		if distanceToFoliage < closestDistance then
			closestDistance = distanceToFoliage
			chosenFoliage = foliage
		end
	end

	return chosenFoliage
end

function focusingState:enter()
	self.controller:setCanAttack(false)
	self.controller:setEyeState(false)
	self:stopMovement()
end

function focusingState:exit()
	self:setMovementLocked(false)
	self.agent:SetAttribute("Focused", false)
end

function focusingState:isFocused(): boolean
	return self.agent:GetAttribute("Focused") == true and not self.controller:isMidAction()
end

function focusingState:setFocused(isFocused: boolean, skipAnimation: boolean?)
	local controller = self.controller
	local focusTracks = self.tracks.focus

	if self:isFocused() == isFocused then
		return
	end

	controller:setMidAction(true)
	self.agent:SetAttribute("Focused", isFocused)
	self:setMovementLocked(true)
	self:stopMovement()

	if skipAnimation then
		if not isFocused then
			focusTracks.idle:Stop()
		end

		self:setMovementLocked(false)
		controller:setMidAction(false)
		return
	end

	if isFocused then
		if not focusTracks.idle.IsPlaying then
			focusTracks.idle:Play()
		end

		audioUtilities.playSound({
			sound = self.sounds.Focus.Start,
			parent = self.rootPart,
		})
	else
		focusTracks.idle:Stop()
	end

	local transitionTrack = isFocused and focusTracks.enter or focusTracks.exit
	transitionTrack:Play()
	transitionTrack:AdjustSpeed(self.timeScale)

	self.connections.transitionEnded = transitionTrack.Ended:Once(function()
		if not isFocused then
			self:setMovementLocked(false)
		end

		controller:setMidAction(false)

		if not isFocused then
			controller.stateMachine:change(controller.states.Running)
		end
	end)
end

function focusingState:update(_deltaTime: number)
	local controller = self.controller
	local focusingConfig = self.config.focusing

	if controller:isMidAction() then
		return
	end

	local nearestTarget = controller.targeting:getNearestTarget({
		range = 100,
		canRaycast = false,
	})

	if not self.ignoreFoliage and not self.hasReachedFoliage and self.chosenFoliage then
		local foliagePosition = self.chosenFoliage.Position
		local distanceToFoliage = vector.magnitude(self.rootPart.Position - foliagePosition)

		self.pathfinder:Run(foliagePosition)

		if distanceToFoliage <= focusingConfig.bushReachedDistance then
			self.hasReachedFoliage = true
		else
			local isNearingFoliage = distanceToFoliage <= focusingConfig.bushApproachLookDistance
			local shouldFaceTarget = nearestTarget ~= nil and not isNearingFoliage
			controller:setOrientationEnabled(shouldFaceTarget)
		end
	else
		self.canBeginFocus = true
	end

	if not nearestTarget then
		self:setFocused(false)
		return
	end

	controller:turnToward(nearestTarget.root.Position)
	controller:toggleIKControl(true, nearestTarget.agent:FindFirstChild("Head"))

	if self.canBeginFocus then
		controller:setOrientationEnabled(true)
		self:stopMovement()
		self:setFocused(true)
	end

	if not self:isFocused() then
		controller:recordActionTime("focusEntry")
		return
	end

	self:stopMovement()

	if self.canStandOff then
		if not controller.targeting:isTargetTurnedAway(nearestTarget) then
			self:setFocused(false, true)
			controller.stateMachine:change(controller.states.StandingOff, {
				target = nearestTarget,
			})

			return
		end
	end

	if not controller.targeting:isTargetVisible(nearestTarget) then
		self:setFocused(false)
		controller:recordActionTime("lunge")
		return
	end

	local timeSinceFocusEntry = os.clock() - controller:getActionTime("focusEntry")

	if timeSinceFocusEntry > focusingConfig.timeUntilLungeSeconds or self.skipWaiting then
		self:setFocused(false, true)
		controller.stateMachine:change(controller.states.Lunging)
	end
end

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

function focusingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(focusingState, controller, extraInfo)
	local safeExtraInfo = extraInfo or {}

	self.ignoreFoliage = safeExtraInfo.ignoreFoliage or false
	self.canStandOff = safeExtraInfo.canStandOff or false
	self.skipWaiting = safeExtraInfo.skipWaiting or false
	self.timeScale = safeExtraInfo.timeScale or 1

	self.foliageParts = getFoliageParts()

	local inheritedFoliage = safeExtraInfo.preferredFoliage
	self.chosenFoliage = (inheritedFoliage and inheritedFoliage.Parent) and inheritedFoliage
		or self:getNearestFoliage(30)

	self.hasReachedFoliage = false
	self.canBeginFocus = false

	return self
end

return focusingState
