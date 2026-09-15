local mouseController = require(script.Parent.Mouse)

local mouseUnlock = {}

export type MouseRequestToken = mouseController.MouseRequestToken

function mouseUnlock.acquire(reason: string): MouseRequestToken
	return mouseController.acquireUnlock(reason)
end

function mouseUnlock.release(token: MouseRequestToken?)
	mouseController.releaseUnlock(token)
end

function mouseUnlock.isActive(): boolean
	return mouseController.hasUnlockRequests()
end

return mouseUnlock
