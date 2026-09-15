local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GROUP_ID = 867384979 -- replace with your group ID
local MIN_RANK = 15 -- minimum rank allowed to playtest

local function isAllowed(player)
	local rank = player:GetRankInGroup(GROUP_ID)
	return rank >= MIN_RANK
end

Players.PlayerAdded:Connect(function(player)
	task.wait(1)

	if not isAllowed(player) and not RunService:IsStudio() then
		player:Kick("You are not whitelisted.")
	end
end)
