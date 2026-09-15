local replicatedFirst = game:GetService("ReplicatedFirst")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

local player = players.LocalPlayer

local clientData = require(replicatedFirst.ClientData)

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
		lastAppliedOffset = headBobOffset

		camera.CFrame = baseCFrame * headBobOffset
	end)

	runService:BindToRenderStep("ragdollCamera", ragdollCameraPriority, function(deltaTime: number)
		self:applyRagdollCamera(deltaTime)
	end)
end

function cameraController.new()
	local self = setmetatable({}, cameraController)

	self.controllers = {}
	self.__vars = table.clone(cameraController.__vars)

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

	self.__vars = nil
	setmetatable(self, nil)
end

return cameraController
