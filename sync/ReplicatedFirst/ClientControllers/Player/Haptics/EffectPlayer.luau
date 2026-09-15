local workspace = game:GetService("Workspace")

local millisecondsPerSecond = 1000
local waveformTimeoutPaddingSeconds = 0.1

local effectPlayer = {}
effectPlayer.__index = effectPlayer

export type EffectProperties = {
	channel: string,
	waveform: { FloatCurveKey },
	isLooped: boolean,
}

export type ChannelEffectConfig = {
	name: string,
	position: Vector3,
	radius: number,
}

export type PlayerProperties = {
	effectsByChannel: { [string]: ChannelEffectConfig },
	isInputActive: () -> boolean,
}

function effectPlayer:createEffect(effectProperties: EffectProperties): HapticEffect
	local channelConfig = self.effectsByChannelConfig[effectProperties.channel]
	local hapticEffect = Instance.new("HapticEffect")
	hapticEffect.Name = if channelConfig then channelConfig.name else effectProperties.channel
	hapticEffect.Type = Enum.HapticEffectType.Custom
	hapticEffect.Looped = effectProperties.isLooped
	if channelConfig then
		hapticEffect.Position = channelConfig.position
		hapticEffect.Radius = channelConfig.radius
	end
	hapticEffect.Parent = workspace
	hapticEffect:SetWaveformKeys(effectProperties.waveform)

	return hapticEffect
end

function effectPlayer:destroyEffect(hapticEffect: HapticEffect)
	local effectConnectionsByEffect = self.effectConnectionsByEffect
	local endedConnection = effectConnectionsByEffect[hapticEffect]

	if endedConnection then
		endedConnection:Disconnect()
		effectConnectionsByEffect[hapticEffect] = nil
	end

	if hapticEffect.Parent == nil then
		return
	end

	hapticEffect:Stop()
	hapticEffect:Destroy()
end

function effectPlayer:stopChannel(channel: string)
	local effectsByChannel = self.effectsByChannel
	local hapticEffect = effectsByChannel[channel]
	if hapticEffect == nil then
		return
	end

	effectsByChannel[channel] = nil
	self:destroyEffect(hapticEffect)
end

function effectPlayer:stopAllChannels()
	local effectsByChannel = self.effectsByChannel

	for channel, hapticEffect in pairs(effectsByChannel) do
		effectsByChannel[channel] = nil
		self:destroyEffect(hapticEffect)
	end
end

function effectPlayer:onEffectEnded(channel: string, hapticEffect: HapticEffect)
	local effectsByChannel = self.effectsByChannel
	self.effectConnectionsByEffect[hapticEffect] = nil

	if effectsByChannel[channel] == hapticEffect then
		effectsByChannel[channel] = nil
	end

	if hapticEffect.Parent then
		hapticEffect:Destroy()
	end
end

function effectPlayer:scheduleEffectTimeout(channel: string, hapticEffect: HapticEffect, waveform: { FloatCurveKey })
	local finalKey = waveform[#waveform]
	if finalKey == nil then
		return
	end

	local timeoutSeconds = math.max(finalKey.Time, 0) / millisecondsPerSecond + waveformTimeoutPaddingSeconds
	task.delay(timeoutSeconds, function()
		if getmetatable(self) == nil or self.effectsByChannel[channel] ~= hapticEffect then
			return
		end

		self:stopChannel(channel)
	end)
end

function effectPlayer:startEffect(effectProperties: EffectProperties)
	local channel = effectProperties.channel
	local hapticEffect = self:createEffect(effectProperties)

	self.effectsByChannel[channel] = hapticEffect
	self.effectConnectionsByEffect[hapticEffect] = hapticEffect.Ended:Once(function()
		self:onEffectEnded(channel, hapticEffect)
	end)
	hapticEffect:Play()

	if not effectProperties.isLooped then
		self:scheduleEffectTimeout(channel, hapticEffect, effectProperties.waveform)
	end
end

function effectPlayer:playChannelWaveform(channel: string, waveform: { FloatCurveKey })
	self:stopChannel(channel)
	if not self.isInputActive() then
		return
	end

	self:startEffect({
		channel = channel,
		waveform = waveform,
		isLooped = false,
	})
end

function effectPlayer:setLoopedChannelWaveform(
	channel: string,
	waveform: { FloatCurveKey }?,
	waveformSignature: number?
)
	local loopSignaturesByChannel = self.loopSignaturesByChannel
	if waveform == nil or waveformSignature == nil then
		loopSignaturesByChannel[channel] = nil
		self:stopChannel(channel)
		return
	end

	if loopSignaturesByChannel[channel] == waveformSignature and self.effectsByChannel[channel] then
		return
	end

	loopSignaturesByChannel[channel] = waveformSignature
	self:stopChannel(channel)
	if not self.isInputActive() then
		return
	end

	self:startEffect({
		channel = channel,
		waveform = waveform,
		isLooped = true,
	})
end

function effectPlayer:invalidateLoopSignatures()
	table.clear(self.loopSignaturesByChannel)
end

function effectPlayer.new(playerProperties: PlayerProperties)
	local self = setmetatable({}, effectPlayer)

	self.effectsByChannelConfig = playerProperties.effectsByChannel
	self.isInputActive = playerProperties.isInputActive
	self.effectsByChannel = {}
	self.effectConnectionsByEffect = {}
	self.loopSignaturesByChannel = {}

	return self
end

function effectPlayer:destroy()
	self:stopAllChannels()
	table.clear(self.effectConnectionsByEffect)
	table.clear(self.loopSignaturesByChannel)
	table.clear(self.effectsByChannel)
	table.clear(self)
	setmetatable(self, nil)
end

return effectPlayer
