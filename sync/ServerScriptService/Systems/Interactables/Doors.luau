local serverStorage = game:GetService("ServerStorage")

local serverUtilities = serverStorage.ServerUtilities
local soundEvents = require(serverUtilities.SoundEvents)

local doorsMainController = {}
doorsMainController.__index = doorsMainController
doorsMainController.activeDoors = {}

function doorsMainController:createNewDoorState()
	return {
		doorSpring = nil,
		doorModel = nil,
		pivotDriver = nil,
		closedPivot = nil,
		targetPivot = nil,
		connections = {},
	}
end

function doorsMainController:preload()
	local instance = self.instance
	local doorClass = instance:GetAttribute("DoorClass")

	local foundController = script:FindFirstChild(doorClass)
	foundController = foundController and require(foundController)

	if foundController ~= nil then
		self.attributes = instance:GetAttributes()
		self.mainController = foundController.new(self)
	end

	if self.ambiencePart and not self.attributes.Open then
		self.ambiencePart:AddTag("Disabled")
	end
end

function doorsMainController:canPlayerActuate(player: Player, wantsToOpen: boolean): (boolean, BasePart?)
	local doorInstance = self.instance
	local doorAttributes = self.attributes

	if self.mainController == nil or doorAttributes == nil or doorInstance.Parent == nil then
		return false, nil
	end

	if wantsToOpen and doorAttributes.Locked == true then
		return false, nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return false, nil
	end

	local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false, nil
	end

	local maximumDistanceStuds = self.prompt.MaxActivationDistance + 8
	local distanceStuds = (rootPart.Position - doorInstance:GetPivot().Position).Magnitude
	if distanceStuds > maximumDistanceStuds then
		return false, nil
	end

	return true, rootPart
end

function doorsMainController:init()
	self:preload()

	self.connections.promptActivated = self.prompt.Triggered:Connect(function(player: Player)
		local newState = not self.attributes.Open
		local canActuate, rootPart = self:canPlayerActuate(player, newState)

		if canActuate and rootPart ~= nil then
			self:setState(rootPart, newState)

			self.instance:SetAttribute("Open", newState)
		end
	end)

	self.connections.onAttributeChanged = self.instance.AttributeChanged:Connect(function(attributeName: string)
		local attributeState = self.instance:GetAttribute(attributeName)
		self.attributes[attributeName] = attributeState

		if attributeName == "Open" and self.mainController.currentState ~= attributeState then
			self:setState()
		end
	end)
end

function doorsMainController.new(info)
	local self = setmetatable({}, doorsMainController)

	self.info = info
	self.instance = self.info.instance
	self.ambiencePart = self.instance:FindFirstChild("AmbienceMimicPart")
	self.children = self.instance:GetChildren()
	self.prompt = self.info.prompt

	self.mainController = nil
	self.connections = {}

	doorsMainController.activeDoors[self.instance] = self

	task.spawn(self.init, self)

	return self
end

function doorsMainController:setState(
	rootPart: BasePart?,
	forcedState: boolean?,
	toggleSpeed: number?,
	soundNameOverride: string?,
	triggerSoundEvent: boolean?
)
	if triggerSoundEvent == nil then
		triggerSoundEvent = true
	end

	if forcedState ~= nil then
		self.attributes.Open = forcedState
	end

	self.mainController:updateDoor(rootPart, toggleSpeed, soundNameOverride)

	for _, part in self.children do
		if not part:IsA("BasePart") or not part:HasTag("IsDoorPart") then
			continue
		end

		part.CanCollide = not self.attributes.Open
		part.CanQuery = part.CanCollide
	end

	if triggerSoundEvent then
		soundEvents.createEvent({
			position = self.instance:GetPivot().Position,
			radius = 35,
			loudness = 0.5,
			tag = "door",
		})
	end

	if self.ambiencePart then
		if self.attributes.Open then
			self.ambiencePart:RemoveTag("Disabled")
		else
			self.ambiencePart:AddTag("Disabled")
		end
	end
end

function doorsMainController:destroy()
	doorsMainController.activeDoors[self.instance] = nil

	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end
end

return doorsMainController
