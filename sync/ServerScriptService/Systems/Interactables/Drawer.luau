local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local spring = require(replicatedStorage.SharedClasses.Spring)
local audioUtils = require(replicatedStorage.SharedUtilities.AudioUtils)
local interactableMotion = require(replicatedStorage.SharedUtilities.InteractableMotion)

local drawerSoundsFolder = replicatedStorage.SharedAssets.Effects.Sounds.Interaction.Drawer

local settledDistanceThreshold = interactableMotion.thresholds.slideSettledDistance
local settledVelocityThreshold = interactableMotion.thresholds.slideSettledVelocity

local drawerController = {}
drawerController.__index = drawerController

export type newInfo = {
	instance: Model,
	prompt: ProximityPrompt,
	promptHolder: Instance,
}

local function disconnectConnection(connections: { [string]: RBXScriptConnection? }, key: string)
	local connection = connections[key]
	if connection then
		connection:Disconnect()
		connections[key] = nil
	end
end

function drawerController:getCurrentDistance(): number
	local drawer = self.drawer
	local closedPivot = self.closedPivot
	if not drawer or not closedPivot then
		return 0
	end

	local localOffset = closedPivot:ToObjectSpace(drawer:GetPivot())
	return -localOffset.Z
end

function drawerController:applyDistance(distance: number)
	local drawer = self.drawer
	local closedPivot = self.closedPivot
	if not drawer or not closedPivot then
		return
	end

	drawer:PivotTo(closedPivot * CFrame.new(0, 0, -distance))
end

function drawerController:ensureSpringConnection()
	local connections = self.connections
	if connections.drawerSpringStep then
		return
	end

	connections.drawerSpringStep = runService.Heartbeat:Connect(function(deltaTime)
		local activeSpring = self.drawerSpring
		if not activeSpring then
			return
		end

		local currentDistance = activeSpring:update(deltaTime).X
		self:applyDistance(currentDistance)

		local targetDistance = activeSpring.target.X
		local isSettled = math.abs(targetDistance - currentDistance) <= settledDistanceThreshold
			and math.abs(activeSpring.velocity.X) <= settledVelocityThreshold

		if not isSettled then
			return
		end

		activeSpring.position = Vector2.new(targetDistance, 0)
		activeSpring.velocity = Vector2.zero
		self:applyDistance(targetDistance)
	end)
end

function drawerController:cacheDrawer()
	local instance = self.instance
	local drawer = instance:FindFirstChild("Drawer")
	if not drawer then
		return
	end

	self.drawer = drawer
	self.closedPivot = drawer:GetPivot()
	self.openDistance = self.attributes.OpenDistance or 1
	self:syncReplicatedMotion()
end

function drawerController:syncReplicatedMotion()
	interactableMotion.publishState(self.instance, {
		mode = interactableMotion.modes.slide,
		targetYaw = nil,
		targetYaw1 = nil,
		targetYaw2 = nil,
		targetDistance = self.attributes.Open and self.openDistance or 0,
		speedOverride = nil,
	})
end

function drawerController:setState(isOpen: boolean)
	local instance = self.instance
	local attributes = self.attributes

	if attributes.Open == isOpen or (isOpen == true and attributes.Locked == true) then
		return false
	end

	local drawer = self.drawer
	if not drawer then
		return false
	end

	instance:SetAttribute("Open", isOpen)
	attributes.Open = isOpen

	audioUtils.playSound({
		sound = isOpen and drawerSoundsFolder.DrawerOpen or drawerSoundsFolder.DrawerClose,
		volume = 1,
		parent = drawer:IsA("BasePart") and drawer or drawer:FindFirstChildOfClass("BasePart"),
	})

	local targetDistance = isOpen and self.openDistance or 0
	if interactableMotion.animateOnClient then
		self:syncReplicatedMotion()
	else
		local currentDistance = self:getCurrentDistance()
		local springSettings = interactableMotion.getDrawerSpringSettings(isOpen)
		local activeSpring = self.drawerSpring
		if not activeSpring then
			activeSpring = spring.new(
				Vector2.new(currentDistance, 0),
				springSettings.mass,
				springSettings.force,
				springSettings.damping,
				springSettings.speed
			)
			self.drawerSpring = activeSpring
			self:ensureSpringConnection()
		else
			activeSpring.position = Vector2.new(currentDistance, 0)
		end

		activeSpring.mass = springSettings.mass
		activeSpring.force = springSettings.force
		activeSpring.damping = springSettings.damping
		activeSpring.speed = springSettings.speed
		activeSpring.target = Vector2.new(targetDistance, 0)
	end

	return true
end

function drawerController:updatePromptType()
	local prompt = self.prompt
	local attributes = self.attributes

	if attributes.Locked == true then
		prompt:SetAttribute("PromptType", "Locked")
	else
		prompt:SetAttribute("PromptType", "Interact")
	end
end

function drawerController:init()
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
		elseif attributeName == "OpenDistance" then
			self:cacheDrawer()
		end
	end)

	connections.promptActivated = prompt.Triggered:Connect(function()
		self:setState(not self.attributes.Open)
	end)

	connections.instanceDestroyed = instance.Destroying:Once(function()
		self:destroy()
	end)

	task.defer(self.cacheDrawer, self)
end

function drawerController.new(info: newInfo)
	local self = setmetatable({}, drawerController)

	self.connections = {}
	self.instance = info.instance
	self.prompt = info.prompt
	self.promptHolder = info.promptHolder

	task.defer(self.init, self)

	return self
end

function drawerController:destroy()
	self.drawerSpring = nil
	disconnectConnection(self.connections, "drawerSpringStep")

	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
end

return drawerController
