local flashlightController = {}
flashlightController.__index = flashlightController

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local effects = sharedAssets.Effects
local sounds = effects.Sounds
local toolSounds = sounds.Tools

local flashlightSounds = toolSounds.Flashlight
local equipSounds = flashlightSounds.Equip:GetChildren()
local toggleSounds = flashlightSounds.Toggle:GetChildren()

local audioUtilities = require(sharedUtilities.AudioUtils)
local autoRigUtility = require(serverStorage.ServerUtilities.AutoRig)
local itemUtilities = require(sharedUtilities.ItemUtils)

local attributeConstants = require(sharedAssets.Attributes)
local toolAttributes = attributeConstants.tool

function flashlightController:cacheEffects()
	self.effects = {}

	for _, descendant in ipairs(self.tool:GetDescendants()) do
		if descendant:IsA("Light") or descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") then
			table.insert(self.effects, descendant)
		end
	end
end

function flashlightController:preload()
	self.mainRemote = Instance.new("RemoteEvent")
	self.mainRemote.Name = "MainRemote"
	self.mainRemote.Parent = self.tool

	self.handle = self.tool:FindFirstChild("Handle")
	self.tool:GetAttribute(toolAttributes.toggled, false)

	self:cacheEffects()
	self:registerToggle()
end

function flashlightController:playSound(newSound, pitch)
	if not newSound then
		return
	end

	self.activeSound = audioUtilities.playSound({
		sound = newSound,
		volume = newSound.Volume,
		parent = self.handle,
		playbackSpeed = pitch,
	})
end

function flashlightController:stopActiveSound()
	audioUtilities.stopSound(self.activeSound)
	self.activeSound = nil
end

function flashlightController:cleanupRigArtifacts()
	for _, descendant in ipairs(self.character:GetDescendants()) do
		if descendant == self.tool then
			continue
		end

		if itemUtilities.isRigArtifact(descendant, self.tool.Name) then
			descendant:Destroy()
		end
	end
end

function flashlightController:onMainEvent(event: string)
	if event == "activate" then
		self:activate({ playSound = true })
	elseif event == "activateSilent" then
		self:activate({ playSound = false })
	end
end

function flashlightController:init()
	self:preload()
	self.isEquipping = false

	self.connections.onMainEvent = self.mainRemote.OnServerEvent:Connect(function(eventPlayer: Player, event: string)
		if eventPlayer ~= self.player or typeof(event) ~= "string"
			or (event ~= "activate" and event ~= "activateSilent")
			or not remoteGuard.allow(eventPlayer, "lightToggle", 8, 1) then
			return
		end

		self:onMainEvent(event)
	end)
end

function flashlightController:registerToggle()
	for _, object in self.effects do
		object.Enabled = self.tool:GetAttribute(toolAttributes.toggled)
	end
end

function flashlightController.new(player, character, tool, config)
	local self = setmetatable({}, flashlightController)

	self.tool = tool
	self.player = player
	self.character = character

	self.config = config
	self.connections = {}
	self.effects = {}

	self:init()

	return self
end

function flashlightController:activate(params: { playSound: boolean? })
	if self.isEquipping then
		return
	end

	if not self.tool:GetAttribute(toolAttributes.equipped) then
		return
	end

	if params.playSound == true or params.playSound == nil then
		self:playSound(toggleSounds[math.random(1, #toggleSounds)])
	end

	self.tool:SetAttribute(toolAttributes.toggled, not self.tool:GetAttribute(toolAttributes.toggled))

	self:registerToggle()

	self.mainRemote:FireClient(self.player, "activate", {
		isServerReplication = true,
	})
end

function flashlightController:equip()
	if self.isEquipping then
		return
	end

	self.isEquipping = true

	if self.tool.Parent ~= self.character then
		self.isEquipping = false
		return
	end

	self.tool:SetAttribute(toolAttributes.equipped, true)
	self.tool:SetAttribute(toolAttributes.toggled, false)
	self:registerToggle()

	self:cleanupRigArtifacts()

	self:playSound(equipSounds[math.random(1, #equipSounds)])
	self:playSound(toggleSounds[math.random(1, #toggleSounds)])

	if self.config and self.config.rigging then
		autoRigUtility.rig({
			tool = self.tool,
			config = self.config.rigging,
			character = self.character,
		})
	end

	self.isEquipping = false
end

function flashlightController:unequip()
	self.tool:SetAttribute(toolAttributes.equipped, false)
	self.tool:SetAttribute(toolAttributes.toggled, false)

	self:registerToggle()

	self:playSound(equipSounds[math.random(1, #equipSounds)])
	self:playSound(toggleSounds[math.random(1, #toggleSounds)])
end

function flashlightController:destroy()
	self:stopActiveSound()
	self.tool:SetAttribute(toolAttributes.equipped, false)
	self.tool:SetAttribute(toolAttributes.toggled, false)
	self:registerToggle()

	if self.character ~= nil then
		self:cleanupRigArtifacts()
	end

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	setmetatable(self, nil)
end

return flashlightController
