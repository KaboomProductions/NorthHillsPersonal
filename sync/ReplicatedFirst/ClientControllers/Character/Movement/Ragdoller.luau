local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

local player = players.LocalPlayer

local ragdollerController = {}
ragdollerController.__index = ragdollerController

function ragdollerController:preload()
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid") or self.character:WaitForChild("Humanoid")
	self.animator = self.humanoid:FindFirstChildOfClass("Animator")
end

function ragdollerController:onRagdollUpdate(newValue: boolean)
	if newValue == nil then
		newValue = false
	end

	self.currentValue = newValue
	self.oppositeValue = not newValue

	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, self.oppositeValue)
	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, self.oppositeValue)
	self.humanoid:ChangeState(newValue and Enum.HumanoidStateType.Ragdoll or Enum.HumanoidStateType.GettingUp)

	self.humanoid.PlatformStand = newValue
end

function ragdollerController:init()
	self:preload()

	self.connections.onRagdollUpdate = networking.events.ragdollUpdate.OnClientEvent:Connect(function(newValue)
		self:onRagdollUpdate(newValue)
	end)
end

function ragdollerController.new()
	local self = setmetatable({}, ragdollerController)

	self.connections = {}
	self.character = nil
	self.humanoid = nil

	task.defer(self.init, self)

	return self
end

function ragdollerController:destroy()
	local connections = self.connections

	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	table.clear(connections)
	setmetatable(self, nil)
end

return ragdollerController
