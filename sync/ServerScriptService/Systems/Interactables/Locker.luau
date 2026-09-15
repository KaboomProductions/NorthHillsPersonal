local replicatedStorage = game:GetService("ReplicatedStorage")

local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local interactableMotion = require(replicatedStorage.SharedUtilities.InteractableMotion)
local pivotDoor = require(script.Parent.PivotDoor)
local config = require(script.Config)

local sharedAssets = replicatedStorage.SharedAssets
local effectsFolder = sharedAssets.Effects
local soundsFolder = effectsFolder.Sounds
local interactionSoundsFolder = soundsFolder.Interaction
local lockerSoundsFolder = interactionSoundsFolder.Locker

local lockerController = {}
lockerController.__index = lockerController
lockerController.__vars = config.stateValues

export type newInfo = {
	instance: Model,
	prompt: ProximityPrompt,
	promptHolder: Instance,
}

function lockerController:cacheDoor()
	local instance = self.instance
	local door = instance:FindFirstChild("LockerDoor")
	if not door then
		return
	end

	local existingPivotDriver = self.pivotDriver
	if existingPivotDriver then
		pivotDoor.stopSpring(self)
		existingPivotDriver:Destroy()
	end

	self.door = door
	self.pivotDriver = nil
	if not interactableMotion.animateOnClient then
		self.pivotDriver = pivotDoor.createPivotDriver(door)
	end

	local closedPivot = door:GetPivot()
	self.closedPivot = closedPivot
	self.openPivot = closedPivot * CFrame.Angles(0, math.rad(self.attributes.OpenAngle), 0)
	self:syncReplicatedMotion()
end

function lockerController:syncReplicatedMotion()
	local closedPivot = self.closedPivot
	local targetPivot = self.attributes.Open and self.openPivot or closedPivot
	if closedPivot == nil or targetPivot == nil then
		return
	end

	interactableMotion.publishState(self.instance, {
		mode = interactableMotion.modes.singlePivot,
		targetYaw = interactableMotion.getRelativeYaw(closedPivot, targetPivot),
		targetYaw1 = nil,
		targetYaw2 = nil,
		targetDistance = nil,
		speedOverride = nil,
	})
end

function lockerController:isRightSideBlocked(): boolean
	local instance = self.instance
	local stateValues = self.__vars
	local lockerBody = instance:FindFirstChild("LockerBody") or instance.PrimaryPart
	if not lockerBody then
		return false
	end

	local rayOrigin = lockerBody.Position
	local rayDirection = lockerBody.CFrame.RightVector * 2

	local raycastParams = self.raycastParams
	raycastParams.FilterDescendantsInstances = { instance }

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if not raycastResult or not raycastResult.Instance then
		return false
	end

	local hitModel = raycastResult.Instance:FindFirstAncestorWhichIsA("Model")
	if not hitModel then
		return false
	end

	local isOpen = hitModel:GetAttribute("Open")
	local openAngle = hitModel:GetAttribute("OpenAngle")
	if isOpen == nil or openAngle == nil then
		return false
	end

	return isOpen == true and tonumber(openAngle) > stateValues.minimumBlockedAngle
end

function lockerController:setState(isOpen: boolean)
	local instance = self.instance
	local attributes = self.attributes

	if attributes.Open == isOpen or (isOpen == true and attributes.Locked == true) then
		return false
	end

	if self:isRightSideBlocked() then
		return false
	end

	local door = self.door
	if not door then
		return false
	end

	instance:SetAttribute("Open", isOpen)
	attributes.Open = isOpen

	local pivotDriverValue = self.pivotDriver
	local targetPivot = isOpen and self.openPivot or self.closedPivot
	if not targetPivot then
		return false
	end

	if interactableMotion.animateOnClient then
		self:syncReplicatedMotion()
	elseif not pivotDriverValue then
		return false
	end

	if not interactableMotion.animateOnClient then
		pivotDoor.springPivot(
			self,
			door,
			pivotDriverValue,
			self.closedPivot,
			targetPivot,
			interactableMotion.getLockerSpringSettings(isOpen)
		)
	end

	audioUtilities.playSound({
		sound = isOpen and lockerSoundsFolder.LockerOpen or lockerSoundsFolder.LockerClose,
		volume = 1,
		parent = instance:FindFirstChild("LockerBody"),
	})

	return true
end

function lockerController:updatePromptType()
	local prompt = self.prompt
	local attributes = self.attributes

	if attributes.Locked == true then
		prompt:SetAttribute("PromptType", "Locked")
	else
		prompt:SetAttribute("PromptType", "Interact")
	end
end

function lockerController:init()
	local instance = self.instance
	local prompt = self.prompt
	local connections = self.connections

	instance:SetAttribute("Open", false)
	self.attributes = instance:GetAttributes()

	self:updatePromptType()

	connections.attributesChanged = instance.AttributeChanged:Connect(function(attributeName)
		self.attributes[attributeName] = instance:GetAttribute(attributeName)

		if attributeName == "Locked" then
			self:updatePromptType()
		elseif attributeName == "OpenAngle" then
			self:cacheDoor()
		end
	end)

	connections.promptActivated = prompt.Triggered:Connect(function()
		self:setState(not self.attributes.Open)
	end)

	connections.instanceDestroyed = instance.Destroying:Once(function()
		self:destroy()
	end)

	task.defer(self.cacheDoor, self)
end

function lockerController.new(info: newInfo)
	local self = setmetatable({}, lockerController)

	self.__vars = table.clone(lockerController.__vars)
	self.connections = {}
	self.instance = info.instance
	self.prompt = info.prompt
	self.promptHolder = info.promptHolder

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	self.raycastParams = raycastParams

	task.defer(self.init, self)

	return self
end

function lockerController:destroy()
	pivotDoor.stopSpring(self)

	local connections = self.connections
	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	pivotDoor.destroyDriver(self.pivotDriver)
	self.pivotDriver = nil

	table.clear(connections)
end

return lockerController
