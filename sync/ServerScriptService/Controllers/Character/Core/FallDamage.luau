local runService = game:GetService("RunService")

local fallDamageController = {}
fallDamageController.__index = fallDamageController
fallDamageController.__vars = {
	minimumFallHeight = 5,
	maximumFallHeight = 55,
	fallDamageLevels = 6,
	ragdollFallHeight = 20,

	fallVelocityThreshold = -5,
	groundCheckDistance = 3.5,

	spinTorque = math.huge,
	spinAngularSpeed = 8,

	initialHeight = nil,
	isFalling = false,
	hasRagdolled = false,
}

function fallDamageController:calculateFallLevel(fallHeight: number): number
	local stateValues = self.__vars
	local minimumFallHeight = stateValues.minimumFallHeight
	local maximumFallHeight = stateValues.maximumFallHeight
	local fallDamageLevels = stateValues.fallDamageLevels

	if fallHeight <= minimumFallHeight then
		return 0
	end

	if fallHeight >= maximumFallHeight then
		return fallDamageLevels - 1
	end

	local heightRange = maximumFallHeight - minimumFallHeight
	local normalizedHeight = (fallHeight - minimumFallHeight) / heightRange
	local level = math.floor(normalizedHeight * (fallDamageLevels - 1) + 0.5)

	return math.clamp(level, 0, fallDamageLevels - 1)
end

function fallDamageController:calculateFallDamage(fallHeight: number): (number, number)
	local stateValues = self.__vars
	local humanoid = self.humanoid
	local level = self:calculateFallLevel(fallHeight)

	if level == 0 then
		return 0, level
	end

	if level == 5 then
		return humanoid.MaxHealth, level
	end

	local maximumHealth = humanoid.MaxHealth
	local damagePerLevel = maximumHealth / (stateValues.fallDamageLevels - 1)
	local damage = damagePerLevel * level

	return damage, level
end

function fallDamageController:ragdoll()
	self.character:SetAttribute("RagdollTimer", math.huge)
	self:_startSpin()
end

function fallDamageController:_startSpin()
	local humanoidRootPart = self.humanoidRootPart
	local stateValues = self.__vars

	self:_stopSpin()

	local attachment = Instance.new("Attachment")
	attachment.Name = "FallSpinAttachment"
	attachment.Parent = humanoidRootPart

	local spinAxis = Vector3.new(math.random(-100, 100), math.random(-40, 40), math.random(-100, 100)).Unit
	local angularVelocity = Instance.new("AngularVelocity")
	angularVelocity.Name = "FallSpin"
	angularVelocity.Attachment0 = attachment
	angularVelocity.AngularVelocity = spinAxis * stateValues.spinAngularSpeed
	angularVelocity.MaxTorque = stateValues.spinTorque
	angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	angularVelocity.Parent = attachment

	self.spinAttachment = attachment
	self.spinAngularVelocity = angularVelocity
end

function fallDamageController:_stopSpin()
	if self.spinAttachment then
		self.spinAttachment:Destroy()
		self.spinAttachment = nil
		self.spinAngularVelocity = nil
	end
end

function fallDamageController:_isGrounded(): boolean
	local humanoidRootPart = self.humanoidRootPart
	local stateValues = self.__vars

	local raycastParams = self.groundRaycastParams
	local origin = humanoidRootPart.Position
	local result = workspace:Raycast(origin, Vector3.new(0, -stateValues.groundCheckDistance, 0), raycastParams)

	return result ~= nil
end

function fallDamageController:_onLand(fallHeight: number)
	local wasRagdolled = self.__vars.hasRagdolled

	self:_stopSpin()

	if fallHeight <= 0 then
		return
	end

	if wasRagdolled then
		self.humanoid.Health = 0
		return
	end

	local damage, level = self:calculateFallDamage(fallHeight)

	if level == 5 then
		self.humanoid.Health = 0
		return
	end

	if damage > 0 then
		self.humanoid:TakeDamage(damage)
	end
end

function fallDamageController:_onHeartbeat()
	local stateValues = self.__vars
	local humanoidRootPart = self.humanoidRootPart

	local velocityY = humanoidRootPart.AssemblyLinearVelocity.Y
	local grounded = self:_isGrounded()

	if not stateValues.isFalling then
		if not grounded and velocityY <= stateValues.fallVelocityThreshold then
			stateValues.isFalling = true
			stateValues.hasRagdolled = false
			stateValues.initialHeight = humanoidRootPart.Position.Y
		end

		return
	end

	if not stateValues.hasRagdolled then
		local fallenSoFar = stateValues.initialHeight - humanoidRootPart.Position.Y

		if fallenSoFar >= stateValues.ragdollFallHeight then
			stateValues.hasRagdolled = true
			self:ragdoll()
		end
	end

	if grounded then
		local fallHeight = stateValues.initialHeight - humanoidRootPart.Position.Y

		stateValues.isFalling = false
		stateValues.initialHeight = nil

		self:_onLand(fallHeight)

		stateValues.hasRagdolled = false
	end
end

function fallDamageController:preload()
	local character = self.character

	self.humanoid = character:WaitForChild("Humanoid")
	self.humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	self.groundRaycastParams = raycastParams
end

function fallDamageController:init()
	local connections = self.connections

	self:preload()

	connections.heartbeat = runService.Heartbeat:Connect(function()
		self:_onHeartbeat()
	end)
end

function fallDamageController.new(player: Player, character: Model)
	local self = setmetatable({}, fallDamageController)

	self.player = player
	self.character = character
	self.humanoid = nil
	self.humanoidRootPart = nil
	self.groundRaycastParams = nil
	self.spinAttachment = nil
	self.spinAngularVelocity = nil
	self.connections = {}
	self.__vars = table.clone(fallDamageController.__vars)

	task.defer(self.init, self)

	return self
end

function fallDamageController:destroy()
	local connections = self.connections

	self:_stopSpin()

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return fallDamageController
