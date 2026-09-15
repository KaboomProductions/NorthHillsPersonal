local replicatedStorage = game:GetService("ReplicatedStorage")

local communication = replicatedStorage.Communication
local soundEvent = communication.SoundEvent

local noiseDetection = {}
noiseDetection.__index = noiseDetection

export type SoundEventInfo = {
	position: vector | Vector3,
	radius: number,
	loudness: number,
	player: Player?,
	tag: string,
	timestamp: number,
	priority: number,
}

export type NoiseDetectionOptions = {
	rootPart: BasePart,
	cooldownSeconds: number?,
	minDirectionDelta: number?,
	minPriority: number?,
	onDetect: (eventInfo: SoundEventInfo, detector: any) -> (),
	isEnabled: (() -> boolean)?,
}

function noiseDetection.new(options: NoiseDetectionOptions)
	local self = setmetatable({}, noiseDetection)

	self.rootPart = options.rootPart
	self.cooldownSeconds = options.cooldownSeconds or 1.5
	self.minDirectionDelta = options.minDirectionDelta or 0.5
	self.minPriority = options.minPriority or 0
	self.onDetect = options.onDetect
	self.isEnabled = options.isEnabled

	self.lastSoundReactionTime = nil :: number?
	self.lastSoundPriority = nil :: number?
	self.lastKnownPosition = nil :: Vector3?
	self.lastKnownDirection = nil :: Vector3?

	self.connection = nil :: RBXScriptConnection?

	return self
end

function noiseDetection:_shouldReactTo(eventInfo: SoundEventInfo): boolean
	if self.isEnabled and not self.isEnabled() then
		return false
	end

	if eventInfo.priority < self.minPriority then
		return false
	end

	local distanceToSelf = vector.magnitude(eventInfo.position - self.rootPart.Position)
	if distanceToSelf > eventInfo.radius then
		return false
	end

	if self.lastSoundPriority and eventInfo.priority < self.lastSoundPriority then
		return false
	end

	local now = os.clock()
	if self.lastSoundReactionTime and (now - self.lastSoundReactionTime) < self.cooldownSeconds then
		return false
	end

	return true
end

function noiseDetection:connect(): RBXScriptConnection
	if self.connection then
		return self.connection
	end

	self.connection = soundEvent.Event:Connect(function(eventInfo: SoundEventInfo)
		if not self:_shouldReactTo(eventInfo) then
			return
		end

		local now = os.clock()
		local previousPosition = self.lastKnownPosition

		self.lastSoundReactionTime = now
		self.lastSoundPriority = eventInfo.priority
		self.lastKnownPosition = eventInfo.position

		if previousPosition then
			local delta = eventInfo.position - previousPosition

			if vector.magnitude(delta) > self.minDirectionDelta then
				self.lastKnownDirection = delta.Unit
			end
		end

		self.onDetect(eventInfo, self)
	end)

	return self.connection
end

function noiseDetection:disconnect()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function noiseDetection:reset()
	self.lastSoundReactionTime = nil
	self.lastSoundPriority = nil
end

return noiseDetection
