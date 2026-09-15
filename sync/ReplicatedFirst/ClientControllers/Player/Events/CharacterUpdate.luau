local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local networking = require(replicatedStorage.Communication.Networking)

local config = require(script.Config)
local packetHandler = require(script.PacketHandler)
local smoothing = require(script.Smoothing)
local targetState = require(script.TargetState)

local newEventController = {}
newEventController.__index = newEventController
newEventController.__vars = config

local function getDistanceToCharacter(localCharacter: Model?, remoteCharacter: Model): number
	if localCharacter == nil or localCharacter.PrimaryPart == nil then
		return 0
	end

	local remotePrimary = remoteCharacter.PrimaryPart
	if remotePrimary == nil then
		return 0
	end

	return (localCharacter.PrimaryPart.Position - remotePrimary.Position).Magnitude
end

function newEventController:applyMotorTargets(deltaTime: number)
	local configValues = self.__vars
	local nearDistance = configValues.nearDistanceStuds
	local farDistance = configValues.farDistanceStuds
	local cullDistance = configValues.cullDistanceStuds
	local nearSpeed = configValues.smoothingSpeed
	local farSpeed = configValues.farSmoothingSpeed
	local localCharacter = players.LocalPlayer and players.LocalPlayer.Character

	for otherPlayer, playerState in pairs(self.playerStates) do
		local character = targetState.getCharacter(otherPlayer)
		if character == nil or character.Parent == nil then
			self.playerStates[otherPlayer] = nil
			continue
		end

		local distance = getDistanceToCharacter(localCharacter, character)

		--// Skip characters beyond cull distance entirely.
		if distance > cullDistance then
			continue
		end

		--// Blend smoothing speed between near and far based on distance.
		local distanceAlpha = math.clamp((distance - nearDistance) / (farDistance - nearDistance), 0, 1)
		local smoothingSpeed = nearSpeed + (farSpeed - nearSpeed) * distanceAlpha

		smoothing.applyMotorTargets(self, playerState, deltaTime, smoothingSpeed)
	end

	local previewState = self.previewState
	if previewState == nil then
		return
	end

	local previewCharacter = targetState.getReplicationTestingCharacter()
	if previewCharacter == nil or previewCharacter.Parent == nil then
		self.previewState = nil
		return
	end

	smoothing.applyMotorTargets(self, previewState, deltaTime, nearSpeed)
end

function newEventController:handlePacket(otherPlayer: Player, packet)
	packetHandler.handlePacket(self, otherPlayer, packet)
end

function newEventController.new()
	local self = setmetatable({}, newEventController)

	self.connections = {}
	self.playerStates = {}
	self.previewState = nil
	self.__vars = table.clone(newEventController.__vars)

	runService:UnbindFromRenderStep(self.__vars.renderStepName)

	self.connections.characterUpdate = networking.events.characterUpdate.OnClientEvent:Connect(
		function(otherPlayer, replicationPacket)
			self:handlePacket(otherPlayer, replicationPacket)
		end
	)
	self.connections.playerRemoving = players.PlayerRemoving:Connect(function(otherPlayer)
		self.playerStates[otherPlayer] = nil
	end)

	runService:BindToRenderStep(
		self.__vars.renderStepName,
		Enum.RenderPriority.Character.Value,
		function(deltaTime: number)
			self:applyMotorTargets(deltaTime)
		end
	)

	return self
end

function newEventController:destroy()
	runService:UnbindFromRenderStep(self.__vars.renderStepName)

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	table.clear(self.playerStates)
	self.previewState = nil
	table.clear(self.connections)
	setmetatable(self, nil)
end

return newEventController
