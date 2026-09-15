local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local communication = replicatedStorage.Communication
local transferSettingRemote = communication.RemoteFunctions.TransferSetting

local settingsDictionary = require(replicatedStorage.SharedAssets.PlayerSettings)
local playerData = require(serverScriptService.GameHandler.PlayerData)

local settingValues = require(replicatedStorage.SharedUtilities.SettingValues)
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)

local playerSettings = {}

local function resolveClassName(settingData): string?
	if settingData.settingType == "Slider" then
		return "Number"
	end

	if string.match(settingData.settingType, "Toggle") then
		return if type(settingData.default) == "string" then "String" else "Bool"
	end

	return nil
end

function playerSettings.generate(player: Player): Configuration
	local data = playerData.get(player)
	local savedSettings = if data and typeof(data.Settings) == "table" then data.Settings else {}
	if data then
		data.Settings = savedSettings
	end

	local settingsConfiguration = Instance.new("Configuration")
	settingsConfiguration.Name = "Settings"

	for categoryName, categoryEntries in pairs(settingsDictionary) do
		local savedCategory = if typeof(savedSettings[categoryName]) == "table" then savedSettings[categoryName] else {}
		savedSettings[categoryName] = savedCategory

		local categoryFolder = Instance.new("Folder")
		categoryFolder.Name = categoryName
		categoryFolder.Parent = settingsConfiguration

		for settingName, settingData in pairs(categoryEntries) do
			local rawSaved = savedCategory and savedCategory[settingName]
			local savedValue = settingValues.normalize(settingData, rawSaved)
			savedCategory[settingName] = savedValue
			local className = resolveClassName(settingData)

			if not className then
				continue
			end

			local valueInstance = Instance.new(className .. "Value")
			valueInstance.Name = settingName
			valueInstance.Value = savedValue

			--// Write back changes to the profile whenever the player updates a setting
			valueInstance.Changed:Connect(function(newValue)
				local currentData = playerData.get(player)
				if currentData == nil then
					return
				end

				local currentSettings = currentData.Settings
				if currentSettings and currentSettings[categoryName] then
					currentSettings[categoryName][settingName] = newValue
				end
			end)

			valueInstance.Parent = categoryFolder
		end
	end

	settingsConfiguration.Parent = player
	return settingsConfiguration
end

function playerSettings.ensureSettings(player: Player)
	if not player:FindFirstChild("Settings") then
		playerSettings.generate(player)
	end
end

function playerSettings.onTransferInvoke(
	player: Player,
	settingData: { settingName: string, settingType: string, categoryId: string },
	newValue: any
)
	if not remoteGuard.allow(player, "setting", 20, 1) then
		return nil
	end
	if
		type(settingData) ~= "table"
		or type(settingData.categoryId) ~= "string"
		or type(settingData.settingName) ~= "string"
	then
		return nil
	end

	if #settingData.categoryId > 128 or #settingData.settingName > 128 then
		return nil
	end
	local category = settingsDictionary[settingData.categoryId]
	local definition = category and category[settingData.settingName]
	if definition == nil or not settingValues.isValid(definition, newValue) or playerData.get(player) == nil then
		return nil
	end

	local settingsConfig = player:FindFirstChild("Settings")
	if not settingsConfig then
		return nil
	end

	local categoryFolder = settingsConfig:FindFirstChild(settingData.categoryId)
	if not categoryFolder then
		return nil
	end

	local valueInstance = categoryFolder:FindFirstChild(settingData.settingName)
	if not valueInstance then
		return nil
	end

	local isValid = (valueInstance:IsA("BoolValue") and type(newValue) == "boolean")
		or (valueInstance:IsA("NumberValue") and type(newValue) == "number")
		or (valueInstance:IsA("StringValue") and type(newValue) == "string")

	if not isValid then
		return nil
	end

	valueInstance.Value = newValue

	return valueInstance.Value
end

function playerSettings.init()
	transferSettingRemote.OnServerInvoke = playerSettings.onTransferInvoke
end

return playerSettings
