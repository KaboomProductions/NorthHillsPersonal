local replicatedStorage = game:GetService("ReplicatedStorage")

local lineResolver = require(script.Parent.LineResolver)
local networking = require(replicatedStorage.Communication.Networking)

local dialogueChoiceProcessor = {}
dialogueChoiceProcessor.__index = dialogueChoiceProcessor

type sessionManager = {
	config: {
		exchangeCooldownSeconds: number,
		itemCommentCooldownSeconds: number,
	},
	getSession: (self: sessionManager, player: Player) -> { [string]: any }?,
	wasRecentlyGreeted: (self: sessionManager, player: Player, npcId: string) -> boolean,
	getExchangeTimestamp: (self: sessionManager, player: Player, npcId: string, choiceId: string) -> number?,
	markExchange: (self: sessionManager, player: Player, npcId: string, choiceId: string) -> (),
	getItemCommentTimestamp: (self: sessionManager, player: Player, npcId: string, itemId: string) -> number?,
	markItemComment: (self: sessionManager, player: Player, npcId: string, itemId: string) -> (),
}

type registry = {
	getItemConfig: (self: registry, itemId: string) -> { [string]: any }?,
}

type linePayload = {
	npcId: string,
	npcName: string,
	text: string,
	action: string?,
}

type newInfo = {
	registry: registry,
	sessionManager: sessionManager,
}

local function sendDialogueResponse(player: Player, responsePayload: linePayload)
	networking.events.showDialogueResponse:FireClient(player, responsePayload)
end

function dialogueChoiceProcessor:buildResponse(
	activeSession: { [string]: any },
	text: string,
	action: string?,
	extra: { [string]: any }?
): linePayload
	local response = {
		npcId = activeSession.npcId,
		npcName = activeSession.npcData.displayName or activeSession.npcId,
		text = text,
		action = action,
	}

	if extra ~= nil then
		for key, value in pairs(extra) do
			response[key] = value
		end
	end

	return response
end

function dialogueChoiceProcessor:sendLineFromCategory(
	activeSession: { [string]: any },
	lineCategory: string,
	action: string?,
	extra: { [string]: any }?
): boolean
	local lineTable = activeSession.npcData[lineCategory]
	if lineTable == nil then
		return false
	end

	local line = lineResolver.pickRandomLine(lineTable, activeSession.stats, activeSession.thresholds)
	if line == nil then
		return false
	end

	sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, line, action, extra))
	return true
end

function dialogueChoiceProcessor:sendGreeting(activeSession: { [string]: any }, extra: { [string]: any }?, ignoreCooldown: boolean?)
	if ignoreCooldown ~= true and self.sessionManager:wasRecentlyGreeted(activeSession.player, activeSession.npcId) then
		return
	end

	self:sendLineFromCategory(activeSession, "greetings", nil, extra)
end

function dialogueChoiceProcessor:sendBusyResponse(activeSession: { [string]: any }, queuePosition: number)
	local npcName = activeSession.npcData.displayName or activeSession.npcId
	local busyLines = activeSession.npcData.busy
	local line = lineResolver.pickRandomLine(busyLines, activeSession.stats, activeSession.thresholds)

	if line == nil then
		if queuePosition == 1 then
			line = npcName .. " is with someone. You're next."
		else
			line = npcName .. " is busy. You're #" .. queuePosition .. " in line."
		end
	end

	sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, line, nil, {
		isQueued = true,
		queuePosition = queuePosition,
	}))
end

function dialogueChoiceProcessor:processChoice(activeSession: { [string]: any }, choiceId: string)
	activeSession.lastInteractionTime = os.clock()

	local playerChoices = activeSession.npcData.playerChoices
	if playerChoices == nil then
		return
	end

	local choiceData = playerChoices[choiceId]
	if choiceData == nil then
		return
	end

	local lastExchangeTime = self.sessionManager:getExchangeTimestamp(activeSession.player, activeSession.npcId, choiceId)
	if lastExchangeTime ~= nil and (os.clock() - lastExchangeTime) < self.sessionManager.config.exchangeCooldownSeconds then
		local actionId = choiceData.action or ("open" .. string.upper(string.sub(choiceId, 1, 1)) .. string.sub(choiceId, 2))
		sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, "", actionId))
		return
	end

	local exchanges = choiceData.exchanges
	if exchanges == nil or #exchanges == 0 then
		return
	end

	local chosenExchange = exchanges[math.random(1, #exchanges)]
	local npcLine = lineResolver.pickRandomLine(chosenExchange.zara, activeSession.stats, activeSession.thresholds)
	if npcLine == nil then
		return
	end

	self.sessionManager:markExchange(activeSession.player, activeSession.npcId, choiceId)

	local actionId = choiceData.action or ("open" .. string.upper(string.sub(choiceId, 1, 1)) .. string.sub(choiceId, 2))
	sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, npcLine, actionId, {
		playerLine = chosenExchange.player,
		playerName = activeSession.player.DisplayName,
	}))
end

function dialogueChoiceProcessor:processItemSelect(activeSession: { [string]: any }, itemId: string)
	activeSession.lastInteractionTime = os.clock()

	local itemConfig = self.registry:getItemConfig(itemId)
	if itemConfig == nil then
		return
	end

	local npcComments = itemConfig.zaraComments
	if npcComments == nil then
		return
	end

	local lastCommentTime = self.sessionManager:getItemCommentTimestamp(activeSession.player, activeSession.npcId, itemId)
	if lastCommentTime ~= nil and (os.clock() - lastCommentTime) < self.sessionManager.config.itemCommentCooldownSeconds then
		return
	end

	local line = lineResolver.pickRandomLine(npcComments, activeSession.stats, activeSession.thresholds)
	if line == nil then
		return
	end

	self.sessionManager:markItemComment(activeSession.player, activeSession.npcId, itemId)
	sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, line))
end

function dialogueChoiceProcessor:processBuyConfirm(activeSession: { [string]: any }, itemId: string)
	activeSession.lastInteractionTime = os.clock()

	local itemConfig = self.registry:getItemConfig(itemId)
	if itemConfig == nil then
		return
	end

	local buyConfirmLines = activeSession.npcData.buyConfirm
	if buyConfirmLines == nil then
		return
	end

	local line = lineResolver.pickRandomLine(buyConfirmLines, activeSession.stats, activeSession.thresholds)
	if line == nil then
		return
	end

	sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, line, nil, {
		purchaseResult = "success",
		itemId = itemId,
	}))
end

function dialogueChoiceProcessor:processHaggle(activeSession: { [string]: any }, itemId: string)
	activeSession.lastInteractionTime = os.clock()

	local itemConfig = self.registry:getItemConfig(itemId)
	if itemConfig == nil then
		return
	end

	local haggleLines = activeSession.npcData.haggle
	if haggleLines == nil then
		return
	end

	local line = lineResolver.pickRandomLine(haggleLines, activeSession.stats, activeSession.thresholds)
	if line == nil then
		return
	end

	local discountLines = activeSession.npcData.discounts
	local hasDiscount = discountLines ~= nil
		and lineResolver.pickRandomLine(discountLines, activeSession.stats, activeSession.thresholds) ~= nil

	if hasDiscount and itemConfig.discountedPrice then
		local discountLine = lineResolver.pickRandomLine(discountLines, activeSession.stats, activeSession.thresholds)
		if discountLine ~= nil then
			sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, discountLine, nil, {
				haggleResult = "accepted",
				itemId = itemId,
				discountedPrice = itemConfig.discountedPrice,
			}))
			return
		end
	end

	sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, line, nil, {
		haggleResult = "rejected",
		itemId = itemId,
	}))
end

function dialogueChoiceProcessor:processRemoteChoice(activeSession: { [string]: any }, choiceId: string)
	local itemSelectId = string.match(choiceId, "^itemSelect_(.+)$")
	if itemSelectId ~= nil then
		self:processItemSelect(activeSession, itemSelectId)
		return
	end

	local buyItemId = string.match(choiceId, "^buyConfirm_(.+)$")
	if buyItemId ~= nil then
		if not activeSession.isQueued then
			self:processBuyConfirm(activeSession, buyItemId)
		end
		return
	end

	local haggleItemId = string.match(choiceId, "^haggle_(.+)$")
	if haggleItemId ~= nil then
		if not activeSession.isQueued then
			self:processHaggle(activeSession, haggleItemId)
		end
		return
	end

	if activeSession.isQueued then
		return
	end

	self:processChoice(activeSession, choiceId)
end

function dialogueChoiceProcessor:sendContextLine(player: Player, lineCategory: string)
	local activeSession = self.sessionManager:getSession(player)
	if activeSession == nil then
		return
	end

	self:sendLineFromCategory(activeSession, lineCategory, nil, nil)
end

function dialogueChoiceProcessor:checkImpatience(player: Player)
	local activeSession = self.sessionManager:getSession(player)
	if activeSession == nil or activeSession.isQueued then
		return
	end

	local impatienceLines = activeSession.npcData.impatience
	if impatienceLines == nil then
		return
	end

	local timeSinceLastInteraction = os.clock() - activeSession.lastInteractionTime
	local patienceDrain = math.floor(timeSinceLastInteraction / 10) * 5
	local temporaryStats = table.clone(activeSession.stats)
	temporaryStats.patience = math.max(0, temporaryStats.patience - patienceDrain)

	local line = lineResolver.pickRandomLine(impatienceLines, temporaryStats, activeSession.thresholds)
	if line == nil then
		return
	end

	sendDialogueResponse(activeSession.player, self:buildResponse(activeSession, line))
	activeSession.lastInteractionTime = os.clock()
end

function dialogueChoiceProcessor.new(info: newInfo)
	local self = setmetatable({}, dialogueChoiceProcessor)

	self.registry = info.registry
	self.sessionManager = info.sessionManager

	return self
end

return dialogueChoiceProcessor
