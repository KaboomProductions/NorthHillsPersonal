local lineResolver = require(script.Parent.LineResolver)

local dialogueSessionManager = {}
dialogueSessionManager.__index = dialogueSessionManager

type dialogueConfig = {
	greetingCooldownSeconds: number,
	exchangeCooldownSeconds: number,
	itemCommentCooldownSeconds: number,
}

type dialogueSession = {
	player: Player,
	npcId: string,
	npcData: { [string]: any },
	stats: lineResolver.playerStats,
	thresholds: lineResolver.thresholds,
	lastInteractionTime: number,
	isQueued: boolean,
}

type npcTimers = { [string]: number }
type exchangeTimers = { [string]: npcTimers }
type itemTimers = { [string]: npcTimers }

local function getOrCreateUserBucket<T>(bucketsByUserId: { [number]: T }, userId: number, defaultValue: T): T
	local existingBucket = bucketsByUserId[userId]
	if existingBucket ~= nil then
		return existingBucket
	end

	bucketsByUserId[userId] = defaultValue
	return defaultValue
end

function dialogueSessionManager:createSession(player: Player, npcId: string, npcData: { [string]: any }): dialogueSession
	local stats = lineResolver.getPlayerStats(player, npcId)
	local activeSession: dialogueSession = {
		player = player,
		npcId = npcId,
		npcData = npcData,
		stats = stats,
		thresholds = npcData.conditions or {},
		lastInteractionTime = os.clock(),
		isQueued = false,
	}

	self.sessionsByPlayer[player] = activeSession
	return activeSession
end

function dialogueSessionManager:getSession(player: Player): dialogueSession?
	return self.sessionsByPlayer[player]
end

function dialogueSessionManager:clearSession(player: Player)
	local activeSession = self:getSession(player)
	if activeSession == nil then
		return
	end

	local userId = player.UserId
	local greetingTimesByNpcId = getOrCreateUserBucket(self.greetingTimesByUserId, userId, {})
	greetingTimesByNpcId[activeSession.npcId] = os.clock()

	local exchangeTimesByNpcId = self.exchangeTimesByUserId[userId]
	if exchangeTimesByNpcId ~= nil then
		exchangeTimesByNpcId[activeSession.npcId] = nil
	end

	self.sessionsByPlayer[player] = nil
end

function dialogueSessionManager:wasRecentlyGreeted(player: Player, npcId: string): boolean
	local greetingTimesByNpcId = self.greetingTimesByUserId[player.UserId]
	local lastGreetingTime = greetingTimesByNpcId and greetingTimesByNpcId[npcId]
	if lastGreetingTime == nil then
		return false
	end

	return (os.clock() - lastGreetingTime) < self.config.greetingCooldownSeconds
end

function dialogueSessionManager:getExchangeTimestamp(player: Player, npcId: string, choiceId: string): number?
	local exchangeTimesByNpcId = self.exchangeTimesByUserId[player.UserId]
	local exchangeTimesByChoiceId = exchangeTimesByNpcId and exchangeTimesByNpcId[npcId]
	return exchangeTimesByChoiceId and exchangeTimesByChoiceId[choiceId]
end

function dialogueSessionManager:markExchange(player: Player, npcId: string, choiceId: string)
	local exchangeTimesByNpcId = getOrCreateUserBucket(self.exchangeTimesByUserId, player.UserId, {})
	local exchangeTimesByChoiceId = exchangeTimesByNpcId[npcId]

	if exchangeTimesByChoiceId == nil then
		exchangeTimesByChoiceId = {}
		exchangeTimesByNpcId[npcId] = exchangeTimesByChoiceId
	end

	exchangeTimesByChoiceId[choiceId] = os.clock()
end

function dialogueSessionManager:getItemCommentTimestamp(player: Player, npcId: string, itemId: string): number?
	local itemCommentTimesByNpcId = self.itemCommentTimesByUserId[player.UserId]
	local itemCommentTimesByItemId = itemCommentTimesByNpcId and itemCommentTimesByNpcId[npcId]
	return itemCommentTimesByItemId and itemCommentTimesByItemId[itemId]
end

function dialogueSessionManager:markItemComment(player: Player, npcId: string, itemId: string)
	local itemCommentTimesByNpcId = getOrCreateUserBucket(self.itemCommentTimesByUserId, player.UserId, {})
	local itemCommentTimesByItemId = itemCommentTimesByNpcId[npcId]

	if itemCommentTimesByItemId == nil then
		itemCommentTimesByItemId = {}
		itemCommentTimesByNpcId[npcId] = itemCommentTimesByItemId
	end

	itemCommentTimesByItemId[itemId] = os.clock()
end

function dialogueSessionManager:cleanupPlayer(player: Player)
	self.sessionsByPlayer[player] = nil
	self.greetingTimesByUserId[player.UserId] = nil
	self.exchangeTimesByUserId[player.UserId] = nil
	self.itemCommentTimesByUserId[player.UserId] = nil
end

function dialogueSessionManager.new(config: dialogueConfig)
	local self = setmetatable({}, dialogueSessionManager)

	self.config = config
	self.sessionsByPlayer = {}
	self.greetingTimesByUserId = {} :: exchangeTimers
	self.exchangeTimesByUserId = {} :: exchangeTimers
	self.itemCommentTimesByUserId = {} :: itemTimers

	return self
end

return dialogueSessionManager
