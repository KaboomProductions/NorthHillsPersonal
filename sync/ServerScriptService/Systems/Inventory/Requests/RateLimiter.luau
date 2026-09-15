--!strict

local rateLimiter = {}
rateLimiter.__index = rateLimiter
local types = require(script.Parent.Parent.Contracts)

function rateLimiter.new(maximum: number, windowSeconds: number): types.RateLimiter
	return (
		setmetatable({
			maximum = maximum,
			windowSeconds = windowSeconds,
			buckets = {},
			consume = rateLimiter.consume,
			clear = rateLimiter.clear,
			destroy = rateLimiter.destroy,
		}, rateLimiter) :: unknown
	) :: types.RateLimiter
end

function rateLimiter.consume(self: types.RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if bucket == nil or now - bucket.startedAt >= self.windowSeconds then
		self.buckets[player] = { startedAt = now, count = 1 }
		return true
	end
	bucket.count += 1
	return bucket.count <= self.maximum
end

function rateLimiter.clear(self: types.RateLimiter, player: Player): ()
	self.buckets[player] = nil
end

function rateLimiter.destroy(self: types.RateLimiter): ()
	table.clear(self.buckets)
end

return rateLimiter
