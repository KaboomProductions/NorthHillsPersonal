local replicatedStorage = game:GetService("ReplicatedStorage")
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)

local stunController = {}
stunController.__index = stunController

function stunController:recover()
	self.agent:SetAttribute("Stunned", false)
	self.agent:SetAttribute("Blocking", false)
	self.controller.speedController:clearLock("stunned")
	self.controller.speedController:clearLock("blocked")
	self.controller:toggleIKControl(true)
	self.controller:setCanAttack(true)
end

function stunController:disconnectThread()
	if self.recoveryThread then
		task.cancel(self.recoveryThread)
		self.recoveryThread = nil
		self:recover()
	end
end

function stunController:triggerStun(isHeavyAttack: boolean?)
	self:disconnectThread()

	self.availableTracks = isHeavyAttack and self.majorStunTracks or self.minorStunTracks
	self.currentTrack = self.availableTracks[self.instance.trackIndex]

	if self.currentTrack then
		self.controller:stopTraversal()
		self.controller:toggleIKControl(false)
		self.controller:setOrientationEnabled(false)

		if isHeavyAttack then
			self.agent:SetAttribute("Stunned", true)

			audioUtilities.playSound({
				sound = self.meleePainSounds[math.random(1, #self.meleePainSounds)],
				parent = self.rootPart,
			})
		else
			self.controller.speedController:setLock("stunned", true)
			self.humanoid.WalkSpeed = 4
		end

		local playbackSpeed = math.random(90, 110) / 100
		self.currentTrack:Play(0.25, 5, playbackSpeed)

		self.recoveryThread = task.delay(self.currentTrack.Length / playbackSpeed, function()
			self.recoveryThread = nil
			self:recover()
		end)
	end
end

function stunController:triggerBlock()
	self:disconnectThread()

	self.currentTrack = self.blockTracks[self.instance.trackIndex]

	if self.currentTrack then
		self.currentTrack:Play(0, 5, 1.5)

		self.agent:SetAttribute("Blocking", true)

		audioUtilities.playSound({
			sound = self.deflectSounds[math.random(1, #self.deflectSounds)],
			parent = self.rootPart,
			useAcousticSimulation = false,
			playbackSpeed = math.random(900, 1100) / 1000,
		})

		self.controller.speedController:setLock("blocked", true)
		self.humanoid.WalkSpeed = 11

		self.recoveryThread = task.delay(self.currentTrack.Length, function()
			self.recoveryThread = nil
			self:recover()
		end)
	end
end

function stunController.new(parentInstance: any)
	local self = setmetatable({}, stunController)

	self.instance = parentInstance
	self.controller = self.instance.controller
	self.agent = self.instance.agent
	self.humanoid = self.instance.humanoid
	self.rootPart = self.instance.rootPart

	self.tracks = self.instance.tracks
	self.minorStunTracks = self.tracks.minorStun
	self.majorStunTracks = self.tracks.majorStun
	self.blockTracks = self.tracks.block

	self.sounds = self.instance.sounds
	self.meleePainSounds = self.sounds.Pain.Melee:GetChildren()
	self.deflectSounds = self.sounds.Deflects:GetChildren()

	return self
end

return stunController
