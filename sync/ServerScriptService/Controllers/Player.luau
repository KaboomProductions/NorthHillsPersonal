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
local playerData = require(serverScriptService.GameHandler.PlayerData)

local playerController = {}
playerController.__index = playerController

local function readPersistedCounter(profileData: { [string]: any }?, counterName: string): number
	local storedCounter = profileData and profileData[counterName]
	if typeof(storedCounter) ~= "number" or storedCounter ~= storedCounter or math.abs(storedCounter) == math.huge then
		return 0
	end
	return math.max(math.floor(storedCounter), 0)
end

function playerController:preload()
	local player = self.player
	local profileData = playerData.get(player)

	player:SetAttribute("Money", readPersistedCounter(profileData, "Money"))
	player:SetAttribute("Survivals", readPersistedCounter(profileData, "Survivals"))

	if not nightTimeValue.Value then
		player:SetAttribute("Survived", true)
	end

	scoreTrackerController.startSession(player)
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

	local characterController = characterControllerModule.new(player, character)
	self.characterController = characterController

	if humanoid then
		self.characterConnections.humanoidDied = humanoid.Died:Once(function()
			player:SetAttribute("Survived", false)
			character:SetAttribute("RagdollTimer", math.huge)
		end)

		self.memoryThread = task.spawn(function()
			local isCurrentCharacter = function()
				return self.characterController == characterController and character.Parent ~= nil
			end

			while isCurrentCharacter() do
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

	local memoryThread = self.memoryThread
	if memoryThread then
		if coroutine.running() ~= memoryThread then
			task.cancel(memoryThread)
		end
		self.memoryThread = nil
	end

	self.lastRoomKey = nil

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
	self.memoryThread = nil
	self.lastRoomKey = nil

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
