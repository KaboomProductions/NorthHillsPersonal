local replicatedFirst = game:GetService("ReplicatedFirst")

local clientData = require(replicatedFirst.ClientData)

local effects = require(script.Effects)

local crouching = {}

function crouching.createState(controller)
	return {
		name = "Crouching",
		priority = 15,

		canEnter = function()
			local character = controller.character
			if character == nil then
				return false
			end

			if not controller.wantsCrouch then
				return false
			end

			return (character:GetAttribute("Injured") or 0) == 0
		end,

		enter = function()
			crouching.applyCrouchEffects(controller, true)
		end,

		exit = function()
			controller.wantsCrouch = false
			crouching.applyCrouchEffects(controller, false)
		end,
	}
end

function crouching.applyCrouchEffects(controller, isCrouching: boolean)
	local stateValues = controller.__vars

	if isCrouching then
		clientData.speedModifiers.crouching = stateValues.crouchSpeed
		clientData.fieldOfViewModifiers.crouching = stateValues.crouchFieldOfViewOffset
		controller.targetVignetteTransparency = stateValues.vignetteVisibleTransparency
		return
	end

	clientData.speedModifiers.crouching = 0
	clientData.fieldOfViewModifiers.crouching = 0
	controller.targetVignetteTransparency = stateValues.vignetteHiddenTransparency
end

function crouching.preload(controller)
	effects.preload(controller)
end

function crouching.updateEffects(controller, deltaTime: number)
	effects.update(controller, deltaTime)
end

function crouching.destroyEffects(controller)
	effects.destroy(controller)
end

return crouching
