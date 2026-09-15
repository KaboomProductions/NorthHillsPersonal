local collectionService = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local spring = require(replicatedStorage.SharedClasses.Spring)
local interactableMotion = require(replicatedStorage.SharedUtilities.InteractableMotion)

local motionAttributes = interactableMotion.attributes
local motionThresholds = interactableMotion.thresholds
type PivotInstance = Model | BasePart

local function disconnectConnection(connections: { [string]: RBXScriptConnection? }, key: string)
	local connection = connections[key]
	if connection then
		connection:Disconnect()
		connections[key] = nil
	end
end

local function asPivotInstance(instance: Instance?): PivotInstance?
	if instance == nil then
		return nil
	end

	if instance:IsA("Model") then
		return instance
	end

	if instance:IsA("BasePart") then
		return instance
	end

	return nil
end

local function getNumericAttribute(instance: Instance, attributeName: string, defaultValue: number): number
	local attributeValue = instance:GetAttribute(attributeName)
	if type(attributeValue) == "number" then
		return attributeValue
	end

	return defaultValue
end

local function getOptionalNumericAttribute(instance: Instance, attributeName: string): number?
	local attributeValue = instance:GetAttribute(attributeName)
	if type(attributeValue) == "number" then
		return attributeValue
	end

	return nil
end

local function getStringAttribute(instance: Instance, attributeName: string): string?
	local attributeValue = instance:GetAttribute(attributeName)
	if type(attributeValue) == "string" then
		return attributeValue
	end

	return nil
end

local function applyPivotFromYaw(state, yaw: number)
	if state.model == nil or state.closedPivot == nil then
		return
	end

	state.model:PivotTo(state.closedPivot * CFrame.Angles(0, yaw, 0))
end

local function updatePivotState(state, targetYaw: number, springSettings: { [string]: number }, snap: boolean)
	if state.model == nil or state.closedPivot == nil then
		return
	end

	if snap then
		state.spring = nil
		disconnectConnection(state.connections, "step")
		applyPivotFromYaw(state, targetYaw)
		return
	end

	local currentYaw = interactableMotion.getRelativeYaw(state.closedPivot, state.model:GetPivot())
	if math.abs(targetYaw - currentYaw) <= motionThresholds.pivotSettledAngle then
		state.spring = nil
		disconnectConnection(state.connections, "step")
		applyPivotFromYaw(state, targetYaw)
		return
	end

	local activeSpring = state.spring
	if not activeSpring then
		activeSpring = spring.new(
			Vector2.new(currentYaw, 0),
			springSettings.mass,
			springSettings.force,
			springSettings.damping,
			springSettings.speed
		)
		state.spring = activeSpring
	else
		activeSpring.position = Vector2.new(currentYaw, 0)
	end

	activeSpring.mass = springSettings.mass
	activeSpring.force = springSettings.force
	activeSpring.damping = springSettings.damping
	activeSpring.speed = springSettings.speed
	activeSpring.target = Vector2.new(targetYaw, 0)

	if state.connections.step then
		return
	end

	state.connections.step = runService.RenderStepped:Connect(function(deltaTime)
		local currentSpring = state.spring
		if currentSpring == nil or state.model == nil or state.closedPivot == nil then
			return
		end

		local currentYawPosition = currentSpring:update(deltaTime).X
		applyPivotFromYaw(state, currentYawPosition)

		local isSettled = math.abs(currentSpring.target.X - currentYawPosition) <= motionThresholds.pivotSettledAngle
			and math.abs(currentSpring.velocity.X) <= motionThresholds.pivotSettledVelocity
		if not isSettled then
			return
		end

		local settledTarget = currentSpring.target.X
		currentSpring.position = Vector2.new(settledTarget, 0)
		currentSpring.velocity = Vector2.zero
		applyPivotFromYaw(state, settledTarget)

		state.spring = nil
		disconnectConnection(state.connections, "step")
	end)
end

local function applyDrawerDistance(instance: PivotInstance, closedPivot: CFrame, distance: number)
	instance:PivotTo(closedPivot * CFrame.new(0, 0, -distance))
end

local singlePivotController = {}
singlePivotController.__index = singlePivotController

function singlePivotController:cacheModel(): boolean
	if self.model ~= nil and self.model.Parent ~= nil then
		return self.closedPivot ~= nil
	end

	local model = asPivotInstance(self.instance:FindFirstChild(self.modelName))
	if model == nil then
		return false
	end

	self.model = model
	self.closedPivot = self.closedPivot or model:GetPivot()
	self.state.model = self.model
	self.state.closedPivot = self.closedPivot

	return true
end

function singlePivotController:syncToReplicatedState(snap: boolean)
	if not self:cacheModel() then
		return
	end

	local motionSequence = getOptionalNumericAttribute(self.instance, motionAttributes.sequence)
	if motionSequence == nil and not self.hasInitialized then
		return
	end

	local isOpen = self.instance:GetAttribute("Open") == true
	local targetYaw = getNumericAttribute(self.instance, motionAttributes.targetYaw, 0)

	local springSettings = self.springSettingsGetter(isOpen, self.instance)
	interactableMotion.applySpeedOverride(
		springSettings,
		getNumericAttribute(self.instance, motionAttributes.speedOverride, springSettings.speed)
	)
	updatePivotState(self.state, targetYaw, springSettings, snap or not self.hasInitialized)
	self.hasInitialized = true
end

function singlePivotController:scheduleRefresh(snap: boolean?)
	if snap then
		self.pendingSnap = true
	end

	if self.refreshQueued then
		return
	end

	self.refreshQueued = true
	task.defer(function()
		if getmetatable(self) == nil then
			return
		end

		self.refreshQueued = false
		local shouldSnap = self.pendingSnap == true
		self.pendingSnap = false
		self:syncToReplicatedState(shouldSnap)
	end)
end

function singlePivotController:init()
	self.connections.sequenceChanged = self.instance
		:GetAttributeChangedSignal(motionAttributes.sequence)
		:Connect(function()
			self:scheduleRefresh(false)
		end)

	self.connections.childAdded = self.instance.ChildAdded:Connect(function(child)
		if child.Name ~= self.modelName then
			return
		end

		self.model = nil
		self.closedPivot = nil
		self.state.model = nil
		self.state.closedPivot = nil
		self.hasInitialized = false
		self:scheduleRefresh(true)
	end)

	self:scheduleRefresh(true)
end

function singlePivotController.new(
	instance: Model,
	modelName: string,
	springSettingsGetter: (boolean, Instance) -> { [string]: number }
)
	local self = setmetatable({}, singlePivotController)

	self.instance = instance
	self.modelName = modelName
	self.springSettingsGetter = springSettingsGetter
	self.connections = {}
	self.refreshQueued = false
	self.pendingSnap = false
	self.hasInitialized = false
	self.state = {
		model = nil,
		closedPivot = nil,
		spring = nil,
		connections = {},
	}

	task.defer(self.init, self)

	return self
end

function singlePivotController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	for _, connection in pairs(self.state.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
	table.clear(self.state.connections)
	self.state.spring = nil

	setmetatable(self, nil)
end

local doublePivotController = {}
doublePivotController.__index = doublePivotController

function doublePivotController:cacheModels(): boolean
	if self.door1 ~= nil and self.door2 ~= nil and self.door1.Parent ~= nil and self.door2.Parent ~= nil then
		return self.state1.closedPivot ~= nil and self.state2.closedPivot ~= nil
	end

	local door1 = asPivotInstance(self.instance:FindFirstChild("Door1"))
	local door2 = asPivotInstance(self.instance:FindFirstChild("Door2"))
	if door1 == nil or door2 == nil then
		return false
	end

	self.door1 = door1
	self.door2 = door2
	self.state1.model = door1
	self.state2.model = door2
	self.state1.closedPivot = self.state1.closedPivot or door1:GetPivot()
	self.state2.closedPivot = self.state2.closedPivot or door2:GetPivot()

	return true
end

function doublePivotController:syncToReplicatedState(snap: boolean)
	if not self:cacheModels() then
		return
	end

	local motionSequence = getOptionalNumericAttribute(self.instance, motionAttributes.sequence)
	if motionSequence == nil and not self.hasInitialized then
		return
	end

	local isOpen = self.instance:GetAttribute("Open") == true
	local targetYaw1 = getNumericAttribute(self.instance, motionAttributes.targetYaw1, 0)
	local targetYaw2 = getNumericAttribute(self.instance, motionAttributes.targetYaw2, 0)

	local springSettings =
		interactableMotion.getDoorSpringSettings(isOpen, getStringAttribute(self.instance, "DoorType"))
	interactableMotion.applySpeedOverride(
		springSettings,
		getNumericAttribute(self.instance, motionAttributes.speedOverride, springSettings.speed)
	)

	local shouldSnap = snap or not self.hasInitialized
	updatePivotState(self.state1, targetYaw1, springSettings, shouldSnap)
	updatePivotState(self.state2, targetYaw2, springSettings, shouldSnap)
	self.hasInitialized = true
end

function doublePivotController:scheduleRefresh(snap: boolean?)
	if snap then
		self.pendingSnap = true
	end

	if self.refreshQueued then
		return
	end

	self.refreshQueued = true
	task.defer(function()
		if getmetatable(self) == nil then
			return
		end

		self.refreshQueued = false
		local shouldSnap = self.pendingSnap == true
		self.pendingSnap = false
		self:syncToReplicatedState(shouldSnap)
	end)
end

function doublePivotController:init()
	self.connections.sequenceChanged = self.instance
		:GetAttributeChangedSignal(motionAttributes.sequence)
		:Connect(function()
			self:scheduleRefresh(false)
		end)

	self.connections.childAdded = self.instance.ChildAdded:Connect(function(child)
		if child.Name ~= "Door1" and child.Name ~= "Door2" then
			return
		end

		if child.Name == "Door1" then
			self.door1 = nil
			self.state1.model = nil
			self.state1.closedPivot = nil
		else
			self.door2 = nil
			self.state2.model = nil
			self.state2.closedPivot = nil
		end

		self.hasInitialized = false
		self:scheduleRefresh(true)
	end)

	self:scheduleRefresh(true)
end

function doublePivotController.new(instance: Model)
	local self = setmetatable({}, doublePivotController)

	self.instance = instance
	self.connections = {}
	self.refreshQueued = false
	self.pendingSnap = false
	self.hasInitialized = false
	self.state1 = { model = nil, closedPivot = nil, spring = nil, connections = {} }
	self.state2 = { model = nil, closedPivot = nil, spring = nil, connections = {} }

	task.defer(self.init, self)

	return self
end

function doublePivotController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	for _, connection in pairs(self.state1.connections) do
		connection:Disconnect()
	end

	for _, connection in pairs(self.state2.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
	table.clear(self.state1.connections)
	table.clear(self.state2.connections)
	self.state1.spring = nil
	self.state2.spring = nil

	setmetatable(self, nil)
end

local slideController = {}
slideController.__index = slideController

function slideController:cacheDrawer(): boolean
	if self.drawer ~= nil and self.drawer.Parent ~= nil then
		return self.closedPivot ~= nil
	end

	local drawer = asPivotInstance(self.instance:FindFirstChild("Drawer"))
	if drawer == nil then
		return false
	end

	self.drawer = drawer
	self.closedPivot = self.closedPivot or drawer:GetPivot()

	return true
end

function slideController:applyDistance(distance: number)
	if self.drawer == nil or self.closedPivot == nil then
		return
	end

	applyDrawerDistance(self.drawer, self.closedPivot, distance)
end

function slideController:getCurrentDistance(): number
	if self.drawer == nil or self.closedPivot == nil then
		return 0
	end

	local localOffset = self.closedPivot:ToObjectSpace(self.drawer:GetPivot())
	return -localOffset.Z
end

function slideController:ensureSpringConnection()
	if self.connections.drawerSpringStep then
		return
	end

	self.connections.drawerSpringStep = runService.RenderStepped:Connect(function(deltaTime)
		local activeSpring = self.drawerSpring
		if activeSpring == nil then
			return
		end

		local currentDistance = activeSpring:update(deltaTime).X
		self:applyDistance(currentDistance)

		local isSettled = math.abs(activeSpring.target.X - currentDistance) <= motionThresholds.slideSettledDistance
			and math.abs(activeSpring.velocity.X) <= motionThresholds.slideSettledVelocity
		if not isSettled then
			return
		end

		local settledTarget = activeSpring.target.X
		activeSpring.position = Vector2.new(settledTarget, 0)
		activeSpring.velocity = Vector2.zero
		self:applyDistance(settledTarget)

		self.drawerSpring = nil
		disconnectConnection(self.connections, "drawerSpringStep")
	end)
end

function slideController:syncToReplicatedState(snap: boolean)
	if not self:cacheDrawer() then
		return
	end

	local motionSequence = getOptionalNumericAttribute(self.instance, motionAttributes.sequence)
	if motionSequence == nil and not self.hasInitialized then
		return
	end

	local isOpen = self.instance:GetAttribute("Open") == true
	local targetDistance = getNumericAttribute(self.instance, motionAttributes.targetDistance, 0)

	if snap or not self.hasInitialized then
		self.drawerSpring = nil
		disconnectConnection(self.connections, "drawerSpringStep")
		self:applyDistance(targetDistance)
		self.hasInitialized = true
		return
	end

	local currentDistance = self:getCurrentDistance()
	if math.abs(targetDistance - currentDistance) <= motionThresholds.slideSettledDistance then
		self.drawerSpring = nil
		disconnectConnection(self.connections, "drawerSpringStep")
		self:applyDistance(targetDistance)
		return
	end

	local springSettings = interactableMotion.getDrawerSpringSettings(isOpen)
	local activeSpring = self.drawerSpring
	if activeSpring == nil then
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
	self.hasInitialized = true
end

function slideController:scheduleRefresh(snap: boolean?)
	if snap then
		self.pendingSnap = true
	end

	if self.refreshQueued then
		return
	end

	self.refreshQueued = true
	task.defer(function()
		if getmetatable(self) == nil then
			return
		end

		self.refreshQueued = false
		local shouldSnap = self.pendingSnap == true
		self.pendingSnap = false
		self:syncToReplicatedState(shouldSnap)
	end)
end

function slideController:init()
	self.connections.sequenceChanged = self.instance
		:GetAttributeChangedSignal(motionAttributes.sequence)
		:Connect(function()
			self:scheduleRefresh(false)
		end)

	self.connections.childAdded = self.instance.ChildAdded:Connect(function(child)
		if child.Name ~= "Drawer" then
			return
		end

		self.drawer = nil
		self.closedPivot = nil
		self.hasInitialized = false
		self:scheduleRefresh(true)
	end)

	self:scheduleRefresh(true)
end

function slideController.new(instance: Model)
	local self = setmetatable({}, slideController)

	self.instance = instance
	self.connections = {}
	self.drawer = nil
	self.closedPivot = nil
	self.drawerSpring = nil
	self.refreshQueued = false
	self.pendingSnap = false
	self.hasInitialized = false

	task.defer(self.init, self)

	return self
end

function slideController:destroy()
	self.drawerSpring = nil

	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
	setmetatable(self, nil)
end

local interactablesController = {}
interactablesController.__index = interactablesController

function interactablesController:getTargetsForSource(sourceInstance: Instance): { Instance }
	if sourceInstance:IsA("Configuration") or sourceInstance:IsA("Folder") then
		return sourceInstance:GetChildren()
	end

	return { sourceInstance }
end

function interactablesController:createTargetController(className: string, target: Instance)
	if not target:IsA("Model") then
		return nil
	end

	if className == "Doors" then
		if target:GetAttribute("DoorClass") == "Double" then
			return doublePivotController.new(target)
		end

		return singlePivotController.new(target, "Door", function(isOpen: boolean, instance: Instance)
			return interactableMotion.getDoorSpringSettings(isOpen, getStringAttribute(instance, "DoorType"))
		end)
	end

	if className == "Locker" then
		return singlePivotController.new(target, "LockerDoor", function(isOpen: boolean)
			return interactableMotion.getLockerSpringSettings(isOpen)
		end)
	end

	if className == "Drawer" then
		return slideController.new(target)
	end

	return nil
end

function interactablesController:loadSource(sourceInstance: Instance)
	local className = sourceInstance:GetAttribute("Class")
	if className ~= "Doors" and className ~= "Locker" and className ~= "Drawer" then
		return
	end

	local loadedTargets = {}
	for _, target in ipairs(self:getTargetsForSource(sourceInstance)) do
		if self.controllersByTarget[target] ~= nil then
			continue
		end

		local controller = self:createTargetController(className, target)
		if controller == nil then
			continue
		end

		self.controllersByTarget[target] = controller
		table.insert(loadedTargets, target)
	end

	if #loadedTargets > 0 then
		self.targetsBySource[sourceInstance] = loadedTargets
	end
end

function interactablesController:unloadSource(sourceInstance: Instance)
	local loadedTargets = self.targetsBySource[sourceInstance]
	if loadedTargets == nil then
		return
	end

	for _, target in ipairs(loadedTargets) do
		local controller = self.controllersByTarget[target]
		if type(controller) == "table" and type(controller.destroy) == "function" then
			controller:destroy()
		end

		self.controllersByTarget[target] = nil
	end

	self.targetsBySource[sourceInstance] = nil
end

function interactablesController:init()
	if not interactableMotion.animateOnClient then
		return
	end

	for _, taggedInstance in ipairs(collectionService:GetTagged("Interactable")) do
		self:loadSource(taggedInstance)
	end

	self.connections.tagAdded = collectionService
		:GetInstanceAddedSignal("Interactable")
		:Connect(function(taggedInstance)
			self:loadSource(taggedInstance)
		end)

	self.connections.tagRemoved = collectionService
		:GetInstanceRemovedSignal("Interactable")
		:Connect(function(taggedInstance)
			self:unloadSource(taggedInstance)
		end)
end

function interactablesController.new()
	local self = setmetatable({}, interactablesController)

	self.connections = {}
	self.targetsBySource = {}
	self.controllersByTarget = {}

	task.defer(self.init, self)

	return self
end

function interactablesController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	for sourceInstance in pairs(self.targetsBySource) do
		self:unloadSource(sourceInstance)
	end

	table.clear(self.connections)
	table.clear(self.targetsBySource)
	table.clear(self.controllersByTarget)
end

return interactablesController
