local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local baseState = require(serverStorage.ServerAssets.AI.StateMachine.StateMachine.BaseState)

local screamingState = baseState.extend("Screaming")

function screamingState:enter()
	local controller = self.controller
	local humanoid = self.humanoid

	local screamTracks = self.tracks.scream
	local mainTrack = self.runAndScream and screamTracks.moving or screamTracks.stationary

	self.agent:SetAttribute("Screaming", true)
	controller:setFlag("hasScreamedThisChase", true)
	controller:setMidAction(true)
	controller:setCanStun(false)

	controller.speedController:setLock("screaming", true)
	humanoid.WalkSpeed = 0

	self.pathfinder:Stop()

	humanoid:MoveTo(self.rootPart.Position)

	mainTrack:Play(0.1)
	self.activeTrack = mainTrack

	for _, sound in self.sounds.Scream:GetChildren() do
		mainTrack:GetMarkerReachedSignal(sound.Name):Once(function()
			audioUtilities.playSound({
				sound = sound,
				parent = self.rootPart,
				useAcousticSimulation = false,
			})
		end)
	end

	if not self.runAndScream then
		repeat
			task.wait()
		until not mainTrack.IsPlaying
	end

	controller.stateMachine:change(controller.states.Running)
end

function screamingState:update(_deltaTime: number)
	local controller = self.controller
	local nearestTarget = controller.targeting:getNearestTarget({
		range = self.config.shared.ranges.run,
		canRaycast = false,
	})

	controller:setOrientationEnabled(nearestTarget ~= nil)

	if nearestTarget then
		controller:turnToward(nearestTarget.root.Position)
	end
end

function screamingState:exit()
	if self.activeTrack and not self.runAndScream then
		self.activeTrack:Stop(0.1)
	end

	self.controller.speedController:clearLock("screaming")
	self.agent:SetAttribute("Screaming", false)
	self.controller:setMidAction(false)
	self.controller:setCanStun(true)
end

function screamingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(screamingState, controller, extraInfo)

	self.activeTrack = nil

	local safeExtraInfo = extraInfo or {}
	self.runAndScream = safeExtraInfo.runAndScream

	return self
end

return screamingState
