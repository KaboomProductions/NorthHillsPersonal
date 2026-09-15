local defaultDoorController = {}
defaultDoorController.__index = defaultDoorController
defaultDoorController.__vars = {
	stateValues = {
		defaultOpenAngle = 95,
		smashOpenVelocity = 18,
		smashOpenDirectionThreshold = 0.55,
		smashOpenMoveThreshold = 0.25,
		smashCooldownSeconds = 0.35,
		smashImpulseScale = 0.035,
		smashImpulseMin = 10,
		smashImpulseMax = 20,
		metalSpringMass = 17,
	},

	springSettingsOpen = {
		mass = 15,
		force = 100,
		damping = 4,
		speed = 2,
	},

	springSettingsClose = {
		mass = 15,
		force = 100,
		damping = 4,
		speed = 2,
	},
}

local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local effects = sharedAssets.Effects
local sounds = effects.Sounds

local interactionSounds = sounds.Interaction
local doorSounds = interactionSounds.Door

local mainDoorController = script.Parent
local pivotDoorController = require(mainDoorController.Parent.PivotDoor)
local audioUtilities = require(sharedUtilities.AudioUtils)
local interactableMotion = require(sharedUtilities.InteractableMotion)

function defaultDoorController:cacheDoor()
	self.door = self.instance:FindFirstChild("Door")
	self.primaryPart = self.instance.PrimaryPart or self.instance:FindFirstChild("DoorFrame")
	if not interactableMotion.animateOnClient then
		self.pivotDriver = pivotDoorController.createPivotDriver(self.door)
	end

	self.closedPivot = self.door:GetPivot()
	self.openPivot = self.closedPivot
		* CFrame.Angles(0, math.rad(self.attributes.OpenAngle or interactableMotion.door.stateValues.defaultOpenAngle), 0)

	self:syncReplicatedMotion()
end

function defaultDoorController:preload()
	self:cacheDoor()
end

function defaultDoorController:init()
	self:preload()
end

function defaultDoorController.new(ancestorInfo)
	local self = setmetatable({}, defaultDoorController)

	self.ancestor = ancestorInfo
	self.instance = self.ancestor.instance
	self.attributes = self.ancestor.attributes

	self.__vars = table.clone(defaultDoorController.__vars)
	self.connections = self.ancestor.connections

	task.spawn(self.init, self)

	return self
end

function defaultDoorController:getOpenPivot(originPart: BasePart): CFrame
	local closedPivot = self.closedPivot
	local openAngle = self.attributes.OpenAngle or interactableMotion.door.stateValues.defaultOpenAngle

	local toPlayer = originPart.Position - closedPivot.Position
	toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)

	if toPlayer:Dot(toPlayer) <= 1e-6 then
		return self.openPivot
	end

	local playerDirection = toPlayer.Unit
	local side = closedPivot.LookVector:Dot(playerDirection)
	local direction = side >= 0 and -1 or 1

	return closedPivot * CFrame.Angles(0, math.rad(openAngle * direction), 0)
end

function defaultDoorController:getSpringSettings(isOpen: boolean)
	return interactableMotion.getDoorSpringSettings(isOpen, self.attributes.DoorType)
end

function defaultDoorController:syncReplicatedMotion(speedOverride: number?)
	local targetPivot = self.attributes.Open and (self.currentTargetPivot or self.openPivot) or self.closedPivot
	if targetPivot == nil or self.closedPivot == nil then
		return
	end

	interactableMotion.publishState(self.instance, {
		mode = interactableMotion.modes.singlePivot,
		targetYaw = interactableMotion.getRelativeYaw(self.closedPivot, targetPivot),
		targetYaw1 = nil,
		targetYaw2 = nil,
		targetDistance = nil,
		speedOverride = speedOverride,
	})
end

function defaultDoorController:updateDoor(originPart: BasePart?, toggleSpeed: number?, soundNameOverride: string?)
	local attributes = self.attributes
	local targetPivot = self.closedPivot

	local doorType = self.instance:GetAttribute("DoorType")
	local soundDirectory = doorSounds:FindFirstChild(doorType)

	local isOpen = attributes.Open
	local shouldUpdate = true
	local springSettings = self:getSpringSettings(isOpen)

	if isOpen then
		targetPivot = originPart and self:getOpenPivot(originPart) or self.openPivot
	end

	if self.currentState == isOpen and self.currentTargetPivot then
		local lookDelta = self.currentTargetPivot.LookVector:Dot(targetPivot.LookVector)
		shouldUpdate = lookDelta < 0.999
	end

	if not shouldUpdate then
		return false
	end

	if toggleSpeed ~= nil then
		springSettings.speed = toggleSpeed
	end

	self.currentState = isOpen
	self.currentTargetPivot = targetPivot

	local soundToPlay = nil
	if soundDirectory ~= nil then
		if soundNameOverride ~= nil then
			soundToPlay = soundDirectory:FindFirstChild(soundNameOverride)
		end

		if soundToPlay == nil then
			soundToPlay = self.currentState and soundDirectory:FindFirstChild("DoorOpen")
				or soundDirectory:FindFirstChild("DoorClose")
		end
	end

	audioUtilities.playSound({
		sound = soundToPlay,
		parent = self.primaryPart,
	})

	if interactableMotion.animateOnClient then
		self:syncReplicatedMotion(toggleSpeed)
		return true
	end

	pivotDoorController.springPivot(self, self.door, self.pivotDriver, self.closedPivot, targetPivot, springSettings)

	return true
end

return defaultDoorController
