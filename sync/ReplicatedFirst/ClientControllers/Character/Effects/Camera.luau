local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

local player = players.LocalPlayer

local clientData = require(replicatedFirst.ClientData)
local spring = require(replicatedStorage.SharedClasses.Spring)

local cameraController = {}
cameraController.__index = cameraController
cameraController.__vars = {
	isRagdollCameraActive = false,
	ragdollTransitionElapsedSeconds = 0,
	ragdollTransitionStartCFrame = CFrame.identity,
}

local positionController = require(script.Position)
local tiltController = require(script.Tilt)
local headBobController = require(script.HeadBob)

local cameraEffectsPriority = Enum.RenderPriority.Camera.Value + 1
local ragdollCameraPriority = Enum.RenderPriority.Last.Value
local ragdollTransitionDurationSeconds = 0.25

local function configureSpring(activeSpring, springConfig)
	activeSpring.mass = springConfig.mass or 5
	activeSpring.force = springConfig.force or 50
	activeSpring.damping = springConfig.damping or 4
	activeSpring.speed = springConfig.speed or 4
end

local function resetSpring(activeSpring)
	activeSpring.target = Vector3.zero
	activeSpring.position = Vector3.zero
	activeSpring.velocity = Vector3.zero
end

local function randomizeVector3(baseVector: Vector3, maximumVariation: Vector3, randomGenerator: Random): Vector3
	return Vector3.new(
		baseVector.X + randomGenerator:NextNumber(-maximumVariation.X, maximumVariation.X),
		baseVector.Y + randomGenerator:NextNumber(-maximumVariation.Y, maximumVariation.Y),
		baseVector.Z + randomGenerator:NextNumber(-maximumVariation.Z, maximumVariation.Z)
	)
end

function cameraController:computeRecoilOffset(deltaTime: number): (CFrame, number)
	local recoilSpring = self.recoilSpring
	local settledPitchIncrementRadians = 0

	for _, impulse in clientData.cameraRecoilImpulses do
		local recoilConfig = impulse.config
		configureSpring(recoilSpring, recoilConfig.spring or {})

		local recoilMultiplier = impulse.isAiming and (recoilConfig.aimingMultiplier or 1) or 1
		local rotationVelocityRadians = recoilConfig.rotationVelocityRadians or Vector3.zero
		local rotationVelocityVariationRadians = recoilConfig.rotationVelocityVariationRadians or Vector3.zero
		local rotationVelocity = randomizeVector3(
			rotationVelocityRadians,
			rotationVelocityVariationRadians,
			self.recoilRandom
		) * recoilMultiplier
		local pitchIncrementRadians = recoilConfig.settledPitchIncrementRadians or 0
		local pitchVariationRadians = recoilConfig.settledPitchVariationRadians or 0
		settledPitchIncrementRadians += (pitchIncrementRadians + self.recoilRandom:NextNumber(
			-pitchVariationRadians,
			pitchVariationRadians
		)) * recoilMultiplier

		recoilSpring:shove(rotationVelocity)
	end

	table.clear(clientData.cameraRecoilImpulses)

	local rotationRadians = recoilSpring:update(deltaTime)
	return CFrame.Angles(rotationRadians.X, rotationRadians.Y, rotationRadians.Z), settledPitchIncrementRadians
end

function cameraController:applyRagdollCamera(deltaTime: number)
	local camera = workspace.CurrentCamera
	if camera == nil or player:GetAttribute("InMenu") then
		return
	end

	local stateValues = self.__vars
	local ragdollCameraCFrame = self.controllers.position:getRagdollCameraCFrame()
	if ragdollCameraCFrame == nil then
		stateValues.isRagdollCameraActive = false
		stateValues.ragdollTransitionElapsedSeconds = 0
		return
	end

	if not stateValues.isRagdollCameraActive then
		stateValues.isRagdollCameraActive = true
		stateValues.ragdollTransitionElapsedSeconds = 0
		stateValues.ragdollTransitionStartCFrame = camera.CFrame
	end

	local elapsedSeconds =
		math.min(stateValues.ragdollTransitionElapsedSeconds + deltaTime, ragdollTransitionDurationSeconds)
	stateValues.ragdollTransitionElapsedSeconds = elapsedSeconds

	if elapsedSeconds >= ragdollTransitionDurationSeconds then
		camera.CFrame = ragdollCameraCFrame
		return
	end

	local transitionAlpha = elapsedSeconds / ragdollTransitionDurationSeconds
	local easedTransitionAlpha = tweenService:GetValue(transitionAlpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	camera.CFrame = stateValues.ragdollTransitionStartCFrame:Lerp(ragdollCameraCFrame, easedTransitionAlpha)
end

function cameraController:init()
	local controllers = self.controllers

	controllers.position = positionController.new()
	controllers.tilt = tiltController.new()
	controllers.headBob = headBobController.new()

	table.clear(clientData.cameraLocks)
	table.clear(clientData.cameraRecoilImpulses)

	local lastAppliedOffset = CFrame.identity
	local lockedCameraRotation = nil
	local lockedBaseCFrame = nil

	runService:BindToRenderStep("cameraEffects", cameraEffectsPriority, function(deltaTime: number)
		local camera = workspace.CurrentCamera
		if camera == nil or player:GetAttribute("InMenu") then
			return
		end

		local baseCFrame = camera.CFrame * lastAppliedOffset:Inverse()
		local ragdollCameraCFrame = controllers.position:getRagdollCameraCFrame()
		if ragdollCameraCFrame ~= nil then
			lastAppliedOffset = CFrame.identity
			lockedCameraRotation = nil
			lockedBaseCFrame = nil
			table.clear(clientData.cameraRecoilImpulses)
			resetSpring(self.recoilSpring)
			return
		end

		if clientData.isCameraLocked() then
			lockedCameraRotation = lockedCameraRotation or (baseCFrame - baseCFrame.Position)
			baseCFrame = CFrame.new(baseCFrame.Position) * lockedCameraRotation

			if controllers.position:isLockTargetReached() then
				lockedBaseCFrame = lockedBaseCFrame or baseCFrame
				baseCFrame = lockedBaseCFrame
			else
				lockedBaseCFrame = nil
			end
		else
			lockedCameraRotation = nil
			lockedBaseCFrame = nil
		end

		local tiltOffset = controllers.tilt:computeOffset(deltaTime)
		baseCFrame = baseCFrame * tiltOffset

		local headBobOffset = controllers.headBob:computeOffset(deltaTime)
		local recoilOffset, settledPitchIncrementRadians = self:computeRecoilOffset(deltaTime)
		if settledPitchIncrementRadians ~= 0 then
			local settledPitchOffset = CFrame.Angles(settledPitchIncrementRadians, 0, 0)
			baseCFrame *= settledPitchOffset

			if lockedCameraRotation ~= nil then
				lockedCameraRotation *= settledPitchOffset
			end
			if lockedBaseCFrame ~= nil then
				lockedBaseCFrame *= settledPitchOffset
			end
		end

		lastAppliedOffset = recoilOffset * headBobOffset

		camera.CFrame = baseCFrame * recoilOffset * headBobOffset
	end)

	runService:BindToRenderStep("ragdollCamera", ragdollCameraPriority, function(deltaTime: number)
		self:applyRagdollCamera(deltaTime)
	end)
end

function cameraController.new()
	local self = setmetatable({}, cameraController)

	self.controllers = {}
	self.__vars = table.clone(cameraController.__vars)
	self.recoilSpring = spring.new(Vector3.zero)
	self.recoilRandom = Random.new()

	task.defer(self.init, self)

	return self
end

function cameraController:destroy()
	runService:UnbindFromRenderStep("cameraEffects")
	runService:UnbindFromRenderStep("ragdollCamera")

	local controllers = self.controllers

	for controllerName, controller in pairs(controllers) do
		if type(controller) == "table" and type(controller.destroy) == "function" then
			controller:destroy()
		end

		controllers[controllerName] = nil
	end

	table.clear(clientData.cameraRecoilImpulses)
	self.recoilSpring = nil
	self.recoilRandom = nil
	self.__vars = nil
	setmetatable(self, nil)
end

return cameraController
