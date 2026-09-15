local crowdControlController = {}
crowdControlController.__index = crowdControlController

function crowdControlController:attemptTo()
	if self.currentValue or self.agent:GetAttribute("CrowdControl") then
		self.startedAt = os.clock()
		return
	end

	local targetsInRange = self.controller.targeting:getAllTargetsInRange({
		range = self.sharedConfig.ranges.run,
		canRaycast = false,
	})

	if
		self.instance.currentDamageInSuccession >= self.combatConfig.crowdControlDamageThreshold
		and #targetsInRange >= self.combatConfig.playersNearbyToCrowdControl
	then
		self.startedAt = os.clock()
		self.agent:SetAttribute("CrowdControl", true)
	end
end

function crowdControlController:init()
	self.connections.onCrowdControl = self.agent:GetAttributeChangedSignal("CrowdControl"):Connect(function()
		self.currentValue = self.agent:GetAttribute("CrowdControl")

		if self.currentValue then
			self.controller.speedController:setLock("crowdControl", true)
			self.controller:setFlag("hasEnteredCrowdControl", true)

			return
		end

		self.controller.speedController:clearLock("crowdControl")
	end)
end

function crowdControlController.new(parentInstance: any)
	local self = setmetatable({}, crowdControlController)

	self.instance = parentInstance
	self.controller = self.instance.controller
	self.agent = self.instance.agent
	self.humanoid = self.instance.humanoid

	self.sharedConfig = self.controller.config.shared
	self.combatConfig = self.controller.config.combat
	self.connections = {}

	self.tracks = self.instance.tracks
	self.crowdControlLoop = self.tracks.crowdControl.loop
	self.pushTrack = self.tracks.push[1]

	task.spawn(self.init, self)

	return self
end

function crowdControlController:update(_deltaTime)
	self.isBusy = self.pushTrack.IsPlaying
		or self.agent:GetAttribute("Attacking")
		or self.agent:GetAttribute("Blocking")
		or self.agent:GetAttribute("Spitting")

	if self.currentValue then
		local elapsed = os.clock() - (self.startedAt or 0)
		local targetsInRange = self.controller.targeting:getAllTargetsInRange({
			range = self.sharedConfig.ranges.run,
			canRaycast = false,
		})

		if elapsed >= self.combatConfig.crowdControlDurationSeconds or #targetsInRange == 0 then
			self.startedAt = nil
			self.currentValue = false
			self.agent:SetAttribute("CrowdControl", false)
			self.controller:setOrientationEnabled(false)

			return
		end
	end

	local nearestTarget = self.controller.targeting:getNearestTarget({
		range = self.sharedConfig.ranges.run,
		useTargetCache = true,
	})

	if self.currentValue then
		self.humanoid.WalkSpeed = self.sharedConfig.walkSpeeds.crowdControl

		if not self.loopActive and not self.isBusy then
			self.loopActive = true
			self.crowdControlLoop:Play(0.5, 1)
		end

		self.controller:toggleIKControl(self.isBusy, nearestTarget and nearestTarget.agent:FindFirstChild("Head"))
		self.controller:turnToward(nearestTarget and nearestTarget.root.Position)
		self.controller:setOrientationEnabled(true)
	end

	if (not self.currentValue or self.isBusy) and self.loopActive then
		self.loopActive = false
		self.crowdControlLoop:Stop(1)
	end
end

return crowdControlController
