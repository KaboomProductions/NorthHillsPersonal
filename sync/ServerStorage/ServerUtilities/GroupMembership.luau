--!strict

local players = game:GetService("Players")

local groupMembership = {}

groupMembership.groupId = 867384979

local cachedRanksByPlayer: { [Player]: number } = {}

local function fetchGroupRank(player: Player): number?
	local didLookupSucceed, groupRank = pcall(player.GetRankInGroupAsync, player, groupMembership.groupId)
	if not didLookupSucceed or typeof(groupRank) ~= "number" then
		warn(string.format("[GroupMembership] Rank lookup failed for %s: %s", player.Name, tostring(groupRank)))
		return nil
	end

	return groupRank
end

function groupMembership.getRank(player: Player): number?
	local cachedRank = cachedRanksByPlayer[player]
	if cachedRank ~= nil then
		return cachedRank
	end
	local groupRank = fetchGroupRank(player)
	if groupRank ~= nil and player.Parent == players then
		cachedRanksByPlayer[player] = groupRank
	end
	return groupRank
end

function groupMembership.isMember(player: Player): boolean
	local groupRank = groupMembership.getRank(player)
	return groupRank ~= nil and groupRank > 0
end

function groupMembership.clear(player: Player)
	cachedRanksByPlayer[player] = nil
end

players.PlayerRemoving:Connect(groupMembership.clear)

return groupMembership
