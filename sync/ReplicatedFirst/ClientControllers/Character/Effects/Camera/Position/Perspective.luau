local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")

local clientData = require(replicatedFirst.ClientData)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)
local player = players.LocalPlayer

local perspective = {}

function perspective.setFirstPerson(controller, isEnabled: boolean)
	local stateValues = controller.__vars
	stateValues.isFirstPerson = isEnabled

	if controller.character then
		controller.character:SetAttribute("FirstPerson", isEnabled)
	end

	if isEnabled then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		return
	end

	player.CameraMode = Enum.CameraMode.Classic
end

function perspective.handleToggleViewInput(controller)
	if clientData.isPerspectiveLocked() then
		return
	end

	perspective.setFirstPerson(controller, not controller.__vars.isFirstPerson)

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:playPerspectiveChange()
	end
end

return perspective
