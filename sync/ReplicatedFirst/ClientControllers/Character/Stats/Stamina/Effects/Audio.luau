local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)

local player = players.LocalPlayer
local audioEffectsController = {}
audioEffectsController.__index = audioEffectsController
audioEffectsController.__vars = {
	exhaustedTargetVolume = 2.5,
	criticalSprintTargetVolume = 2,
	lowSprintTargetVolume = 1.5,
	recoveryTargetVolume = 1.5,
	criticalStaminaThreshold = 30,
	lowStaminaThreshold = 50,
	recoveryStopThreshold = 75,
	settingsTimeoutSeconds = 10,
	isActive = false,
	lastTargetVolume = nil,
}

local function findPlayerSoundSet(): StringValue?
	local settingsFolder = player:FindFirstChild("Settings")
	local audioFolder = settingsFolder and settingsFolder:FindFirstChild("Audio")
	return audioFolder and audioFolder:FindFirstChild("PlayerSoundSet") or nil
end

local function waitForPlayerSoundSet(timeoutSeconds: number): StringValue?
	local playerSoundSet = findPlayerSoundSet()
	if playerSoundSet or timeoutSeconds <= 0 then
		return playerSoundSet
	end

	local settingsFolder = player:FindFirstChild("Settings") or player:WaitForChild("Settings", timeoutSeconds)
	if settingsFolder == nil then
		return nil
	end

	local audioFolder = settingsFolder:FindFirstChild("Audio") or settingsFolder:WaitForChild("Audio", timeoutSeconds)
	if audioFolder == nil then
		return nil
	end

	return audioFolder:FindFirstChild("PlayerSoundSet") or audioFolder:WaitForChild("PlayerSoundSet", timeoutSeconds)
end

function audioEffectsController:computeTargetVolume(): number
	local stateValues = self.__vars
	local character = self.character
	if character == nil then
		stateValues.isActive = false
		return 0
	end

	local stamina = character:GetAttribute("Stamina")
	if type(stamina) ~= "number" then
		stateValues.isActive = false
		return 0
	end

	local isExhausted = character:GetAttribute("Exhausted") == true
	if isExhausted then
		stateValues.isActive = true
		return stateValues.exhaustedTargetVolume
	end

	if character:GetAttribute("Sprinting") == true then
		if stamina <= stateValues.criticalStaminaThreshold then
			stateValues.isActive = true
			return stateValues.criticalSprintTargetVolume
		end

		if stamina <= stateValues.lowStaminaThreshold then
			stateValues.isActive = true
			return stateValues.lowSprintTargetVolume
		end

		stateValues.isActive = false
		return 0
	end

	if stamina <= stateValues.lowStaminaThreshold then
		stateValues.isActive = true
	elseif stamina >= stateValues.recoveryStopThreshold then
		stateValues.isActive = false
	end

	return stateValues.isActive and stateValues.recoveryTargetVolume or 0
end

function audioEffectsController:pushUpdate(targetVolume: number)
	local stateValues = self.__vars
	if stateValues.lastTargetVolume == targetVolume then
		return
	end

	stateValues.lastTargetVolume = targetVolume
end

function audioEffectsController:applyCurrentTarget(forceRefresh: boolean?)
	local stateValues = self.__vars
	if forceRefresh then
		stateValues.lastTargetVolume = nil
	end

	self:pushUpdate(self:computeTargetVolume())
end

function audioEffectsController:bindPlayerSoundSet(playerSoundSet: StringValue?)
	connectionUtilities.disconnectConnection(self.connections.soundSetChanged)
	self.connections.soundSetChanged = nil
	self.playerSoundSet = playerSoundSet

	if playerSoundSet == nil then
		return
	end

	self:applyCurrentTarget(true)

	self.connections.soundSetChanged = playerSoundSet.Changed:Connect(function()
		self:applyCurrentTarget(true)
	end)
end

function audioEffectsController:refreshPlayerSoundSet(timeoutSeconds: number?)
	local playerSoundSet = waitForPlayerSoundSet(timeoutSeconds or 0)
	if playerSoundSet == self.playerSoundSet then
		return playerSoundSet
	end

	self:bindPlayerSoundSet(playerSoundSet)
	return playerSoundSet
end

function audioEffectsController:bindCharacter(character: Model?)
	connectionUtilities.disconnectConnection(self.connections.attributeChanged)
	self.connections.attributeChanged = nil
	self.character = character

	if character == nil then
		self:pushUpdate(0)
		return
	end

	self.connections.attributeChanged = character.AttributeChanged:Connect(function(attributeName: string)
		if attributeName == "Exhausted" or attributeName == "Sprinting" or attributeName == "Stamina" then
			self:applyCurrentTarget()
		end
	end)

	self:applyCurrentTarget(true)
end

function audioEffectsController:init()
	self:refreshPlayerSoundSet(self.__vars.settingsTimeoutSeconds)

	--// Listen only on the specific parent chain instead of the entire Player tree.
	local settingsFolder = player:FindFirstChild("Settings")
	if settingsFolder then
		local audioFolder = settingsFolder:FindFirstChild("Audio")
		if audioFolder then
			self.connections.soundSetChildAdded = audioFolder.ChildAdded:Connect(function(child: Instance)
				if child.Name == "PlayerSoundSet" then
					self:refreshPlayerSoundSet()
				end
			end)
		else
			self.connections.audioFolderAdded = settingsFolder.ChildAdded:Connect(function(child: Instance)
				if child.Name == "Audio" then
					connectionUtilities.disconnectConnection(self.connections.audioFolderAdded)
					self.connections.audioFolderAdded = nil

					self:refreshPlayerSoundSet()
					self.connections.soundSetChildAdded = child.ChildAdded:Connect(function(grandchild: Instance)
						if grandchild.Name == "PlayerSoundSet" then
							self:refreshPlayerSoundSet()
						end
					end)
				end
			end)
		end
	else
		self.connections.settingsFolderAdded = player.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Settings" then
				connectionUtilities.disconnectConnection(self.connections.settingsFolderAdded)
				self.connections.settingsFolderAdded = nil

				self:refreshPlayerSoundSet()
			end
		end)
	end
end

function audioEffectsController.new(parentController)
	local self = setmetatable({}, audioEffectsController)

	self.parentController = parentController
	self.connections = {}
	self.__vars = table.clone(audioEffectsController.__vars)
	self.character = nil
	self.playerSoundSet = nil

	task.defer(self.init, self)

	return self
end

function audioEffectsController:destroy()
	connectionUtilities.disconnectConnections(self.connections)
	table.clear(self.connections)
	setmetatable(self, nil)
end

return audioEffectsController
