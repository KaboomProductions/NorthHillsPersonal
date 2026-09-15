local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")
local serverStorage = game:GetService("ServerStorage")

local gameValues = replicatedStorage.Values
local roundCycleValues = gameValues.RoundCycle
local timeCycleValues = roundCycleValues.TimeCycle
local nightTimeValue = timeCycleValues.NightTime

local serverAssets = serverStorage.ServerAssets
local scoreTrackerController = require(serverAssets.ScoreTracker)
local playerMemoryController = require(serverAssets.PlayerMemory)
local buildingMapping = playerMemoryController.mapping

local bucketUtilities = require(replicatedStorage.SharedUtilities.BucketUtils)
local characterControllerModule = require(serverScriptService.Controllers.Character)

local playerController = {}
playerController.__index = playerController

function playerController:preload()
	self.player:SetAttribute("Money", 0)
	self.player:SetAttribute("Survivals", 0)

	if not nightTimeValue.Value then
		self.player:SetAttribute("Survived", true)
	end

	scoreTrackerController.startSession(self.player)
end

--// memory stuff is for phils ai
function playerController:updatePlayerMemory(character: Model)
	local rootPart = character.PrimaryPart
	local position = rootPart and rootPart.Position

	if not position then
		return
	end

	for buildingName, buildingData in buildingMapping do
		for roomName, roomPart in buildingData.rooms do
			if not roomPart:IsA("BasePart") then
				continue
			end

			if bucketUtilities.checkInRegion(roomPart, position) then
				local roomKey = buildingName .. "/" .. roomName

				if roomKey ~= self.lastRoomKey then
					self.lastRoomKey = roomKey
					playerMemoryController:recordVisit(self.player, buildingName, roomName)
				end

				return
			end
		end
	end
end

function playerController:onCharacterAdded(character: Model)
	self:onCharacterRemoving()

	local player = self.player
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	self.characterController = characterControllerModule.new(player, character)

	if humanoid then
		self.characterConnections.humanoidDied = humanoid.Died:Once(function()
			player:SetAttribute("Survived", false)
			character:SetAttribute("RagdollTimer", math.huge)
		end)

		task.spawn(function()
			while player and character and self.characterController do
				self:updatePlayerMemory(character)

				task.wait(0.1)
			end
		end)
	end
end

function playerController:onCharacterRemoving()
	local characterConnections = self.characterConnections

	for key, connection in pairs(characterConnections) do
		connection:Disconnect()
		characterConnections[key] = nil
	end

	if self.characterController then
		self.characterController:destroy()
		self.characterController = nil
	end
end

function playerController:init()
	local player = self.player
	local connections = self.connections

	self:preload()

	--// init player memory
	playerMemoryController:init(player)

	connections.characterAdded = player.CharacterAdded:Connect(function(character)
		self:onCharacterAdded(character)
	end)

	connections.characterRemoving = player.CharacterRemoving:Connect(function()
		self:onCharacterRemoving()
	end)

	if player.Character then
		self:onCharacterAdded(player.Character)
	end
end

function playerController.new(player: Player)
	local self = setmetatable({}, playerController)

	self.player = player
	self.connections = {}
	self.characterConnections = {}
	self.characterController = nil

	task.defer(self.init, self)

	return self
end

function playerController:destroy()
	local connections = self.connections

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	--// clean player memory
	playerMemoryController:cleanUp(self.player)

	self:onCharacterRemoving()

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return playerController
