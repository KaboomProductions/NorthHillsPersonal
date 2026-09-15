local runService = game:GetService("RunService")

local legController = {}
legController.__index = legController

local ikAttachmentOffsets = {
	leftHip = CFrame.new(-0.466, -0.944, 0),
	leftFoot = CFrame.new(-0.5, -2.9, 0),
	rightHip = CFrame.new(0.5, -0.944, 0),
	rightFoot = CFrame.new(0.5, -2.9, 0),
}

function legController.new(character: Model, configuration: any)
	local self = setmetatable({}, legController)

	local humanoid = character:WaitForChild("Humanoid")

	local rootJoint = character:WaitForChild("HumanoidRootPart"):WaitForChild("RootJoint") :: Motor6D
	local leftHip =
		character:FindFirstChild(humanoid.RigType == Enum.HumanoidRigType.R15 and "LeftHip" or "Left Hip", true)
	local rightHip =
		character:FindFirstChild(humanoid.RigType == Enum.HumanoidRigType.R15 and "RightHip" or "Right Hip", true)

	self.states = {
		isTiltingEnabled = true,
		isIkEnabled = configuration.ikEnabled,
	}

	local defaultMotorCFrames = {
		rootJoint = rootJoint.C0,
		hips = {
			leftHip = leftHip.C0,
			rightHip = rightHip.C0,
		},
	}

	local ikParams = RaycastParams.new()
	ikParams.FilterType = Enum.RaycastFilterType.Exclude
	ikParams.FilterDescendantsInstances = { character }
	for _, exclusionObject in pairs(configuration.ikExclude) do
		table.insert(ikParams.FilterDescendantsInstances, exclusionObject)
	end

	self.ikAttachments = {}
	for attachmentName, attachmentCFrame in pairs(ikAttachmentOffsets) do
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = attachmentName
		newAttachment.CFrame = attachmentCFrame
		newAttachment.Parent = humanoid.RootPart

		self.ikAttachments[attachmentName] = newAttachment
	end

	self.renderConnection = runService.RenderStepped:Connect(function(deltaTime: number)
		local normalizedDeltaTime = deltaTime * 60

		local moveDirection = humanoid.RootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
		local moveDirectionMagnitude = moveDirection.Magnitude

		local horizontalSpeed = moveDirection.X
		local forwardSpeed = moveDirection.Z

		local absoluteHorizontal = math.abs(horizontalSpeed)
		local absoluteForward = math.abs(forwardSpeed)

		local stopThreshold = 0.05
		local movementFactor = math.clamp((moveDirectionMagnitude - stopThreshold) / (1 - stopThreshold), 0, 1)

		local diagonalThreshold = 0.25
		local diagonalFactor = 0
		if moveDirectionMagnitude > stopThreshold then
			diagonalFactor = math.min(absoluteHorizontal, absoluteForward)
				/ math.max(absoluteHorizontal, absoluteForward)
			diagonalFactor = math.clamp((diagonalFactor - diagonalThreshold) / (1 - diagonalThreshold), 0, 1)
		end

		local directionalRightVelocity = 0
		if moveDirectionMagnitude > stopThreshold and diagonalFactor > 0 then
			directionalRightVelocity = horizontalSpeed
		end

		local canAngle = table.find(configuration.onStates, humanoid:GetState())
		local isMovingBackward = humanoid.RootPart.CFrame.LookVector:Dot(humanoid.MoveDirection) < -0.1

		local rootAngle = 0
		local legAngle = 0

		if self.states.isTiltingEnabled and canAngle and moveDirection.Magnitude ~= 0 then
			rootAngle = math.rad(directionalRightVelocity * configuration.maxRootAngle) * (isMovingBackward and 1 or -1)
			legAngle = math.rad(directionalRightVelocity * configuration.maxAngle) * (isMovingBackward and 1 or -1)
		end

		rootAngle *= movementFactor * diagonalFactor
		legAngle *= movementFactor * diagonalFactor

		local interpolationSpeed = configuration.interpolationSpeed.Speed
		rootJoint.C0 = rootJoint.C0:Lerp(
			defaultMotorCFrames.rootJoint * CFrame.Angles(0, 0, rootAngle),
			(interpolationSpeed * 0.25) * normalizedDeltaTime
		)
		leftHip.C0 = leftHip.C0:Lerp(
			defaultMotorCFrames.hips.leftHip * CFrame.Angles(0, legAngle, 0),
			interpolationSpeed * normalizedDeltaTime
		)
		rightHip.C0 = rightHip.C0:Lerp(
			defaultMotorCFrames.hips.rightHip * CFrame.Angles(0, legAngle, 0),
			interpolationSpeed * normalizedDeltaTime
		)
	end)

	return self
end

function legController:destroy()
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	for _, attachment in pairs(self.ikAttachments) do
		attachment:Destroy()
	end

	table.clear(self)
	setmetatable(self, nil)
end

function legController:setState(stateKey: string, isEnabled: boolean)
	if self.states[stateKey] == nil then
		error("Invalid state key: " .. stateKey)
		return
	end

	self.states[stateKey] = isEnabled
end

return legController
