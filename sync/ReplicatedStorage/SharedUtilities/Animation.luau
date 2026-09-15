local contentProvider = game:GetService("ContentProvider")

local animationUtilities = {}

local DefaultTrackDurationRetryCount = 10

local adjustmentEpsilon = 0.005
local replicationInterval = 1 / 12
local speedSnapDelta = 0.25
local speedQuantumStep = 0.05

local lastWeightFlushTimes: { [AnimationTrack]: number } = setmetatable({} :: any, { __mode = "k" })
local lastSpeedFlushTimes: { [AnimationTrack]: number } = setmetatable({} :: any, { __mode = "k" })

function animationUtilities.setTrackWeight(animationTrack: AnimationTrack, weight: number, fadeTime: number?)
	if math.abs(animationTrack.WeightTarget - weight) < adjustmentEpsilon then
		return
	end

	local currentTime = os.clock()
	local lastFlushTime = lastWeightFlushTimes[animationTrack]
	if lastFlushTime ~= nil and currentTime - lastFlushTime < replicationInterval then
		return
	end

	lastWeightFlushTimes[animationTrack] = currentTime
	animationTrack:AdjustWeight(weight, fadeTime or replicationInterval)
end

function animationUtilities.setTrackSpeed(animationTrack: AnimationTrack, speed: number)
	speed = math.floor(speed / speedQuantumStep + 0.5) * speedQuantumStep

	local speedDelta = math.abs(animationTrack.Speed - speed)
	if speedDelta < adjustmentEpsilon then
		return
	end

	if speedDelta < speedSnapDelta then
		local currentTime = os.clock()
		local lastFlushTime = lastSpeedFlushTimes[animationTrack]
		if lastFlushTime ~= nil and currentTime - lastFlushTime < replicationInterval then
			return
		end

		lastSpeedFlushTimes[animationTrack] = currentTime
	else
		lastSpeedFlushTimes[animationTrack] = os.clock()
	end

	animationTrack:AdjustSpeed(speed)
end

function animationUtilities.loadAnimation(
	animator: Animator,
	animation: Animation,
	shouldPreload: boolean?
): AnimationTrack
	if shouldPreload then
		contentProvider:PreloadAsync({ animation })
	end

	return animator:LoadAnimation(animation)
end

function animationUtilities.loadAnimationById(
	animator: Animator,
	assetId: number,
	shouldPreload: boolean?
): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. assetId

	local loadedTrack = animationUtilities.loadAnimation(animator, animation, shouldPreload)
	animation:Destroy()

	return loadedTrack
end

function animationUtilities.sortRecursively(animator: Animator, node: { [string]: any })
	local result = {}

	for key, value in node do
		if type(value) == "table" then
			result[key] = animationUtilities.sortRecursively(animator, value)
			continue
		end

		result[key] = animationUtilities.loadAnimationById(animator, value)
	end

	return result
end

function animationUtilities.getTrackDuration(track: AnimationTrack, maxRetryCount: number?): number
	local trackDuration = track.Length
	local retryCount = 0
	local allowedRetryCount = maxRetryCount or DefaultTrackDurationRetryCount

	while trackDuration <= 0 and retryCount < allowedRetryCount do
		retryCount = retryCount + 1
		task.wait()
		trackDuration = track.Length
	end

	return trackDuration
end

function animationUtilities.cancelTracksOfDictionary(trackDictionary: { AnimationTrack }, fadeTime: number?)
	for _, track in pairs(trackDictionary) do
		track:Stop(fadeTime or 0)
	end
end

return animationUtilities
