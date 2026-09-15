local replicatedStorage = game:GetService("ReplicatedStorage")

local bootstrapUtilities = require(replicatedStorage.SharedUtilities.Bootstrap)

local charactersFolder = workspace.Components.Characters

local characterController = {}
characterController.__index = characterController

function characterController:preload()
	for _, basePart in ipairs(self.character:GetDescendants()) do
		if not basePart:IsA("BasePart") then
			continue
		end

		basePart.AudioCanCollide = false
		basePart.CanCollide = false
		basePart.CanQuery = false
		basePart.CollisionGroup = "Player"

		if basePart.Name == "Torso" then
			basePart.CanCollide = true
		end
	end

	self.character.Parent = charactersFolder
	self.character.PrimaryPart = self.character:FindFirstChild("HumanoidRootPart")

	self.humanoid = self.character:FindFirstChildOfClass("Humanoid")
	self.humanoid.BreakJointsOnDeath = false
	self.humanoid.RequiresNeck = false
end

function characterController:init()
	local player = self.player
	local character = self.character

	self:preload()

	self.coreControllers = bootstrapUtilities.startModules(script.Core, player, character)
	self.stateControllers = bootstrapUtilities.startModules(script.States, player, character)
end

function characterController.new(player: Player, character: Model)
	local self = setmetatable({}, characterController)

	self.player = player
	self.character = character
	self.connections = {}
	self.coreControllers = {}
	self.stateControllers = {}

	task.defer(self.init, self)

	return self
end

function characterController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	bootstrapUtilities.destroyModules(self.coreControllers)
	bootstrapUtilities.destroyModules(self.stateControllers)

	table.clear(self)
	setmetatable(self, nil)
end

return characterController
