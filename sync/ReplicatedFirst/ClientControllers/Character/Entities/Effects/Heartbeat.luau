local heartbeatEffectController = {}
heartbeatEffectController.__index = heartbeatEffectController

function heartbeatEffectController.new()
	local self = setmetatable({}, heartbeatEffectController)
	self.active = false

	return self
end

function heartbeatEffectController:start(_profile: { any })
	self.active = true
end

function heartbeatEffectController:update(_deltaTime: number, _intensity: number)
	if not self.active then
		return
	end
end

function heartbeatEffectController:stop()
	self.active = false
end

return heartbeatEffectController
