local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local spring = require(replicatedStorage.SharedClasses.Spring)
local armMotion = require(script.ArmMotion)
local characterReplicationController = require(script.Parent.CharacterReplication)
local config = require(script.Config)
local gripMotion = require(script.GripMotion)
local helpers = require(script.Helpers)
local replication = require(script.Replication)
local itemState = require(script.ItemState)

local player = players.LocalPlayer

local viewModelController = {}
viewModelController.__index = viewModelController
viewModelController.__vars = {
	lastMoveTime = 0,
	turnDepthOffset = 0,
	turnLateralOffset = 0,
	horizontalOvershoot = 0,
	verticalOvershoot = 0,
	isArmFollowEnabled = false,
	isLeftArmSupportEnabled = false,
	isHandFollowEnabled = false,
	shouldReturnArms = true,
	shouldReturnGrip = true,
	armFollowEnableTime = 0,
	armFollowBlend = 0,
	handFollowEnableTime = 0,
	handFollowBlend = 0,
	leftArmSupportOffset = nil,
	leftArmSupportRotationRadians = nil,
	leftArmSupportFollowsRightArm = nil,
	itemRightArmConfig = nil,
	isCoupledArms = false,

	isCameraRelative = false,
	cameraRelativeAim = false,
	cameraRelativeLookDown = nil,
	cameraRelativeLookUp = nil,
	aimConfig = nil,
	isAiming = false,
	aimAlpha = 0,
	recoilConfig = nil,
	pendingRecoilCount = 0,
}

export type ShoulderState = {
	rightMotor: Motor6D,
	leftMotor: Motor6D,
	defaultRightC0: CFrame,
	defaultLeftC0: CFrame,
	currentRightC0: CFrame,
	currentLeftC0: CFrame,
}

export type GripState = {
	weld: (Weld | Motor6D)?,
	cachedWeld: (Weld | Motor6D)?,
	baseC0: CFrame?,
	basePosition: Vector3?,
	baseRotation: CFrame?,
	currentRotation: CFrame?,
}

function viewModelController:preload()
	local character = self.player.Character or self.player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local torso = character:WaitForChild("Torso")
	local head = character:WaitForChild("Head")
	local rightShoulder = torso:WaitForChild("Right Shoulder")
	local leftShoulder = torso:WaitForChild("Left Shoulder")

	self.character = character
	self.humanoid = humanoid
	self.humanoidRootPart = humanoidRootPart
	self.torso = torso
	self.head = head
	self.shoulders = {
		rightMotor = rightShoulder,
		leftMotor = leftShoulder,
		defaultRightC0 = rightShoulder.C0,
		defaultLeftC0 = leftShoulder.C0,
		currentRightC0 = rightShoulder.C0,
		currentLeftC0 = leftShoulder.C0,
	}
	self.gripState = {
		weld = nil,
		cachedWeld = nil,
		baseC0 = nil,
		basePosition = nil,
		baseRotation = nil,
		currentRotation = nil,
	}
end

function viewModelController:update(deltaTime: number)
	local stateValues = self.__vars
	local shoulders = self.shoulders
	local character = self.character
	local humanoid = self.humanoid
	local torso = self.torso
	local head = self.head
	local camera = workspace.CurrentCamera

	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	if torso == nil or torso.Parent == nil or head == nil or head.Parent == nil then
		return
	end

	if camera == nil or shoulders == nil or shoulders.rightMotor == nil or shoulders.leftMotor == nil then
		return
	end

	local isFirstPerson = helpers.isFirstPerson(character)

	if isFirstPerson then
		if stateValues.isHandFollowEnabled then
			gripMotion.updateHandFollow(self, camera, deltaTime)
		end
	elseif stateValues.isHandFollowEnabled and stateValues.shouldReturnGrip then
		gripMotion.returnGrip(self, deltaTime)
	end

	local shoulderReplication = nil
	if stateValues.isArmFollowEnabled then
		shoulderReplication = armMotion.updateArmFollow(self, camera, isFirstPerson, deltaTime)
	elseif stateValues.shouldReturnArms then
		armMotion.returnArms(self, deltaTime)
	end

	replication.updateShoulderReplication(self, deltaTime, shoulderReplication)
end

function viewModelController:init()
	local controllerConfig = self.config

	self:preload()
	itemState.bindItemSignals(self)

	runService:UnbindFromRenderStep(controllerConfig.renderStepName)

	runService:BindToRenderStep(
		controllerConfig.renderStepName,
		controllerConfig.renderPriority,
		function(deltaTime: number)
			self:update(deltaTime)
		end
	)
end

function viewModelController.new()
	local self = setmetatable({}, viewModelController)

	self.player = player
	self.config = config
	self.connections = {}
	self.controllers = {}
	self.__vars = table.clone(viewModelController.__vars)
	self.replication = characterReplicationController.getShared()
	self.shoulders = nil
	self.gripState = nil
	self.recoilPositionSpring = spring.new(Vector3.zero)
	self.recoilRotationSpring = spring.new(Vector3.zero)
	self.recoilRandom = Random.new()

	task.defer(self.init, self)

	return self
end

function viewModelController:destroy()
	local connections = self.connections
	local controllerConfig = self.config

	runService:UnbindFromRenderStep(controllerConfig.renderStepName)

	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	self.connections = nil
	self.controllers = nil
	self.__vars = nil
	self.shoulders = nil
	self.gripState = nil
	self.heldItem = nil
	self.itemHandle = nil
	self.recoilPositionSpring = nil
	self.recoilRotationSpring = nil
	self.recoilRandom = nil
	self.config = nil
	setmetatable(self, nil)
end

return viewModelController
