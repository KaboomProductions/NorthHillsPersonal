local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local groupMembership = require(ServerStorage.ServerUtilities.GroupMembership)

local minimumPlaytestRank = 15

Players.PlayerAdded:Connect(function(player)
	if RunService:IsStudio() then
		return
	end

	local groupRank = groupMembership.getRank(player)
	if player.Parent ~= Players then
		return
	end

	--// An unverifiable rank must not admit the player.
	if groupRank == nil then
		player:Kick("Could not verify your group rank — please rejoin.")
	elseif groupRank < minimumPlaytestRank then
		player:Kick("You are not whitelisted.")
	end
end)
