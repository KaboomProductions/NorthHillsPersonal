--!strict

local remoteGuard = {}
local buckets: { [Player]: { [string]: { count: number, startedAt: number } } } = setmetatable({}, { __mode = "k" }) :: any

function remoteGuard.allow(player: Player, action: string, maximum: number, windowSeconds: number): boolean
	local actions = buckets[player]
	if actions == nil then
		actions = {}
		buckets[player] = actions
	end
	local now = os.clock()
	local bucket = actions[action]
	if bucket == nil or now - bucket.startedAt >= windowSeconds then
		actions[action] = { count = 1, startedAt = now }
		return true
	end
	bucket.count += 1
	return bucket.count <= maximum
end

function remoteGuard.isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value :: number) < math.huge
end

function remoteGuard.isFiniteCFrame(value: unknown): boolean
	if typeof(value) ~= "CFrame" then
		return false
	end
	for _, component in { (value :: CFrame):GetComponents() } do
		if not remoteGuard.isFiniteNumber(component) then
			return false
		end
	end
	return true
end

return remoteGuard
