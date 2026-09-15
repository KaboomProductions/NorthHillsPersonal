local doubleDoorController = {}
doubleDoorController.__index = doubleDoorController
doubleDoorController.__vars = {
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

function doubleDoorController:cacheDoor()
	self.door1 = self.instance:FindFirstChild("Door1")
	self.door2 = self.instance:FindFirstChild("Door2")

	self.primaryPart = self.instance.PrimaryPart or self.instance:FindFirstChild("DoorFrame")

	if not interactableMotion.animateOnClient then
		self.door1State.pivotDriver = pivotDoorController.createPivotDriver(self.door1)
		self.door2State.pivotDriver = pivotDoorController.createPivotDriver(self.door2)
	end

	self.door1State.closedPivot = self.door1:GetPivot()
	self.door2State.closedPivot = self.door2:GetPivot()

	self.door1OpenPivot = self.door1State.closedPivot * CFrame.Angles(0, math.rad(self.openAngle), 0)
	self.door2OpenPivot = self.door2State.closedPivot * CFrame.Angles(0, math.rad(-self.openAngle), 0)

	self:syncReplicatedMotion()
end

function doubleDoorController:preload()
	self.openAngle = self.attributes.OpenAngle or interactableMotion.door.stateValues.defaultOpenAngle
	self:cacheDoor()
end

function doubleDoorController:init()
	self:preload()
end

function doubleDoorController.new(ancestorInfo)
	local self = setmetatable({}, doubleDoorController)

	self.ancestor = ancestorInfo
	self.instance = self.ancestor.instance
	self.attributes = self.ancestor.attributes

	self.__vars = table.clone(doubleDoorController.__vars)
	self.connections = self.ancestor.connections

	self.door1State = self.ancestor:createNewDoorState()
	self.door2State = self.ancestor:createNewDoorState()

	task.spawn(self.init, self)

	return self
end

function doubleDoorController:getSharedDirection(originPart: BasePart): number
	local center = self.instance:GetPivot().Position
	local toPlayer = (originPart.Position - center)
	toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)

	if vector.magnitude(toPlayer) <= 1e-6 then
		return 1
	end

	local forward = self.door1State.closedPivot.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z).Unit

	local direction = toPlayer.Unit
	local dot = forward:Dot(direction)

	return dot >= 0 and -1 or 1
end

function doubleDoorController:getOpenPivots(originPart: BasePart): (CFrame, CFrame)
	local direction = self:getSharedDirection(originPart)
	local angle = self.openAngle

	local open1 = self.door1State.closedPivot * CFrame.Angles(0, math.rad(angle * direction), 0)
	local open2 = self.door2State.closedPivot * CFrame.Angles(0, math.rad(-angle * direction), 0)

	return open1, open2
end

function doubleDoorController:getSpringSettings(isOpen: boolean)
	return interactableMotion.getDoorSpringSettings(isOpen, self.attributes.DoorType)
end

function doubleDoorController:syncReplicatedMotion(speedOverride: number?)
	local targetPivot1 = self.attributes.Open and (self.currentTargetPivot1 or self.door1OpenPivot) or self.door1State.closedPivot
	local targetPivot2 = self.attributes.Open and (self.currentTargetPivot2 or self.door2OpenPivot) or self.door2State.closedPivot
	if targetPivot1 == nil or targetPivot2 == nil then
		return
	end

	interactableMotion.publishState(self.instance, {
		mode = interactableMotion.modes.doublePivot,
		targetYaw = nil,
		targetYaw1 = interactableMotion.getRelativeYaw(self.door1State.closedPivot, targetPivot1),
		targetYaw2 = interactableMotion.getRelativeYaw(self.door2State.closedPivot, targetPivot2),
		targetDistance = nil,
		speedOverride = speedOverride,
	})
end

function doubleDoorController:updateDoor(originPart: BasePart?, toggleSpeed: number?, soundNameOverride: string?)
	local doorType = self.instance:GetAttribute("DoorType")
	local soundDirectory = doorSounds:FindFirstChild(doorType)

	local isOpen = self.attributes.Open
	local openPivot1, openPivot2
	local springSettings = self:getSpringSettings(isOpen)

	if isOpen and originPart then
		openPivot1, openPivot2 = self:getOpenPivots(originPart)
	elseif isOpen then
		openPivot1 = self.currentTargetPivot1 or self.door1OpenPivot
		openPivot2 = self.currentTargetPivot2 or self.door2OpenPivot
	else
		openPivot1 = self.door1State.closedPivot
		openPivot2 = self.door2State.closedPivot
	end

	if toggleSpeed ~= nil then
		springSettings.speed = toggleSpeed
	end

	self.currentState = isOpen
	self.currentTargetPivot1 = openPivot1
	self.currentTargetPivot2 = openPivot2

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

	pivotDoorController.springPivot(
		self.door1State,
		self.door1,
		self.door1State.pivotDriver,
		self.door1State.closedPivot,
		openPivot1,
		springSettings
	)

	pivotDoorController.springPivot(
		self.door2State,
		self.door2,
		self.door2State.pivotDriver,
		self.door2State.closedPivot,
		openPivot2,
		springSettings
	)

	return true
end

return doubleDoorController
