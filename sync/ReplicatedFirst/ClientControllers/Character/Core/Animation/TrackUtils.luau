local replicatedStorage = game:GetService("ReplicatedStorage")

local animationUtilities = require(replicatedStorage.SharedUtilities.Animation)

local trackUtils = {}

local sideOnlyMovementThreshold = 2

trackUtils.setTrackWeight = animationUtilities.setTrackWeight
trackUtils.setTrackSpeed = animationUtilities.setTrackSpeed

export type movementState = {
	forwardVelocity: number,
	lateralVelocity: number,
	speedMagnitude: number,
}

type movementLayer = {
	name: string,
	tracks: { [string]: AnimationTrack }?,
	weight: number,
}

local function getPlaybackSyncPhase(activeDirectionalTracks: { [string]: AnimationTrack })
	for _, animationTrack in pairs(activeDirectionalTracks) do
		if animationTrack.IsPlaying then
			local trackLength = animationTrack.Length
			if trackLength > 0 then
				return (animationTrack.TimePosition % trackLength) / trackLength
			end

			return 0
		end
	end

	return nil
end

function trackUtils.getDirectionalPlaybackSyncPhase(activeDirectionalTracks: { [string]: AnimationTrack })
	return getPlaybackSyncPhase(activeDirectionalTracks)
end

function trackUtils.forEachTrack(trackTree: AnimationTrack | { [any]: any }?, callback: (AnimationTrack) -> ())
	if trackTree == nil then
		return
	end

	if typeof(trackTree) == "Instance" then
		if trackTree:IsA("AnimationTrack") then
			callback(trackTree)
		end

		return
	end

	if type(trackTree) ~= "table" then
		return
	end

	for _, childTrackNode in pairs(trackTree) do
		trackUtils.forEachTrack(childTrackNode, callback)
	end
end

function trackUtils.stopTrack(track: AnimationTrack?, fadeTime: number?)
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0)
	end
end

function trackUtils.stopTree(trackTree: AnimationTrack | { [any]: any }?, fadeTime: number?)
	trackUtils.forEachTrack(trackTree, function(animationTrack)
		trackUtils.stopTrack(animationTrack, fadeTime)
	end)
end

function trackUtils.adjustTreeSpeed(trackTree: AnimationTrack | { [any]: any }?, speed: number)
	trackUtils.forEachTrack(trackTree, function(animationTrack)
		trackUtils.setTrackSpeed(animationTrack, speed)
	end)
end

function trackUtils.stopDirectionalTracks(activeDirectionalTracks: { [string]: AnimationTrack }, fadeTime: number?)
	for directionName, animationTrack in pairs(activeDirectionalTracks) do
		trackUtils.stopTrack(animationTrack, fadeTime)
		activeDirectionalTracks[directionName] = nil
	end
end

function trackUtils.computeDirectionWeights(movementState: movementState)
	local forwardVelocity = movementState.forwardVelocity or 0
	local lateralVelocity = movementState.lateralVelocity or 0

	local absoluteForwardVelocity = math.abs(forwardVelocity)
	local absoluteLateralVelocity = math.abs(lateralVelocity)

	if absoluteLateralVelocity > absoluteForwardVelocity and absoluteForwardVelocity < sideOnlyMovementThreshold then
		return {
			left = math.clamp(-lateralVelocity, 0, 1),
			right = math.clamp(lateralVelocity, 0, 1),
		}
	end

	return {
		forward = math.clamp(-forwardVelocity, 0, 1),
		backward = math.clamp(forwardVelocity, 0, 1),
	}
end

local function buildMovementTrackKey(layerName: string, directionName: string): string
	return `{layerName}:{directionName}`
end

function trackUtils.playMovementLayers(
	movementLayers: { movementLayer }?,
	directionalWeights,
	activeDirectionalTracks: { [string]: AnimationTrack },
	fadeTime: number,
	preferredPlaybackSyncPhase: number?
)
	if movementLayers == nil or #movementLayers == 0 then
		trackUtils.stopDirectionalTracks(activeDirectionalTracks, fadeTime)
		return {}
	end

	local syncPhase = preferredPlaybackSyncPhase
	if syncPhase == nil then
		syncPhase = getPlaybackSyncPhase(activeDirectionalTracks)
	end

	local nextDirectionalTracks = {}
	local totalDirectionalWeight = 0

	for _, directionWeight in pairs(directionalWeights) do
		if directionWeight > 0 then
			totalDirectionalWeight += directionWeight
		end
	end

	if totalDirectionalWeight > 0 then
		for _, movementLayer in ipairs(movementLayers) do
			local layerName = movementLayer.name
			local movementTracks = movementLayer.tracks
			local layerWeight = movementLayer.weight

			if movementTracks == nil or layerWeight <= 0 then
				continue
			end

			for directionName, directionWeight in pairs(directionalWeights) do
				local animationTrack = movementTracks[directionName]
				if animationTrack == nil or directionWeight <= 0 then
					continue
				end

				local normalizedDirectionWeight = directionWeight / totalDirectionalWeight
				local finalTrackWeight = normalizedDirectionWeight * layerWeight
				local movementTrackKey = buildMovementTrackKey(layerName, directionName)

				if not animationTrack.IsPlaying then
					animationTrack.Priority = Enum.AnimationPriority.Core
					animationTrack:Play(fadeTime, finalTrackWeight, 1)

					if syncPhase ~= nil then
						local trackLength = animationTrack.Length
						if trackLength > 0 then
							animationTrack.TimePosition = syncPhase * trackLength
						end
					end
				else
					trackUtils.setTrackWeight(animationTrack, finalTrackWeight)
				end

				nextDirectionalTracks[movementTrackKey] = animationTrack
			end
		end
	end

	for movementTrackKey, animationTrack in pairs(activeDirectionalTracks) do
		if nextDirectionalTracks[movementTrackKey] ~= animationTrack then
			trackUtils.stopTrack(animationTrack, fadeTime)
		end
	end

	return nextDirectionalTracks
end

function trackUtils.playMovementSet(
	movementTracks: { [string]: AnimationTrack }?,
	directionalWeights,
	activeDirectionalTracks: { [string]: AnimationTrack },
	fadeTime: number,
	preferredPlaybackSyncPhase: number?
)
	if not movementTracks then
		trackUtils.stopDirectionalTracks(activeDirectionalTracks, fadeTime)
		return {}
	end

	return trackUtils.playMovementLayers({
		{
			name = "default",
			tracks = movementTracks,
			weight = 1,
		},
	}, directionalWeights, activeDirectionalTracks, fadeTime, preferredPlaybackSyncPhase)
end

function trackUtils.bindMarkerSignals(
	trackTree: AnimationTrack | { [any]: any }?,
	markerName: string,
	callback: () -> (),
	connectionList: { RBXScriptConnection }
)
	trackUtils.forEachTrack(trackTree, function(animationTrack)
		table.insert(connectionList, animationTrack:GetMarkerReachedSignal(markerName):Connect(callback))
	end)
end

function trackUtils.awaitUnlock(animationTrack: AnimationTrack, fallbackDuration: number?)
	local isFinished = false
	local completionEvent = Instance.new("BindableEvent")

	local function finishTransition()
		if isFinished then
			return
		end

		isFinished = true
		completionEvent:Fire()
	end

	local unlockMarkerConnection = animationTrack:GetMarkerReachedSignal("unlock"):Connect(finishTransition)
	local stoppedConnection = animationTrack.Stopped:Connect(finishTransition)
	local timeoutDuration = math.max(animationTrack.Length, fallbackDuration or 0.2, 0.05)

	task.delay(timeoutDuration, finishTransition)
	completionEvent.Event:Wait()

	unlockMarkerConnection:Disconnect()
	stoppedConnection:Disconnect()
	completionEvent:Destroy()
end

return trackUtils
