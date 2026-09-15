local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local clientData = require(replicatedFirst.ClientData)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local config = require(script.Config)
local tiltCalculator = require(script.TiltCalculator)

local player = players.LocalPlayer
local identityCFrame = CFrame.identity

local tiltController = {}
tiltController.__index = tiltController
tiltController.__vars = {
	currentTilt = 0,
}

function tiltController:cacheCharacter()
	local character = player.Character
	if character == nil then
		self.character = nil
		self.humanoid = nil
		return
	end

	self.character = character
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
end

function tiltController:computeOffset(deltaTime: number): CFrame
	local stateValues = self.__vars
	local targetTilt = 0

	if not clientData.isCameraLocked() then
		targetTilt = tiltCalculator.calculateTargetTilt(self)
	end

	stateValues.currentTilt =
		mathUtilities.exponentialLerp(stateValues.currentTilt, targetTilt, self.config.tiltSmoothSpeed, deltaTime)

	if math.abs(stateValues.currentTilt) < 0.001 then
		return identityCFrame
	end

	return CFrame.Angles(0, 0, -math.rad(stateValues.currentTilt))
end

function tiltController:onCharacterAdded()
	self:cacheCharacter()
end

function tiltController:init()
	self:cacheCharacter()

	self.connections.characterAdded = player.CharacterAdded:Connect(function()
		self:onCharacterAdded()
	end)
end

function tiltController.new()
	local self = setmetatable({}, tiltController)

	self.config = config
	self.connections = {}
	self.__vars = table.clone(tiltController.__vars)

	task.defer(self.init, self)

	return self
end

function tiltController:destroy()
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

return tiltController
