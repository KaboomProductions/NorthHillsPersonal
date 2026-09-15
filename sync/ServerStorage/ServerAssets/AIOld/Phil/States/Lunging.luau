local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local serverStorage = game:GetService("ServerStorage")
local tweenService = game:GetService("TweenService")

local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local hitboxController = require(replicatedStorage.SharedClasses.Hitbox)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)
local baseState = require(serverStorage.ServerAssets.AI.StateMachine.StateMachine.BaseState)

local wallRaycastParams = RaycastParams.new()
wallRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
wallRaycastParams.FilterDescendantsInstances = { workspace.Components, workspace.Ignore }
wallRaycastParams.RespectCanCollide = true

local hitboxParams = OverlapParams.new()
hitboxParams.FilterType = Enum.RaycastFilterType.Exclude
hitboxParams.RespectCanCollide = true

local lungingState = baseState.extend("Lunging")

local function flattenVector(inputVector: Vector3): Vector3
	return Vector3.new(inputVector.X, 0, inputVector.Z)
end

function lungingState.canEnter(controller: any, _extraInfo: { [string]: any }?): boolean
	local currentTarget = controller.currentTarget
	local targeting = controller.targeting

	return currentTarget ~= nil and currentTarget.root ~= nil and not targeting:isTargetDead(currentTarget)
end

function lungingState:playLungeSound(soundName: string)
	local lungeSounds = self.sounds:FindFirstChild("Lunge")
	local targetSound = lungeSounds and lungeSounds:FindFirstChild(soundName)

	if not targetSound then
		return
	end

	audioUtilities.playSound({
		sound = targetSound,
		parent = self.rootPart,
	})
end

function lungingState:hasHitWall(): boolean
	local rootPart = self.rootPart
	local moveDirection = rootPart.CFrame.LookVector

	local raycastResult =
		workspace:Raycast(rootPart.Position, moveDirection * self.wallCheckDistanceStuds, wallRaycastParams)

	return raycastResult ~= nil
end

function lungingState:stopSpeedTween()
	local activeSpeedTween = self.activeSpeedTween

	if not activeSpeedTween then
		return
	end

	activeSpeedTween:Cancel()
	self.activeSpeedTween = nil
end

function lungingState:createSpeedTween(durationSeconds: number, targetWalkSpeed: number): Tween
	local humanoid = self.humanoid
	local newTween = tweenService:Create(humanoid, TweenInfo.new(durationSeconds), {
		WalkSpeed = targetWalkSpeed,
	})

	self.activeSpeedTween = newTween
	return newTween
end

function lungingState:stopHitbox()
	local hitConnection = self.connections.hitTouched
	local hitbox = self.hitbox

	if hitConnection then
		hitConnection:Disconnect()
		self.connections.hitTouched = nil
	end

	if hitbox then
		pcall(function()
			hitbox:Stop()
		end)

		self.hitbox = nil
	end
end

function lungingState:updateHitboxPosition()
	local hitbox = self.hitbox
	local lungingConfig = self.config.lunging
	local rootPart = self.rootPart

	if not hitbox or not rootPart.Parent then
		return
	end

	local hitboxSize = hitbox.Size
	local longestAxisIndex = mathUtilities.getLongestAxis(hitboxSize)
	local longestAxisName = mathUtilities.axisMap[longestAxisIndex]
	local offsetAmount = hitboxSize[longestAxisName] / 2 + lungingConfig.hitboxOffsetStuds

	local rootPartCFrame = rootPart.CFrame
	local velocityPrediction = rootPartCFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity)
		/ lungingConfig.hitboxVelocityPredictionDivisor
	hitbox.CFrame = rootPartCFrame * CFrame.new(0, 0, -offsetAmount) * CFrame.new(velocityPrediction)
end

function lungingState:registerHitbox()
	local agent = self.agent
	local lungingConfig = self.config.lunging

	self:stopHitbox()

	hitboxParams.FilterDescendantsInstances = { agent, workspace.Ignore }

	local newHitbox = hitboxController.CreateHitbox()
	newHitbox.Size = agent:GetExtentsSize() * lungingConfig.hitboxSizeScale
	newHitbox.OverlapParams = hitboxParams
	newHitbox.Visualizer = false
	self.hitbox = newHitbox

	task.spawn(function()
		while self.hitbox == newHitbox and not self.isFinished do
			if self.rootPart.Parent == nil then
				break
			end

			self:updateHitboxPosition()
			task.wait(lungingConfig.hitboxUpdateIntervalSeconds)
		end
	end)
end

function lungingState:finishState()
	local controller = self.controller

	if self.isFinished then
		return
	end

	self.isFinished = true

	self:stopSpeedTween()
	self:stopHitbox()

	controller:setMidAction(false)
	controller:recordActionTime("lunge")
	controller.stateMachine:change(controller.states.Running)
end

function lungingState:beginCarryOver()
	local lungingConfig = self.config.lunging

	if self.isCarryingOver then
		return
	end

	self.isCarryingOver = true

	if self.isSlowing then
		return
	end

	self.isSlowing = true

	self:stopSpeedTween()
	self:createSpeedTween(lungingConfig.carryOverSlowdownSeconds, 0):Play()
end

function lungingState:startLandingSequence()
	local lungingConfig = self.config.lunging
	local landTrack = self.landTrack
	local wallImpactTrack = self.wallImpactTrack

	if self.didStartLanding or self.isFinished then
		return
	end

	self.didStartLanding = true

	if self.didHitWall then
		self.isRecovering = true
		self.humanoid.WalkSpeed = 0

		if wallImpactTrack then
			wallImpactTrack:Play()
		end

		task.spawn(function()
			repeat
				task.wait(lungingConfig.statePollIntervalSeconds)
			until self.isFinished or not wallImpactTrack or not wallImpactTrack.IsPlaying

			self:finishState()
		end)

		return
	end

	if landTrack then
		landTrack:Play()
	end

	self:playLungeSound("Land")
	self:registerHitbox()

	if landTrack then
		self.connections.hitboxStart = landTrack:GetMarkerReachedSignal("Start"):Once(function()
			if self.hitbox and not self.isFinished then
				self.hitbox:Start()
			end
		end)

		self.connections.hitboxEnd = landTrack:GetMarkerReachedSignal("End"):Once(function()
			self:stopHitbox()
			self:beginCarryOver()
		end)
	end

	self.connections.hitTouched = self.hitbox.Touched:Connect(function(_part, hitHumanoid)
		if not hitHumanoid or hitHumanoid == self.humanoid or self.didHitTarget then
			return
		end

		self.didHitTarget = true
		hitHumanoid:TakeDamage(hitHumanoid.MaxHealth)
		self:playLungeSound("Hit")
	end)

	task.spawn(function()
		repeat
			task.wait(lungingConfig.statePollIntervalSeconds)
		until self.isFinished
			or ((not landTrack or not landTrack.IsPlaying) and (not wallImpactTrack or not wallImpactTrack.IsPlaying))

		self.isRecovering = true
		self:finishState()
	end)
end

function lungingState:startMotionLoop()
	local controller = self.controller
	local currentTarget = self.currentTarget
	local targetRootPart = currentTarget and currentTarget.root
	local rootPart = self.rootPart
	local humanoid = self.humanoid
	local lungingConfig = self.config.lunging
	local baseDirection = targetRootPart and (targetRootPart.Position - rootPart.Position).Unit
		or rootPart.CFrame.LookVector

	task.spawn(function()
		self.currentDirection = rootPart.CFrame.LookVector

		while controller:isMidAction() and not self.isRecovering and not self.isFinished do
			local deltaTime = runService.Stepped:Wait()
			local targetOffset = targetRootPart and (targetRootPart.Position - rootPart.Position)
				or self.currentDirection

			if self:hasHitWall() then
				self.didHitWall = true
				self:startLandingSequence()
				break
			end

			if not self.currentDirection then
				self.currentDirection = baseDirection
			end

			if not self.isCarryingOver then
				local desiredDirection = targetOffset.Magnitude > 0 and targetOffset.Unit or self.currentDirection
				self.currentDirection = self.currentDirection:Lerp(
					desiredDirection,
					math.clamp(lungingConfig.turnSpeed * deltaTime, 0, lungingConfig.maxTurnAlpha)
				).Unit

				self.distanceTraveledStuds = (rootPart.Position - self.initialPosition).Magnitude
				if self.distanceTraveledStuds >= self.lungeDistanceStuds then
					self:beginCarryOver()
				end
			end

			if self.currentDirection:Dot(baseDirection) < lungingConfig.directionCorrectionDot then
				self.currentDirection =
					baseDirection:Lerp(self.currentDirection, lungingConfig.directionCorrectionAlpha).Unit
			end

			if self.currentDirection then
				self.lastMoveDirection = self.currentDirection
			end

			if self.isCarryingOver then
				self.currentDirection = self.lastMoveDirection
			end

			local moveDirection = self.currentDirection or self.lastMoveDirection or baseDirection
			local moveDistance = if self.isCarryingOver
				then lungingConfig.carryOver
				else math.max(self.lungeDistanceStuds - self.distanceTraveledStuds, 0)

			local goalPosition = rootPart.Position + moveDirection * moveDistance
			humanoid:MoveTo(goalPosition)
			controller:turnToward(goalPosition)

			if self.isCarryingOver and humanoid.WalkSpeed <= lungingConfig.stopSpeedThreshold then
				break
			end
		end

		if not self.isRecovering and not self.isFinished then
			self:startLandingSequence()
		end
	end)
end

function lungingState:enter()
	local controller = self.controller
	local currentTarget = controller.currentTarget
	local lungingConfig = self.config.lunging

	self.currentTarget = currentTarget

	controller.speedController:setLock("lunging", true)
	self.humanoid.WalkSpeed = 0
	self.agent:SetAttribute("Lunging", true)

	controller:setCanAttack(false)
	controller:setEyeState(true)
	controller:setOrientationEnabled(true)
	controller:setMidAction(true)
	controller:cancelTracksInDictionary(self.tracks.focus)
	self.pathfinder:Stop()

	self:playLungeSound("Start")
	self:createSpeedTween(lungingConfig.lungeSpeedTweenSeconds, self.targetLungeWalkSpeed):Play()

	if self.jumpTrack then
		self.jumpTrack:Play()
	end

	self:startMotionLoop()

	task.delay(lungingConfig.landingDelaySeconds, function()
		if self.isFinished or self.isRecovering then
			return
		end

		self:startLandingSequence()
	end)
end

function lungingState:update(_deltaTime: number)
	if self.currentTarget then
		self.controller:toggleIKControl(true, self.currentTarget.agent:FindFirstChild("Head"))
	end
end

function lungingState:exit()
	local jumpTrack = self.jumpTrack
	local landTrack = self.landTrack
	local wallImpactTrack = self.wallImpactTrack
	local loopTrack = self.loopTrack
	local lungingConfig = self.config.lunging

	self.isFinished = true

	self:stopSpeedTween()
	self:stopHitbox()

	if jumpTrack and jumpTrack.IsPlaying then
		jumpTrack:Stop(lungingConfig.trackFadeSeconds)
	end

	if landTrack and landTrack.IsPlaying then
		landTrack:Stop(lungingConfig.trackFadeSeconds)
	end

	if wallImpactTrack and wallImpactTrack.IsPlaying then
		wallImpactTrack:Stop(lungingConfig.trackFadeSeconds)
	end

	if loopTrack and loopTrack.IsPlaying then
		loopTrack:Stop(lungingConfig.trackFadeSeconds)
	end

	self.agent:SetAttribute("Lunging", false)

	self.controller.speedController:clearLock("lunging")
	self.controller:toggleIKControl(false)
end

function lungingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(lungingState, controller, extraInfo)

	local currentTarget = controller.currentTarget
	local rootPart = controller.rootPart
	local sharedConfig = self.config.shared
	local lungingConfig = self.config.lunging

	local targetOffset = currentTarget and currentTarget.root and (currentTarget.root.Position - rootPart.Position)
	local horizontalOffset = targetOffset and flattenVector(targetOffset)
	local distanceToTargetStuds = horizontalOffset and horizontalOffset.Magnitude or lungingConfig.distance

	self.currentTarget = currentTarget
	self.jumpTrack = self.tracks.lunge.jump
	self.loopTrack = self.tracks.lunge.loop
	self.landTrack = self.tracks.lunge.land
	self.wallImpactTrack = self.tracks.lunge.wallImpact

	self.hitbox = nil
	self.activeSpeedTween = nil

	self.initialPosition = rootPart.Position
	self.currentDirection = nil
	self.lastMoveDirection = nil
	self.isFinished = false
	self.isRecovering = false
	self.isCarryingOver = false
	self.isSlowing = false
	self.didStartLanding = false
	self.didHitWall = false
	self.didHitTarget = false
	self.distanceTraveledStuds = 0

	self.targetLungeWalkSpeed =
		math.max(sharedConfig.walkSpeeds.run * lungingConfig.lungeSpeedMultiplier, lungingConfig.minimumLungeSpeed)
	self.wallCheckDistanceStuds = math.max(lungingConfig.minimumWallCheckDistance, lungingConfig.wallCheckDistance)
	self.lungeDistanceStuds = math.clamp(distanceToTargetStuds, lungingConfig.minimumDistance, lungingConfig.distance)

	return self
end

return lungingState
