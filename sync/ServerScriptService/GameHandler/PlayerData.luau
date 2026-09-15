local players = game:GetService("Players")
local runService = game:GetService("RunService")
local serverStorage = game:GetService("ServerStorage")

local ProfileStore = require(serverStorage.ServerUtilities.ProfileStore)
local dataTemplate = require(script.Parent.DataTemplate)

local isStudio = runService:IsStudio()

local playerStore = ProfileStore.New("PlayerData0", dataTemplate)
if isStudio then
	playerStore = playerStore.Mock
end

local profilesByPlayer: { [Player]: any } = {}

local playerData = {}

function playerData.load(player: Player): boolean
	local profile = playerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= players
		end,
	})

	if profile == nil then
		return false
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profilesByPlayer[player] = nil
		if player.Parent == players then
			player:Kick("Your data has been loaded on another server — please rejoin")
		end
	end)

	if player.Parent ~= players then
		profile:EndSession()
		return false
	end

	profilesByPlayer[player] = profile
	return true
end

function playerData.get(player: Player): { [string]: any }?
	local profile = profilesByPlayer[player]
	if profile == nil then
		return nil
	end
	return profile.Data
end

function playerData.getProfile(player: Player): any?
	return profilesByPlayer[player]
end

function playerData.release(player: Player)
	local profile = profilesByPlayer[player]
	if profile then
		profile:EndSession()
	end
end

ProfileStore.OnError:Connect(function(errorMessage, storeName, profileKey)
	warn(`[PlayerData] DataStore error (Store:{storeName};Key:{profileKey}): {errorMessage}`)
end)

return playerData
