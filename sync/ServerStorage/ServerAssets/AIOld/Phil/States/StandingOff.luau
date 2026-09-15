local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local baseState = require(serverStorage.ServerAssets.AI.BaseState)
local networking = require(replicatedStorage.Communication.Networking)

local standingOffState = baseState.extend("StandingOff")

function standingOffState:ensureMinimumDistance()
	local standingOffConfig = self.config.standingOff
	local currentTarget = self.currentTarget

	self.pathfinder:Stop()

	if not currentTarget or not currentTarget.root then
		return
	end

	local origin = self.rootPart.Position
	local targetPosition = currentTarget.root.Position
	local offset = origin - targetPosition
	local distanceToTarget = vector.magnitude(offset)

	if distanceToTarget < 0.1 then
		offset = self.rootPart.CFrame.LookVector
	end

	local direction = offset.Unit
	local desiredPosition = targetPosition + direction * standingOffConfig.minimumDistance
	desiredPosition = Vector3.new(desiredPosition.X, origin.Y, desiredPosition.Z)

	self.humanoid:MoveTo(desiredPosition)
end

function standingOffState:getAvailablePoses(): { AnimationTrack }
	local standOffTracks = self.tracks.standOff
	local availablePoses = {}

	for _, track in standOffTracks.poses do
		if track ~= self.currentPoseTrack then
			table.insert(availablePoses, track)
		end
	end

	return availablePoses
end

function standingOffState:cancelCurrentPose()
	if self.currentPoseTrack then
		self.currentPoseTrack:Stop(0.15)
	end
end

function standingOffState:swapPose()
	local poseTracks = self:getAvailablePoses()
	local standingOffConfig = self.config.standingOff

	self:cancelCurrentPose()

	local randomTrack = poseTracks[math.random(1, #poseTracks)]
	randomTrack:Play(0.25)

	self.killTimer = standingOffConfig.deathTimerSeconds
	self.stareTimer =
		self.randomGenerator:NextNumber(standingOffConfig.stareMinimumSeconds, standingOffConfig.stareMaximumSeconds)
	self.currentPoseTrack = randomTrack
end

function standingOffState:setTwitching(isStaring: boolean)
	local standOffTracks = self.tracks.standOff
	local twitchTrack = standOffTracks.twitch
	local twitchSound = self.twitchSound

	if not twitchSound then
		return
	end

	if isStaring then
		if not twitchTrack.IsPlaying then
			twitchTrack:Play()
		end

		if not twitchSound.IsPlaying then
			twitchSound:Play()
		end
	else
		twitchTrack:Stop()
		twitchSound:Stop()
	end
end

function standingOffState:fireClientEvent(stage: string)
	if not self.currentTarget or not self.player then
		return
	end

	local standingOffConfig = self.config.standingOff

	local payload = {
		caller = "phil",
		agent = self.agent,
		event = "standoff",
		stage = stage,
	}

	if stage == "start" then
		payload.extraInfo = {
			maxTime = standingOffConfig.deathTimerSeconds,
		}
	elseif stage == "end" then
		payload.extraInfo = {
			failed = self.didFail,
		}
	end

	networking.events.ai:FireClient(self.player, payload)
end

function standingOffState:enter()
	local controller = self.controller
	local currentTarget = self.currentTarget
	local targeting = controller.targeting
	local focusTracks = self.tracks.focus

	if not currentTarget or not currentTarget.root or targeting:isTargetDead(currentTarget) then
		controller.stateMachine:change(controller.states.Running)
		return
	end

	self:ensureMinimumDistance()
	self:swapPose()

	controller:setMidAction(true)
	controller:setEyeState("enraged")
	controller:setOrientationEnabled(true)
	controller:cancelTracksInDictionary(focusTracks)

	self.agent:SetAttribute("Chasing", false)

	local twitchSound = self.sounds.HeadTwitch:Clone()
	twitchSound.Parent = self.rootPart
	self.twitchSound = twitchSound

	self:fireClientEvent("start")
end

function standingOffState:exit()
	self.controller:setMidAction(false)
	self:cancelCurrentPose()
	self:endStandOff()

	if self.twitchSound then
		self.twitchSound:Destroy()
		self.twitchSound = nil
	end

	self.agent:SetAttribute("KillTimer", nil)
end

function standingOffState:endStandOff()
	self:setTwitching(false)
	self:fireClientEvent("end")
end

function standingOffState:update(deltaTime: number)
	local controller = self.controller
	local standingOffConfig = self.config.standingOff
	local currentTarget = self.currentTarget
	local targetCache = controller.targeting:updateTargetCache(currentTarget)

	if not targetCache or controller.targeting:isTargetDead(currentTarget) then
		controller.stateMachine:change(controller.states.Running)
		return
	end

	local isStaring = targetCache:GetAttribute("Staring")

	if isStaring then
		self.stareTimer = self.stareTimer - deltaTime
		self.killTimer = math.clamp(self.killTimer + deltaTime, 0, standingOffConfig.deathTimerSeconds)
	else
		self.killTimer = self.killTimer - deltaTime
	end

	self.agent:SetAttribute("KillTimer", self.killTimer)
	self:setTwitching(isStaring)
	controller:turnToward(currentTarget.root.Position)

	if self.stareTimer <= 0 then
		self:swapPose()
		self.remainingSwaps = self.remainingSwaps - 1
	end

	if self.remainingSwaps <= 0 then
		self:endStandOff()
		controller.stateMachine:change(controller.states.Running)
		return
	end

	if self.killTimer <= 0 then
		self.didFail = true
		controller.stateMachine:change(controller.states.Focusing, {
			ignoreFoliage = true,
			skipWaiting = true,
			afterStandOff = true,
			timeScale = 2,
		})
	end
end

function standingOffState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(standingOffState, controller, extraInfo)

	local safeExtraInfo = extraInfo or {}
	local standingOffConfig = self.config.standingOff

	self.currentTarget = safeExtraInfo.target
	self.player = self.currentTarget and controller.targeting:getPlayerFromTarget(self.currentTarget) or nil
	self.randomGenerator = controller.randomGenerator

	self.currentPoseTrack = nil
	self.twitchSound = nil
	self.didFail = false

	self.stareTimer = 0
	self.killTimer = 0
	self.remainingSwaps = math.random(standingOffConfig.swapAmountMinimum, standingOffConfig.swapAmountMaximum)

	return self
end

return standingOffState
