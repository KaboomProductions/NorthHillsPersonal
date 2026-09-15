local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local dialogueConfig = require(script.Config)
local choiceProcessorModule = require(script.ChoiceProcessor)
local queueManagerModule = require(script.QueueManager)
local registryModule = require(script.Registry)
local sessionManagerModule = require(script.SessionManager)
local networking = require(replicatedStorage.Communication.Networking)

local dialogueService = {}
dialogueService.__index = dialogueService
dialogueService.__vars = {
	isInitialized = false,
}

function dialogueService:promoteNextInQueue(npcId: string)
	local npcQueue = self.queueManager:getQueue(npcId)
	if npcQueue == nil then
		return
	end

	npcQueue.activePlayer = nil

	while #npcQueue.queuedPlayers > 0 do
		local nextPlayer = table.remove(npcQueue.queuedPlayers, 1)
		local activeSession = self.sessionManager:getSession(nextPlayer)

		if activeSession == nil or nextPlayer.Parent == nil then
			self.sessionManager:clearSession(nextPlayer)
			continue
		end

		npcQueue.activePlayer = nextPlayer
		activeSession.isQueued = false
		activeSession.lastInteractionTime = os.clock()

		self.choiceProcessor:sendGreeting(activeSession, { promoted = true }, true)
		return
	end
end

function dialogueService:removePlayerFromQueues(player: Player)
	for npcId, npcQueue in pairs(self.queueManager.queuesByNpcId) do
		self.queueManager:removePlayer(npcId, player)

		if npcQueue.activePlayer == player then
			self:promoteNextInQueue(npcId)
		end
	end
end

function dialogueService:closeSession(player: Player)
	local activeSession = self.sessionManager:getSession(player)
	if activeSession == nil then
		self:removePlayerFromQueues(player)
		return
	end

	local npcId = activeSession.npcId
	self.sessionManager:clearSession(player)

	local npcQueue = self.queueManager:getQueue(npcId)
	if npcQueue == nil then
		return
	end

	if npcQueue.activePlayer == player then
		self:promoteNextInQueue(npcId)
	else
		self.queueManager:removePlayer(npcId, player)
	end
end

function dialogueService:onRequestDialogue(player: Player, npcId: string)
	if type(npcId) ~= "string" then
		return
	end

	if self.sessionManager:getSession(player) ~= nil then
		self:closeSession(player)
	end

	local npcData = self.registry:getNpcData(npcId)
	if npcData == nil then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil then
		return
	end

	if npcData.validateDistance ~= nil and not npcData.validateDistance(rootPart.Position) then
		return
	end

	local npcQueue = self.queueManager:getOrCreateQueue(npcId)
	local activeSession = self.sessionManager:createSession(player, npcId, npcData)

	if npcQueue.activePlayer == nil then
		npcQueue.activePlayer = player
		activeSession.isQueued = false
		self.choiceProcessor:sendGreeting(activeSession)
		return
	end

	self.queueManager:enqueuePlayer(npcId, player)
	activeSession.isQueued = true

	local queuePosition = self.queueManager:getPosition(npcId, player) or #npcQueue.queuedPlayers
	self.choiceProcessor:sendBusyResponse(activeSession, queuePosition)
end

function dialogueService:onSelectChoice(player: Player, choiceId: string)
	if type(choiceId) ~= "string" then
		return
	end

	local activeSession = self.sessionManager:getSession(player)
	if activeSession == nil then
		return
	end

	self.choiceProcessor:processRemoteChoice(activeSession, choiceId)
end

function dialogueService:onCloseDialogue(player: Player)
	self:closeSession(player)
end

function dialogueService:onPlayerRemoving(player: Player)
	self:closeSession(player)
	self.sessionManager:cleanupPlayer(player)
end

function dialogueService:sendContextLine(player: Player, lineCategory: string)
	self.choiceProcessor:sendContextLine(player, lineCategory)
end

function dialogueService:canTransact(player: Player, npcId: string): boolean
	local npcQueue = self.queueManager:getQueue(npcId)
	return npcQueue ~= nil and npcQueue.activePlayer == player
end

function dialogueService:getQueuePosition(player: Player, npcId: string): number?
	return self.queueManager:getPosition(npcId, player)
end

function dialogueService:checkImpatience(player: Player)
	self.choiceProcessor:checkImpatience(player)
end

function dialogueService:sendNightLine(player: Player)
	local activeSession = self.sessionManager:getSession(player)
	if activeSession == nil then
		return
	end

	self.choiceProcessor:sendLineFromCategory(activeSession, "nightStarting", "forceCloseShop")
	self:closeSession(player)
end

function dialogueService:closeAllSessions(npcId: string)
	local npcQueue = self.queueManager:getQueue(npcId)
	if npcQueue == nil then
		return
	end

	local activePlayer = npcQueue.activePlayer
	if activePlayer ~= nil then
		local activeSession = self.sessionManager:getSession(activePlayer)
		if activeSession ~= nil then
			self.choiceProcessor:sendLineFromCategory(activeSession, "nightStarting", "forceCloseShop")
		end

		self.sessionManager:clearSession(activePlayer)
	end

	for _, queuedPlayer in ipairs(npcQueue.queuedPlayers) do
		if self.sessionManager:getSession(queuedPlayer) ~= nil then
			networking.events.forceCloseDialogue:FireClient(queuedPlayer, {
				npcId = npcId,
				action = "forceCloseShop",
			})
			self.sessionManager:clearSession(queuedPlayer)
		end
	end

	table.clear(npcQueue.queuedPlayers)
	npcQueue.activePlayer = nil
end

function dialogueService:init()
	local stateValues = self.__vars
	local connections = self.connections

	if stateValues.isInitialized then
		return
	end

	self.registry:load()

	connections.playerRemoving = players.PlayerRemoving:Connect(function(player: Player)
		self:onPlayerRemoving(player)
	end)

	connections.requestDialogue = networking.events.requestDialogue.OnServerEvent:Connect(
		function(player: Player, npcId: string)
			self:onRequestDialogue(player, npcId)
		end
	)

	connections.selectChoice = networking.events.selectChoice.OnServerEvent:Connect(
		function(player: Player, choiceId: string)
			self:onSelectChoice(player, choiceId)
		end
	)

	connections.closeDialogue = networking.events.closeDialogue.OnServerEvent:Connect(function(player: Player)
		self:onCloseDialogue(player)
	end)

	stateValues.isInitialized = true
end

function dialogueService.new()
	local self = setmetatable({}, dialogueService)

	self.__vars = table.clone(dialogueService.__vars)
	self.connections = {}
	self.registry = registryModule.new()
	self.queueManager = queueManagerModule.new()
	self.sessionManager = sessionManagerModule.new(dialogueConfig)
	self.choiceProcessor = choiceProcessorModule.new({
		registry = self.registry,
		sessionManager = self.sessionManager,
	})

	task.defer(self.init, self)

	return self
end

function dialogueService:destroy()
	local connections = self.connections

	for key, connection in pairs(connections) do
		connection:Disconnect()
		connections[key] = nil
	end

	table.clear(connections)
end

return dialogueService
