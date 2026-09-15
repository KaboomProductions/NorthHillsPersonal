local replicatedStorage = game:GetService("ReplicatedStorage")

local animationUtilities = require(replicatedStorage.SharedUtilities.Animation)

local trackLoader = {}

local function loadTrackTree(animator: Animator, animationSource)
	if animationSource == nil then
		return nil
	end

	if typeof(animationSource) == "Instance" then
		if animationSource:IsA("Animation") then
			return animationUtilities.loadAnimation(animator, animationSource)
		end

		return nil
	end

	if type(animationSource) ~= "table" then
		return nil
	end

	local loadedTrackTree = {}

	for key, childAnimationSource in pairs(animationSource) do
		local loadedChildTrack = loadTrackTree(animator, childAnimationSource)
		if loadedChildTrack ~= nil then
			loadedTrackTree[key] = loadedChildTrack
		end
	end

	return next(loadedTrackTree) and loadedTrackTree or nil
end

function trackLoader.load(animator: Animator, animationConfig)
	local loadedTracks = {
		defaultIdle = loadTrackTree(animator, animationConfig.defaultIdle),
		states = {},
	}

	for stateName, stateDefinition in pairs(animationConfig.states) do
		loadedTracks.states[stateName] = {
			idle = loadTrackTree(animator, stateDefinition.idle),
			transitions = loadTrackTree(animator, stateDefinition.transitions),
			variants = loadTrackTree(animator, stateDefinition.variants),
		}
	end

	return loadedTracks
end

return trackLoader
