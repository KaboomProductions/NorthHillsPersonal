local replicatedStorage = game:GetService("ReplicatedStorage")
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)

local screamAction = {}

function screamAction.canRun(ai, _extraInfo)
	return ai.stateMachine.currentState.id == "Chasing"
end

function screamAction.run(ai, extraInfo)
	local sounds = ai.sounds
	local screamSounds = sounds.Scream

	local janitor = ai:getActionJanitor("Scream")
	local screamTrack = ai.cachedTracks.scream

	if not ai.screamCache then
		ai.screamCache = screamSounds:GetChildren()
	end

	for _, cachedSound in ai.screamCache do
		janitor.add(screamTrack:GetMarkerReachedSignal(cachedSound.Name):Once(function()
			audioUtilities.playSound({
				sound = cachedSound,
				parent = ai.rootPart,
				useAcousticSimulation = false,
			})
		end))
	end

	screamTrack:Play()

	if not extraInfo.runAndScream then
		ai.speed:setLock("Screaming", true)
		ai.humanoid.WalkSpeed = ai.walkSpeedConfig.scream

		janitor.add(screamTrack.Ended:Once(function()
			ai.speed:setLock("Screaming", false)
		end))
	end
end

return screamAction
