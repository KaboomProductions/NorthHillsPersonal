local replicatedFirst = game:GetService("ReplicatedFirst")

local clientConfig = require(replicatedFirst.ClientData.ClientConfig)
local clientData = require(replicatedFirst.ClientData)

local speedPresets = clientConfig.movement.speedPresets

local injured = {}

local function sanitizeInjuredLevel(value)
	local level = tonumber(value) or 0
	if level < 0 then
		level = 0
	end

	return level
end

function injured.createState(controller)
	return {
		name = "Injured",
		priority = 10,

		canEnter = function()
			local character = controller.character
			if character == nil then
				return false
			end

			return (character:GetAttribute("Injured") or 0) > 0
		end,

		enter = function()
			--// Injured walking speed is applied via onInjuredChanged as a
			--// persistent modifier. This state just represents the visual/logical
			--// "injured" movement state when not sprinting or crouching.
		end,

		exit = function() end,
	}
end

--// Called whenever the Injured attribute changes.
--// Applies a persistent speed modifier independent of the state machine,
--// because injured speed penalties apply even while sprinting.
function injured.onInjuredChanged(controller)
	local character = controller.character
	if character == nil then
		return
	end

	local level = sanitizeInjuredLevel(character:GetAttribute("Injured"))

	local newSpeed
	if level == 0 then
		newSpeed = nil
	elseif level < 3 then
		newSpeed = speedPresets.injuredWalking - speedPresets.walking
	else
		newSpeed = (speedPresets.injuredWalking - speedPresets.walking) * 1.5
	end

	if clientData.speedModifiers.injured == newSpeed then
		return
	end

	clientData.speedModifiers.injured = newSpeed
end

return injured
