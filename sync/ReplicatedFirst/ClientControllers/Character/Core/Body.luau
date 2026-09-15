local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local player = players.LocalPlayer

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local bodyController = {}
bodyController.__index = bodyController

local defaultValues = {
	cameraOffset = vector.create(0, 0, -1),
	offsetDistance = {
		min = 0.5,
		max = 4,
	},

	freeRange = {
		viewAngle = 35,
		lerpSpeed = 12,
		maximumLerpSpeed = 32,
	},

	thirdPerson = {
		turnLerpSpeed = 21,
		idleTurnLerpSpeed = 13,
		maximumLerpSpeed = 32,
		yawDeadzone = 0.01,
	},

	turnResponse = {
		boostStartAngle = 45,
		maximumSpeedAngle = 135,
	},

	blacklistedAccessories = {
		[Enum.AccessoryType.Hat] = true,
		[Enum.AccessoryType.Hair] = true,
		[Enum.AccessoryType.Face] = true,
		[Enum.AccessoryType.Shoulder] = true,
		[Enum.AccessoryType.Back] = true,
		[Enum.AccessoryType.Neck] = true,
	},
}

local function calculateTurnAlpha(deltaTime: number, turnAngle: number, minimumSpeed: number, maximumSpeed: number): number
	local turnResponseConfig = defaultValues.turnResponse
	local boostAlpha = mathUtilities.remapClamped(
		math.abs(turnAngle),
		math.rad(turnResponseConfig.boostStartAngle),
		math.rad(turnResponseConfig.maximumSpeedAngle),
		0,
		1
	)
	local smoothBoostAlpha = boostAlpha * boostAlpha * (3 - 2 * boostAlpha)
	local turnSpeed = minimumSpeed + (maximumSpeed - minimumSpeed) * smoothBoostAlpha

	return mathUtilities.exponentialAlpha(turnSpeed, deltaTime)
end

function bodyController:cacheParts()
	local character = self.character
	local head = self.head

	self.parts = {}
	self.accessories = {}

	for _, object in ipairs(character:GetChildren()) do
		if object == head then
			continue
		end

		if object:IsA("BasePart") then
			table.insert(self.parts, object)
		elseif object:IsA("Accessory") and not defaultValues.blacklistedAccessories[object.AccessoryType] then
			local handle = object:FindFirstChild("Handle")
			if handle ~= nil then
				table.insert(self.accessories, handle)
			else
				continue
			end
		end
	end
end

function bodyController:enforcePartVisibility(partArray)
	for _, part in ipairs(partArray) do
		if not part then
			continue
		end

		if part.LocalTransparencyModifier ~= 0 then
			part.LocalTransparencyModifier = 0
		end
	end
end

function bodyController:updateFreeRange(deltaTime)
	local freeRangeConfig = defaultValues.freeRange
	local viewAngle = freeRangeConfig.viewAngle
	local lerpSpeed = freeRangeConfig.lerpSpeed

	local rootPart = self.rootPart
	local currentCamera = self.currentCamera
	local humanoid = self.humanoid

	if not rootPart or not humanoid then
		return
	end

	if self.character and self.character:GetAttribute("Ragdolled") then
		return
	end

	local rootCFrame = rootPart.CFrame
	local cameraCFrame = currentCamera.CFrame

	local cameraYaw = select(2, cameraCFrame:ToEulerAnglesYXZ())
	local rootYaw = select(2, rootCFrame:ToEulerAnglesYXZ())
	self.rotationYaw = select(2, rootCFrame.Rotation:ToEulerAnglesYXZ())
	local cameraYawDelta = mathUtilities.normalizeAngle(cameraYaw - self.rotationYaw)
	local isFirstPerson = self.character:GetAttribute("FirstPerson") == true

	if not isFirstPerson then
		local moveDirection = humanoid.MoveDirection
		local isMoving = vector.magnitude(moveDirection) > 0.01
		local yawDelta = cameraYawDelta
		if math.abs(yawDelta) <= defaultValues.thirdPerson.yawDeadzone then
			return
		end

		local thirdPersonConfig = defaultValues.thirdPerson
		local minimumTurnSpeed = if isMoving then thirdPersonConfig.turnLerpSpeed else thirdPersonConfig.idleTurnLerpSpeed
		local alpha = calculateTurnAlpha(
			deltaTime,
			yawDelta,
			minimumTurnSpeed,
			thirdPersonConfig.maximumLerpSpeed
		)
		local calculatedYaw = self.rotationYaw + yawDelta * alpha

		rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, calculatedYaw, 0)
		self.rotationYaw = calculatedYaw
		return
	end

	local currentRotationYaw = self.rotationYaw
	local yawDelta = nil

	local moveDirection = humanoid.MoveDirection
	local magnitude = vector.magnitude(moveDirection)

	if magnitude > 0 then
		yawDelta = mathUtilities.normalizeAngle(cameraYaw - rootYaw)
		currentRotationYaw = rootYaw + yawDelta * 0.35
	else
		local relative = rootCFrame.Rotation:ToObjectSpace(cameraCFrame.Rotation)
		local relativeYaw = select(2, relative:ToEulerAnglesYXZ())
		relativeYaw = math.deg(relativeYaw)

		if relativeYaw > viewAngle then
			currentRotationYaw = cameraYaw - math.rad(viewAngle)
		elseif relativeYaw < -viewAngle then
			currentRotationYaw = cameraYaw + math.rad(viewAngle)
		end
	end

	yawDelta = mathUtilities.normalizeAngle(currentRotationYaw - self.rotationYaw)

	local alpha = calculateTurnAlpha(deltaTime, cameraYawDelta, lerpSpeed, freeRangeConfig.maximumLerpSpeed)
	local desiredYaw = self.rotationYaw + yawDelta * alpha

	local maxOffset = math.rad(75)
	local offset = mathUtilities.normalizeAngle(desiredYaw - cameraYaw)
	offset = math.clamp(offset, -maxOffset, maxOffset)

	local calculatedYaw = cameraYaw + offset

	rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, calculatedYaw, 0)
	self.rotationYaw = calculatedYaw
end

function bodyController:updateFullBody()
	self:enforcePartVisibility(self.parts)
	self:enforcePartVisibility(self.accessories)
end

function bodyController:preload()
	self:cacheParts()
	self.humanoid.AutoRotate = false
end

function bodyController:init()
	self:preload()

	runService:UnbindFromRenderStep("Body")

	local character = self.character

	self.connections.added = character.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") or child:IsA("Accessory") then
			self:cacheParts()
		end
	end)

	self.connections.removed = character.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") or child:IsA("Accessory") then
			self:cacheParts()
		end
	end)

	runService:BindToRenderStep("Body", Enum.RenderPriority.Character.Value, function(deltaTime)
		if character then
			self:updateFullBody()
			self:updateFreeRange(deltaTime)
		end
	end)
end

function bodyController.new()
	local self = setmetatable({}, bodyController)
	self.connections = {}

	local character = player.Character or player.CharacterAdded:Wait()
	self.character = character
	self.currentCamera = workspace.CurrentCamera
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
	self.rootPart = self.humanoid.RootPart
	self.head = character:WaitForChild("Head")
	self.rotationYaw = select(2, self.rootPart.CFrame.Rotation:ToEulerAnglesYXZ())

	task.defer(self.init, self)

	return self
end

function bodyController:destroy()
	runService:UnbindFromRenderStep("Body")

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	setmetatable(self, nil)
end

return bodyController
