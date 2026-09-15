local replicatedFirst = game:GetService("ReplicatedFirst")

local clientConfig = require(replicatedFirst.ClientData.ClientConfig)
local clientData = require(replicatedFirst.ClientData)

local speedPresets = clientConfig.movement.speedPresets

local sprinting = {}

function sprinting.createState(controller)
	return {
		name = "Sprinting",
		priority = 20,

		canEnter = function()
			local character = controller.character
			if character == nil then
				return false
			end

			if character:GetAttribute("HoldingSprint") ~= true then
				return false
			end

			if (character:GetAttribute("Injured") or 0) >= 2 then
				return false
			end

			if character:GetAttribute("Exhausted") == true then
				return false
			end

			local stamina = character:GetAttribute("Stamina")
			local minimumStamina = character:GetAttribute("StaminaMin")

			if type(stamina) == "number" and type(minimumStamina) == "number" and stamina <= minimumStamina then
				return false
			end

			if stamina <= minimumStamina then
				return false
			end

			local movementDirection = controller:getMovementDirection()
			return movementDirection ~= nil
		end,

		enter = function()
			sprinting.applyModifiers(controller)
		end,

		exit = function()
			clientData.speedModifiers.sprinting = 0
			clientData.fieldOfViewModifiers.sprinting = 0
		end,

		update = function()
			sprinting.applyModifiers(controller)
		end,
	}
end

function sprinting.applyModifiers(controller)
	local stateValues = controller.__vars
	local character = controller.character
	if character == nil then
		return
	end

	local targetSprintSpeed = speedPresets.sprinting - speedPresets.walking
	if (character:GetAttribute("Injured") or 0) > 0 then
		targetSprintSpeed = speedPresets.injuredSprinting - speedPresets.injuredWalking
	end

	local movementDirection = controller:getMovementDirection()

	if type(movementDirection) == "string" and string.find(movementDirection, "backward") then
		clientData.speedModifiers.sprinting = targetSprintSpeed * stateValues.backwardSprintMultiplier
	elseif movementDirection == "left" or movementDirection == "right" then
		clientData.speedModifiers.sprinting = targetSprintSpeed * stateValues.strafeSprintMultiplier
	else
		clientData.speedModifiers.sprinting = targetSprintSpeed
	end

	clientData.fieldOfViewModifiers.sprinting = stateValues.sprintFieldOfViewOffset
end

return sprinting
