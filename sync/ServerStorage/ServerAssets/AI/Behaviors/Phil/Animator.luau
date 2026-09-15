local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local animatorController = inheriter.extend("Animator")
animatorController.__vars = {
	strafeThreshold = 1,
	minimumMoveVelocity = 0.25,
}

function animatorController:setTrackPlaying(track: AnimationTrack, shouldPlay: boolean)
	if shouldPlay then
		if not track.IsPlaying then
			track:Play()
		end
	else
		track:Stop()
	end
end

function animatorController:cancelAllTracks()
	if self.currentMoveTrack then
		self.currentMoveTrack:Stop()
		self.currentMoveTrack = nil
	end

	self.idleTrack:Stop()
end

function animatorController:getMoveDirection(rootPart: BasePart, velocity: Vector3)
	return rootPart.CFrame:VectorToObjectSpace(velocity)
end

function animatorController:getMoveState(velocity: Vector3)
	local x, z = velocity.X, velocity.Z
	local threshold = self.strafeThreshold

	if self.lastDirection then
		threshold = self.strafeThreshold * (self.lastDirection == "forward" and 1 or 0.75)
	end

	if math.abs(x) > math.abs(z) then
		if x > threshold then
			return "right"
		elseif x < -threshold then
			return "left"
		end
	else
		if z > threshold then
			return "backward"
		elseif z < -threshold then
			return "forward"
		end
	end

	return "forward"
end

function animatorController:init() end

function animatorController.new(ai)
	local self = inheriter.new(ai, animatorController)

	self.idleTrack = self.tracks.idle
	self.walkTracks = self.tracks.walk
	self.runTracks = self.tracks.run

	self.strafeThreshold = self.__vars.strafeThreshold
	self.minimumMoveVelocity = self.__vars.minimumMoveVelocity

	self.enabled = true

	task.spawn(self.init, self)

	return self
end

function animatorController:setEnabled(state: boolean)
	self.enabled = state
end

function animatorController:update()
	if not self.enabled then
		self:cancelAllTracks()
		return
	end

	local rawVelocity = self.rootPart:GetVelocityAtPosition(self.rootPart.Position)
	self.smoothedVelocity = self.smoothedVelocity and self.smoothedVelocity:Lerp(rawVelocity, 0.35) or rawVelocity

	local isMoving = vector.magnitude(self.smoothedVelocity) >= self.minimumMoveVelocity
	local isRunning = self.humanoid.WalkSpeed >= self.walkSpeedConfig.run

	if isMoving then
		local localVelocity = self:getMoveDirection(self.rootPart, self.smoothedVelocity)
		local direction = self:getMoveState(localVelocity)

		local setGroup = isRunning and self.runTracks or self.walkTracks
		local desiredTrack = setGroup[direction]

		local baseSpeed = isRunning and self.walkSpeedConfig.run or self.walkSpeedConfig.walk
		local targetScale = baseSpeed > 0 and (self.humanoid.WalkSpeed / baseSpeed) or 1

		self.currentScale = self.currentScale and (self.currentScale + (targetScale - self.currentScale) * 0.2)
			or targetScale

		if not isRunning then
			if self.agent:GetAttribute("Sneaking") then
				desiredTrack = setGroup.sneakForward
			elseif self.agent:GetAttribute("Searching") then
				desiredTrack = setGroup.searchForward
			end
		else
			if direction == "forward" and self.ai:getActionFlag("NearTarget") then
				desiredTrack = setGroup.nearTargetForward
			end
		end

		if self.currentMoveTrack ~= desiredTrack then
			if self.currentMoveTrack then
				self.currentMoveTrack:Stop()
			end

			if desiredTrack then
				desiredTrack:Play()
			end

			self.currentMoveTrack = desiredTrack
		end

		if self.currentMoveTrack then
			self.currentMoveTrack:AdjustSpeed(self.currentScale)
		end
	else
		if self.currentMoveTrack then
			self.currentMoveTrack:Stop()
			self.currentMoveTrack = nil
		end
	end

	self:setTrackPlaying(self.idleTrack, not isMoving)
end

return animatorController
