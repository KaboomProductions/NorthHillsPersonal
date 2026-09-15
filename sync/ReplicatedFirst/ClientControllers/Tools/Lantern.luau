local lanternController = {}
lanternController.__index = lanternController

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")

local player = players.LocalPlayer

local sharedUtilities = replicatedStorage.SharedUtilities
local clientUtilities = replicatedFirst.ClientUtilities
local sharedAssets = replicatedStorage.SharedAssets

local animationUtilities = require(sharedUtilities.Animation)
local attributeConstants = require(sharedAssets.Attributes)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)
local inputActionService = require(sharedUtilities.InputActionService)
local inputHelpers = require(clientUtilities.InputHelpers)
local toolAttributes = attributeConstants.tool

local TRACK_TRANSITION_TIME_SECONDS = 0.05

function lanternController:bindCharacter()
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character and self.character:FindFirstChildOfClass("Humanoid")
	self.animator = self.humanoid and self.humanoid:WaitForChild("Animator", 5)
end

function lanternController:preload()
	self:bindCharacter()

	self.mainRemote = self.tool:WaitForChild("MainRemote", 3)
	for animationName, animationId in pairs(self.config.animations) do
		self.tracks[animationName] = animationUtilities.loadAnimationById(self.animator, animationId, false)
	end
end

function lanternController:stopTrack(track: AnimationTrack?, fadeTime: number?)
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.05)
	end
end

function lanternController:cancelAllTracks()
	for _, track in pairs(self.tracks) do
		track:Stop(0.1)
	end
end

function lanternController:stopTracksExcept(preservedTrack: AnimationTrack, fadeTime: number)
	for _, track in pairs(self.tracks) do
		if track ~= preservedTrack then
			self:stopTrack(track, fadeTime)
		end
	end
end

function lanternController:getUnequipDuration(): number
	local unequipTrack = self.tracks.unequip
	if unequipTrack == nil then
		return 0
	end

	local unequipDuration = animationUtilities.getTrackDuration(unequipTrack)
	if not unequipTrack.IsPlaying then
		return unequipDuration
	end

	return math.max(unequipDuration - unequipTrack.TimePosition, 0)
end

function lanternController:onMainEvent(event: string, info: { isServerReplication: boolean? })
	info = info or {}

	if event == "activate" then
		self:activate(info)
	end
end

function lanternController:init()
	self:preload()

	self.interface = player.PlayerGui:WaitForChild("Interface", 3)
	self.mobileFrame = self.interface.Mobile

	self.connections.onMainEvent = self.mainRemote.OnClientEvent:Connect(function(
		event: string,
		info: {
			isServerReplication: boolean,
			isHeavy: boolean?,
			chargeDepleted: boolean?,
		}
	)
		self:onMainEvent(event, info)
	end)

	self.mainRemote:FireServer("ready")
end

function lanternController.new(tool, config)
	local self = setmetatable({}, lanternController)

	self.tool = tool
	self.config = config

	self.tracks = {}
	self.connections = {}
	self.isUnequipping = false
	self.animationTransitionVersion = 0

	self:init()

	return self
end

function lanternController:toggleAtMarker()
	local toggleTrack = self.tool:GetAttribute(toolAttributes.toggled) and self.tracks.on or self.tracks.off
	if not toggleTrack then
		return
	end

	toggleTrack:GetMarkerReachedSignal("Toggle"):Once(function()
		if self.isEquipped then
			local activeHaptics = haptics.getActiveHaptics()
			if activeHaptics then
				activeHaptics:playToolToggle()
			end

			self.mainRemote:FireServer("activate")
		end
	end)

	toggleTrack:Play(0.1)
end

function lanternController:activate(info: { isServerReplication: boolean })
	if info.isServerReplication then
		return
	end

	local onTrack = self.tracks.on
	local offTrack = self.tracks.off
	local equipTrack = self.tracks.equip

	if onTrack.IsPlaying or offTrack.IsPlaying or equipTrack.IsPlaying or self.isUnequipping then
		return
	end

	self:toggleAtMarker()
end

function lanternController:_bindActivation()
	if self.activationBind then
		return
	end
	self.activationBind = inputActionService.new("toggleActivationLantern", Enum.InputActionType.Bool)
	inputHelpers.wireMobileButton(self.activationBind, self.mobileFrame.ActivateLantern, "ToggleLantern")
	self.activationBind.Activated:Connect(function(_active: Vector2 | Vector3 | boolean | number, pressed: boolean)
		if pressed then
			self:activate({})
		end
	end)
end

function lanternController:playIdleAfterEquip(equipTrack: AnimationTrack, transitionVersion: number)
	equipTrack.Stopped:Once(function()
		if self.animationTransitionVersion ~= transitionVersion or not self.isEquipped or self.isUnequipping then
			return
		end

		local idleTrack = self.tracks.idle
		if idleTrack and not idleTrack.IsPlaying then
			idleTrack:Play(TRACK_TRANSITION_TIME_SECONDS)
		end
	end)
end

function lanternController:beginUnequipAnimation()
	local unequipTrack = self.tracks.unequip
	if unequipTrack == nil then
		self:cancelAllTracks()
		self.isUnequipping = false
		return
	end

	if unequipTrack.IsPlaying then
		return
	end

	self.animationTransitionVersion += 1
	local transitionVersion = self.animationTransitionVersion
	unequipTrack.Stopped:Once(function()
		if self.animationTransitionVersion == transitionVersion and not self.isEquipped then
			self.isUnequipping = false
		end
	end)
	unequipTrack:Play(TRACK_TRANSITION_TIME_SECONDS)
	self:stopTracksExcept(unequipTrack, TRACK_TRANSITION_TIME_SECONDS)
end

function lanternController:equip()
	if self.isEquipped then
		return
	end

	self.isEquipped = true
	self.isUnequipping = false
	self.animationTransitionVersion += 1
	local transitionVersion = self.animationTransitionVersion

	local equipTrack = self.tracks.equip
	if equipTrack then
		self:playIdleAfterEquip(equipTrack, transitionVersion)
		equipTrack:Play(TRACK_TRANSITION_TIME_SECONDS)
		self:stopTracksExcept(equipTrack, TRACK_TRANSITION_TIME_SECONDS)
	elseif self.tracks.idle then
		self.tracks.idle:Play(TRACK_TRANSITION_TIME_SECONDS)
	end
	self:_bindActivation()
	inputHelpers.mobileButtonHolder.setVisible("ToggleLantern", true)

	task.spawn(function()
		task.wait(0.1)

		if self.isEquipped then
			self.mainRemote:FireServer("activateSilent")
		end
	end)
end

function lanternController:interruptEquip()
	self.isEquipped = false
	self.isUnequipping = true
	inputHelpers.mobileButtonHolder.setVisible("ToggleLantern", false)
	if self.activationBind then
		self.activationBind:Destroy()
		self.activationBind = nil
	end
	self:beginUnequipAnimation()
end

function lanternController:unequip(info: { skipAnimation: boolean? }?)
	info = info or {}

	self.isEquipped = false
	self.isUnequipping = true

	inputHelpers.mobileButtonHolder.setVisible("ToggleLantern", false)

	if self.activationBind then
		self.activationBind:Destroy()
		self.activationBind = nil
	end

	if self.tool:GetAttribute(toolAttributes.toggled) then
		self.mainRemote:FireServer("activateSilent")
	end

	if info and info.skipAnimation then
		self.animationTransitionVersion += 1
		self:cancelAllTracks()
		self.isUnequipping = false
		return
	end

	self:beginUnequipAnimation()
end

function lanternController:destroy()
	self.isEquipped = false
	self.isUnequipping = false
	self.animationTransitionVersion += 1
	self:cancelAllTracks()

	inputHelpers.mobileButtonHolder.setVisible("ToggleLantern", false)

	if self.activationBind then
		self.activationBind:Destroy()
		self.activationBind = nil
	end

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	setmetatable(self, nil)
end

return lanternController
