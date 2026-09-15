local gunController = {}
gunController.__index = gunController
gunController.__vars = {
	clientReadyTimeoutSeconds = 2,
}

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local autoRigUtility = require(serverStorage.ServerUtilities.AutoRig)
local itemUtilities = require(sharedUtilities.ItemUtils)

local attributeConstants = require(sharedAssets.Attributes)
local toolAttributes = attributeConstants.tool

function gunController:preload()
	self.mainRemote = Instance.new("RemoteEvent")
	self.mainRemote.Name = "MainRemote"
	self.mainRemote.Parent = self.tool

	self.mainFunction = Instance.new("RemoteFunction")
	self.mainFunction.Name = "MainFunction"
	self.mainFunction.Parent = self.tool
end

function gunController:cleanupRigArtifacts()
	for _, descendant in ipairs(self.character:GetDescendants()) do
		if descendant == self.tool then
			continue
		end

		if itemUtilities.isRigArtifact(descendant, self.tool.Name) then
			descendant:Destroy()
		end
	end
end

function gunController:onMainEvent(event: string)
	if event == "activate" then
		self:activate()
	end
end

function gunController:init()
	self:preload()
	self.isEquipping = false

	self.connections.onMainEvent = self.mainRemote.OnServerEvent:Connect(function(eventPlayer: Player, event: string)
		if eventPlayer ~= self.player then
			return
		end

		if event == "ready" then
			self.isClientReady = true
			return
		end

		self:onMainEvent(event)
	end)
end

function gunController:waitForClientReady(): boolean
	local startTime = os.clock()

	while not self.isClientReady and os.clock() - startTime < self.__vars.clientReadyTimeoutSeconds do
		task.wait()
	end

	return self.isClientReady
end

function gunController:sendClientInfo(event: string, info: {})
	if not self:waitForClientReady() then
		return false
	end

	local wasSent = pcall(function()
		self.mainFunction:InvokeClient(self.player, event, info)
	end)

	return wasSent
end

function gunController:getClientAnimationResponse(event: string, info: {}): any
	if not self:waitForClientReady() then
		return nil
	end

	local wasSuccessful, response = pcall(function()
		return self.mainFunction:InvokeClient(self.player, event, info)
	end)

	if not wasSuccessful then
		return nil
	end

	return response
end

function gunController:getUnequipDuration(): number
	local duration = self:getClientAnimationResponse("getUnequipDuration", {})
	if type(duration) ~= "number" then
		duration = 0
	end

	return duration
end

function gunController.new(player, character, tool, config)
	local self = setmetatable({}, gunController)

	self.tool = tool
	self.player = player
	self.character = character

	self.config = config
	self.__vars = table.clone(gunController.__vars)
	self.connections = {}

	self:init()

	return self
end

function gunController:activate()
	if self.isEquipping then
		return
	end

	if not self.tool:GetAttribute(toolAttributes.equipped) then
		return
	end
end

function gunController:equip()
	if self.isEquipping then
		return
	end

	self.isEquipping = true

	if self.tool.Parent ~= self.character then
		self.isEquipping = false
		return
	end

	self.tool:SetAttribute(toolAttributes.equipped, true)
	self:cleanupRigArtifacts()

	if self.config and self.config.rigging then
		autoRigUtility.rig({
			tool = self.tool,
			config = self.config.rigging,
			character = self.character,
		})
	end

	self.isEquipping = false
end

function gunController:unequip(info: { skipAnimation: boolean? }?)
	self.tool:SetAttribute(toolAttributes.equipped, false)

	if not (info and info.skipAnimation) then
		self:sendClientInfo("unequip", info or {})
	end
end

function gunController:destroy()
	self.tool:SetAttribute(toolAttributes.equipped, false)

	if self.character ~= nil then
		self:cleanupRigArtifacts()
	end

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	setmetatable(self, nil)
end

return gunController
