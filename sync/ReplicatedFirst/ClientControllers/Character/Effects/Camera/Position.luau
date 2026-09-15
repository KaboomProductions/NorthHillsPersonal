local userInputService = game:GetService("UserInputService")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")

local inputHelpers = require(replicatedFirst.ClientUtilities.InputHelpers)
local rayCastingUtilities = require(replicatedFirst.ClientUtilities.RayCasting)
local inputActionService = require(replicatedStorage.SharedUtilities.InputActionService)
local mouseController = require(replicatedFirst.ClientControllers.Player.Interface.Mouse)

local config = require(script.Config)
local perspective = require(script.Perspective)
local viewUpdater = require(script.ViewUpdater)

local player = players.LocalPlayer
local playerGui = player.PlayerGui:WaitForChild("Interface", 3)
local mobileFrame = playerGui.Mobile
local ragdollCameraRaycastParams = RaycastParams.new()
ragdollCameraRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
ragdollCameraRaycastParams.IgnoreWater = true
ragdollCameraRaycastParams.RespectCanCollide = true

local positionController = {}
positionController.__index = positionController
positionController.__vars = {
	isFirstPerson = true,
	targetOffset = Vector3.zero,
	shoulderSide = 1,
	isLockTargetReached = false,
	isRagdollCameraActive = false,
	wasFirstPersonBeforeRagdoll = false,
}

function positionController:cacheCharacter(character: Model)
	self.character = character
	self.humanoid = character:WaitForChild("Humanoid")
	self.head = character:WaitForChild("Head")
	self.humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	self.__vars.targetOffset = Vector3.zero
end

function positionController:onCharacterAdded(character: Model)
	self:cacheCharacter(character)
	perspective.setFirstPerson(self, self.__vars.isFirstPerson)
end

function positionController:isCharacterRagdolled(): boolean
	local character = self.character

	return character ~= nil and character:GetAttribute("Ragdolled") == true
end

function positionController:getRagdollCameraObstruction(targetPosition: Vector3): RaycastResult?
	local character = self.character
	local head = self.head
	if character == nil or head == nil then
		return nil
	end

	ragdollCameraRaycastParams.FilterDescendantsInstances = { character }

	local headPosition = head.Position
	local castDirection = targetPosition - headPosition
	local obstructionResult =
		rayCastingUtilities.raycastUntilBlockingHit(headPosition, castDirection, ragdollCameraRaycastParams)
	if obstructionResult ~= nil or targetPosition.Y >= headPosition.Y then
		return obstructionResult
	end

	local probeOrigin = Vector3.new(
		targetPosition.X,
		headPosition.Y + head.Size.Y / 2 + self.config.ragdollCameraSurfacePadding,
		targetPosition.Z
	)
	local recoveryResult = rayCastingUtilities.raycastUntilBlockingHit(
		probeOrigin,
		targetPosition - probeOrigin,
		ragdollCameraRaycastParams
	)
	if recoveryResult ~= nil and recoveryResult.Normal.Y > 0 then
		return recoveryResult
	end

	return nil
end

function positionController:getRagdollCameraCFrame(): CFrame?
	local head = self.head
	local humanoid = self.humanoid
	if not self:isCharacterRagdolled() or head == nil or humanoid == nil then
		return nil
	end

	local targetCFrame = head.CFrame * CFrame.new(humanoid.CameraOffset)
	local obstructionResult = self:getRagdollCameraObstruction(targetCFrame.Position)
	if obstructionResult == nil then
		return targetCFrame
	end

	local camera = workspace.CurrentCamera
	local nearPlaneDepth = camera and math.abs(camera.NearPlaneZ) or 0
	local surfaceClearance = nearPlaneDepth + self.config.ragdollCameraSurfacePadding
	local safePosition = obstructionResult.Position + obstructionResult.Normal * surfaceClearance

	return CFrame.new(safePosition) * targetCFrame.Rotation
end

function positionController:updateRagdollPerspective(): boolean
	local stateValues = self.__vars
	if not self:isCharacterRagdolled() then
		if stateValues.isRagdollCameraActive then
			stateValues.isRagdollCameraActive = false
			perspective.setFirstPerson(self, stateValues.wasFirstPersonBeforeRagdoll)
		end

		return false
	end

	if not stateValues.isRagdollCameraActive then
		stateValues.isRagdollCameraActive = true
		stateValues.wasFirstPersonBeforeRagdoll = stateValues.isFirstPerson
		perspective.setFirstPerson(self, true)
		viewUpdater.snapToTarget(self)
	elseif not stateValues.isFirstPerson then
		perspective.setFirstPerson(self, true)
	end

	return true
end

function positionController:onRenderStepped(deltaTime: number)
	if self:updateRagdollPerspective() then
		return
	end

	viewUpdater.updateView(self, deltaTime)
end

function positionController:snapViewToTarget()
	viewUpdater.snapToTarget(self)
end

function positionController:isLockTargetReached(): boolean
	return self.__vars.isLockTargetReached
end

function positionController:onToggleViewInput()
	perspective.handleToggleViewInput(self)
end

function positionController:init()
	mouseController.setCameraBehavior(Enum.MouseBehavior.LockCenter)

	self:cacheCharacter(player.Character or player.CharacterAdded:Wait())
	perspective.setFirstPerson(self, true)

	runService:BindToRenderStep("cameraPositionUpdate", Enum.RenderPriority.Character.Value, function(deltaTime: number)
		self:onRenderStepped(deltaTime)
	end)

	self.perspectiveBind = inputActionService.new("togglePerspective", Enum.InputActionType.Bool)
	inputHelpers.attachAllKeysToInput(self.perspectiveBind, config.toggleKeys)
	inputHelpers.wireMobileButton(self.perspectiveBind, mobileFrame.TogglePerspective, "TogglePerspective", true)

	self.connections.onPerspectiveBind = self.perspectiveBind.Activated:Connect(
		function(_active: Vector2 | Vector3 | boolean | number, pressed: boolean)
			if not pressed then
				return
			end

			self:onToggleViewInput()
		end
	)

	self.connections.onConsoleInput = userInputService.InputBegan:Connect(
		function(input: InputObject, gameProcessed: boolean)
			if not gameProcessed then
				return
			end

			if input.KeyCode == Enum.KeyCode.ButtonR3 then
				self:onToggleViewInput(nil, Enum.UserInputState.Begin, nil)
			end
		end
	)

	self.connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:onCharacterAdded(character)
	end)
end

function positionController.new()
	local self = setmetatable({}, positionController)

	self.config = config
	self.connections = {}
	self.__vars = table.clone(positionController.__vars)
	self.defaultMaxZoomDistance = player.CameraMaxZoomDistance
	self.defaultMinZoomDistance = player.CameraMinZoomDistance
	task.defer(self.init, self)

	return self
end

function positionController:destroy()
	runService:UnbindFromRenderStep("cameraPositionUpdate")
	if self.perspectiveBind then
		self.perspectiveBind:Destroy()
		self.perspectiveBind = nil
	end

	perspective.setFirstPerson(self, false)

	player.CameraMaxZoomDistance = self.defaultMaxZoomDistance
	player.CameraMinZoomDistance = self.defaultMinZoomDistance

	local connections = self.connections
	for connectionName, connection in pairs(connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end

		connections[connectionName] = nil
	end

	self.__vars = nil
	self.config = nil
	setmetatable(self, nil)
end

return positionController
