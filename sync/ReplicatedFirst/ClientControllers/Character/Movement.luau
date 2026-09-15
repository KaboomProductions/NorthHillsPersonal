local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local runService = game:GetService("RunService")

local replicatedStorage = game:GetService("ReplicatedStorage")

local moduleLoader = require(replicatedFirst.ClientUtilities.ModuleLoader)
local clientData = require(replicatedFirst.ClientData)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local player = players.LocalPlayer
local lerpEpsilon = 0.001
local movementController = {}
movementController.__index = movementController
movementController.__vars = {
	speedLerpSpeed = 5,
	fieldOfViewLerpSpeed = 3,
}

function movementController:preload()
	table.clear(clientData.movementLocks)
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid") or self.character:WaitForChild("Humanoid")
	self.camera = workspace.CurrentCamera
end

function movementController:onCharacterAdded(character: Model)
	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
end

function movementController:onCurrentCameraChanged()
	self.camera = workspace.CurrentCamera
end

function movementController:update(deltaTime: number)
	local stateValues = self.__vars
	local character = self.character
	local humanoid = self.humanoid
	local camera = self.camera

	if character == nil or humanoid == nil or camera == nil then
		return
	end

	if character.Parent == nil or humanoid.Parent == nil then
		return
	end

	local currentSpeed = humanoid.WalkSpeed
	local targetSpeed = clientData.getTotalSpeed()
	if character:HasTag("MovesetTransition") then
		targetSpeed = 0
	end

	local currentFieldOfView = camera.FieldOfView
	local targetFieldOfView = clientData.getTotalFieldOfView()

	local speedDelta = math.abs(currentSpeed - targetSpeed)
	local fovDelta = math.abs(currentFieldOfView - targetFieldOfView)

	if speedDelta > lerpEpsilon then
		humanoid.WalkSpeed = mathUtilities.lerp(currentSpeed, targetSpeed, stateValues.speedLerpSpeed * deltaTime)
	elseif speedDelta > 0 then
		humanoid.WalkSpeed = targetSpeed
	end

	if fovDelta > lerpEpsilon then
		camera.FieldOfView =
			mathUtilities.lerp(currentFieldOfView, targetFieldOfView, stateValues.fieldOfViewLerpSpeed * deltaTime)
	elseif fovDelta > 0 then
		camera.FieldOfView = targetFieldOfView
	end
end

function movementController:init()
	self:preload()

	self.controllers = moduleLoader.startModules(script)
	self.connections.characterAdded = player.CharacterAdded:Connect(function(character: Model)
		self:onCharacterAdded(character)
	end)
	self.connections.currentCameraChanged = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:onCurrentCameraChanged()
	end)

	runService:UnbindFromRenderStep("ApplyPlayerData")
	runService:BindToRenderStep("ApplyPlayerData", Enum.RenderPriority.Character.Value, function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function movementController.new()
	local self = setmetatable({}, movementController)

	self.connections = {}
	self.controllers = {}
	self.__vars = table.clone(movementController.__vars)
	self.character = nil
	self.humanoid = nil
	self.camera = nil

	task.defer(self.init, self)

	return self
end

function movementController:destroy()
	local connections = self.connections

	runService:UnbindFromRenderStep("ApplyPlayerData")

	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	moduleLoader.destroyModules(self.controllers)
	setmetatable(self, nil)
end

return movementController
