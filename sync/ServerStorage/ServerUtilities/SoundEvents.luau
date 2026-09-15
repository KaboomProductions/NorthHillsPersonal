local soundEvents = {}

local replicatedStorage = game:GetService("ReplicatedStorage")

local communication = replicatedStorage.Communication
local soundEvent = communication.SoundEvent

function soundEvents.createEvent(eventInfo: {
	position: Vector3,
	radius: number,
	loudness: number,
	player: Player?,
	tag: string,
	priority: number?,
	timestamp: number?,
})
	eventInfo.priority = eventInfo.priority or 1
	eventInfo.timestamp = os.clock()
	soundEvent:Fire(eventInfo)
end

return soundEvents
