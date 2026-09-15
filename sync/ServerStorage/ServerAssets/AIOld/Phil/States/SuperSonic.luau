local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local baseState = require(serverStorage.ServerAssets.AI.BaseState)
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local networking = require(replicatedStorage.Communication.Networking)

local superSonicState = baseState.extend("SuperSonic")
local updateRate = 0.05

function superSonicState:performScream()
	local controller = self.controller
	local sharedConfig = self.sharedConfig
	local targetingController = controller.targeting

	self.isScreaming = true

	audioUtilities.playSound({
		sound = self.sounds.SuperSonic.Commit,
		parent = self.rootPart,
		useAcousticSimulation = false,
	})

	task.spawn(function()
		while self.isScreaming do
			task.wait(1 / 10)

			local now = os.clock()
			self.nextScreamUpdate = self.nextScreamUpdate or updateRate

			if os.clock() < self.nextScreamUpdate then
				return
			end

			self.nextScreamUpdate = now + updateRate

			local targetsInRange = targetingController:getAllTargetsInRange({
				range = sharedConfig.ranges.superSonic,
				canRaycast = true,
			})

			local currentlyInRange = {}

			for _, targetData in targetsInRange do
				local player = targetData.player
				if not player then
					continue
				end

				currentlyInRange[player] = true

				if not self.targetsInRangeLastFrame[player] then
					self.targetsInRangeLastFrame[player] = true
					networking.events.ai:FireClient(player, "superSonic", "start")
				end
			end

			for player in pairs(self.targetsInRangeLastFrame) do
				if not currentlyInRange[player] then
					networking.events.ai:FireClient(player, "superSonic", "end")
				end
			end

			self.targetsInRangeLastFrame = currentlyInRange
		end
	end)
end

function superSonicState:cancelScream()
	self.isScreaming = false
	networking.events.ai:FireAllClients("superSonic", "end")
end

function superSonicState:enter()
	local tracks = self.tracks
	local superSonicTrack = tracks.superSonic.main

	local controller = self.controller
	local humanoid = self.humanoid

	controller:setMidAction(true)
	controller:setCanStun(false)

	controller:setOrientationEnabled(true)
	controller:recordActionTime("superSonic")
	controller:stopTraversal()
	controller.speedController:setLock("superSonic", true)

	audioUtilities.playSound({
		sound = self.sounds.SuperSonic.Charge,
		parent = self.rootPart,
		useAcousticSimulation = false,
	})

	humanoid.WalkSpeed = 0
	superSonicTrack:Play()

	self.connections.screamStart = superSonicTrack:GetMarkerReachedSignal("Start"):Once(function()
		self:performScream()
	end)

	self.connections.screamEnd = superSonicTrack:GetMarkerReachedSignal("End"):Once(function()
		self:cancelScream()
	end)

	self.connections.superSonicEnded = superSonicTrack.Ended:Once(function()
		superSonicTrack:Stop()

		controller:setOrientationEnabled(false)
		controller:setMidAction(false)
		controller:setCanStun(true)

		controller.speedController:clearLock("superSonic")

		controller.stateMachine:change(controller.states.Running)
	end)
end

function superSonicState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(superSonicState, controller, extraInfo)

	self.targetsInRangeLastFrame = {}
	self.sharedConfig = self.config.shared

	return self
end

function superSonicState:update(_deltaTime)
	local nearestTarget = self.controller.targeting:getNearestTarget({
		range = self.sharedConfig.ranges.run,
		canRaycast = false,
	})

	if nearestTarget ~= nil then
		self.controller:turnToward(nearestTarget.root.Position)
	end
end

return superSonicState
