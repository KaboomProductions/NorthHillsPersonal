local ragdollController = {}
ragdollController.__index = ragdollController

local rigProfile = {
	torsoPart = "Torso",
	motorParent = "part0",
	joints = {
		Neck = {
			part0 = "Torso",
			part1 = "Head",
			motorName = "Neck",
			upperAngle = 45,
			twistLower = -60,
			twistUpper = 60,
		},
		LeftShoulder = {
			part0 = "Torso",
			part1 = "Left Arm",
			motorName = "Left Shoulder",
			upperAngle = 80,
			twistLower = -80,
			twistUpper = 80,
		},
		RightShoulder = {
			part0 = "Torso",
			part1 = "Right Arm",
			motorName = "Right Shoulder",
			upperAngle = 80,
			twistLower = -80,
			twistUpper = 80,
		},
		LeftHip = {
			part0 = "Torso",
			part1 = "Left Leg",
			motorName = "Left Hip",
			upperAngle = 45,
			twistLower = -20,
			twistUpper = 60,
		},
		RightHip = {
			part0 = "Torso",
			part1 = "Right Leg",
			motorName = "Right Hip",
			upperAngle = 45,
			twistLower = -20,
			twistUpper = 60,
		},
	},
}

local colliderProfile = {
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
	"Head",
}

function ragdollController.new(character, rigTypeOverride)
	assert(character, "ragdollController.new requires a character model")

	local self = setmetatable({}, ragdollController)

	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
	self.enabled = false
	self.built = false

	local rigType = rigTypeOverride
	if not rigType and self.humanoid then
		rigType = (self.humanoid.RigType == Enum.HumanoidRigType.R6) and "R6" or "R15"
	end
	rigType = rigType or "R15"

	self._profile = rigProfile
	assert(self._profile, ("ragdollController: unknown rig type '%s'"):format(tostring(rigType)))

	self._joints = {}
	self._rootJoint = nil
	self._rootWeld = nil
	self._originalCollisionGroups = {}
	self._animationTracks = {}
	self._connections = {}
	self._onEnabledCallbacks = {}
	self._onDisabledCallbacks = {}
	self._originalCanCollide = {}
	self._colliders = {}

	table.insert(
		self._connections,
		character.Destroying:Once(function()
			self:destroy()
		end)
	)

	return self
end

function ragdollController:onEnabled(callback)
	table.insert(self._onEnabledCallbacks, callback)
end

function ragdollController:onDisabled(callback)
	table.insert(self._onDisabledCallbacks, callback)
end

function ragdollController:isEnabled()
	return self.enabled
end

function ragdollController:_createColliders()
	if #self._colliders > 0 then
		return
	end

	for _, partName in pairs(colliderProfile) do
		local limb = self.character:FindFirstChild(partName)

		if limb and limb:IsA("BasePart") then
			local collider = Instance.new("Part")
			collider.Name = partName .. "_RagdollCollider"
			collider.Size = limb.Size * 0.7
			collider.CFrame = limb.CFrame
			collider.Transparency = 1
			collider.CanCollide = true
			collider.Massless = false
			collider.Parent = self.character

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = collider
			weld.Parent = collider

			table.insert(self._colliders, collider)
		end
	end
end

function ragdollController:_build()
	if self.built then
		return
	end

	local profile = self._profile
	local rootPart = self.character:FindFirstChild("HumanoidRootPart")
	local torsoPart = self.character:FindFirstChild(profile.torsoPart)

	if rootPart and torsoPart then
		local rootJoint = rootPart:FindFirstChild("RootJoint")

		if rootJoint and rootJoint:IsA("Motor6D") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "RagdollRootWeld"
			weld.Part0 = rootPart
			weld.Part1 = torsoPart
			weld.Enabled = false
			weld.Parent = rootPart

			self._rootJoint = rootJoint
			self._rootWeld = weld
		end
	end

	for jointName, config in pairs(profile.joints) do
		local part0 = self.character:FindFirstChild(config.part0)
		local part1 = self.character:FindFirstChild(config.part1)
		local motorHolder = (profile.motorParent == "part0") and part0 or part1
		local motor = motorHolder and motorHolder:FindFirstChild(config.motorName)

		if part0 and part1 and motor and motor:IsA("Motor6D") then
			local attachment0 = Instance.new("Attachment")
			attachment0.Name = jointName .. "RagdollAttachment0"
			attachment0.CFrame = motor.C0
			attachment0.Parent = part0

			local attachment1 = Instance.new("Attachment")
			attachment1.Name = jointName .. "RagdollAttachment1"
			attachment1.CFrame = motor.C1
			attachment1.Parent = part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Name = jointName .. "RagdollConstraint"
			socket.Attachment0 = attachment0
			socket.Attachment1 = attachment1
			socket.LimitsEnabled = true
			socket.UpperAngle = config.upperAngle
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = config.twistLower
			socket.TwistUpperAngle = config.twistUpper
			socket.Enabled = false
			socket.Parent = part0

			self._joints[jointName] = {
				motor = motor,
				constraint = socket,
				attachment0 = attachment0,
				attachment1 = attachment1,
			}
		end
	end

	self.built = true
end

function ragdollController:enable()
	if self.enabled then
		return
	end

	self:_build()

	if self._rootJoint then
		self._rootJoint.Enabled = false
		self._rootWeld.Enabled = true
	end

	for _, jointData in pairs(self._joints) do
		jointData.attachment0.WorldCFrame = jointData.attachment1.WorldCFrame
		jointData.motor.Enabled = false
		jointData.constraint.Enabled = true
	end

	for _, part in ipairs(self.character:GetDescendants()) do
		if part:IsA("BasePart") then
			self._originalCollisionGroups[part] = part.CollisionGroup
			self._originalCanCollide[part] = part.CanCollide

			part.CollisionGroup = "Ragdoll"

			if part.Name ~= "HumanoidRootPart" then
				part.CanCollide = true
			end
		end
	end

	self:_createColliders()

	self.enabled = true

	for _, callback in ipairs(self._onEnabledCallbacks) do
		task.spawn(callback)
	end
end

function ragdollController:disable()
	if not self.enabled then
		return
	end

	local rootPart = self.character:FindFirstChild("HumanoidRootPart")
	local torsoPart = self.character:FindFirstChild(self._profile.torsoPart)

	if self._rootWeld then
		self._rootWeld.Enabled = false
	end
	for _, jointData in pairs(self._joints) do
		jointData.constraint.Enabled = false
	end

	if rootPart and torsoPart then
		local lookVector = torsoPart.CFrame.LookVector
		local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

		if flatLook.Magnitude < 0.05 then
			flatLook = Vector3.new(0, 0, -1)
		end

		local targetPosition = torsoPart.Position + Vector3.new(0, 2, 0)
		rootPart.CFrame = CFrame.lookAt(targetPosition, targetPosition + flatLook)
	end

	if self._rootJoint then
		self._rootJoint.Enabled = true
	end

	for _, jointData in pairs(self._joints) do
		jointData.motor.Enabled = true
	end

	for part, group in pairs(self._originalCollisionGroups) do
		if part.Parent then
			part.CollisionGroup = group
		end
	end

	for part, canCollide in pairs(self._originalCanCollide) do
		if part.Parent then
			part.CanCollide = canCollide
		end
	end

	for _, collider in ipairs(self._colliders) do
		if collider.Parent then
			collider:Destroy()
		end
	end

	self._colliders = {}
	self._originalCanCollide = {}
	self._originalCollisionGroups = {}
	self._animationTracks = {}

	self.enabled = false

	for _, callback in ipairs(self._onDisabledCallbacks) do
		task.spawn(callback)
	end
end

function ragdollController:toggle()
	if self.enabled then
		self:disable()
	else
		self:enable()
	end

	return self.enabled
end

function ragdollController:destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	self._connections = {}

	if self._rootWeld then
		self._rootWeld:Destroy()
	end

	for _, jointData in pairs(self._joints) do
		jointData.constraint:Destroy()
		jointData.attachment0:Destroy()
		jointData.attachment1:Destroy()
	end

	for _, collider in ipairs(self._colliders) do
		if collider.Parent then
			collider:Destroy()
		end
	end

	self._colliders = {}
	self._joints = {}

	self.character = nil
	self.humanoid = nil
end

return ragdollController
