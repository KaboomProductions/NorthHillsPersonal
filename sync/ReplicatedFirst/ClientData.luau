local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")

local bucketUtilities = require(replicatedStorage.SharedUtilities.BucketUtils)
local clientConfig = require(script.ClientConfig)

type booleanRequestTable = bucketUtilities.booleanRequestTable
type numberModifierTable = bucketUtilities.numberModifierTable
type vignetteMap = { [string]: ImageLabel }
local clientData = {}
clientData.InInventory = false
clientData.fieldOfViewModifiers = {} :: numberModifierTable
clientData.speedModifiers = {} :: numberModifierTable
clientData.speedMultipliers = {} :: numberModifierTable

clientData.clientConfig = clientConfig

clientData.movementLocks = {} :: booleanRequestTable
clientData.perspectiveLocks = {} :: booleanRequestTable
clientData.cameraLocks = {} :: booleanRequestTable
clientData.isInventoryOpen = false
clientData.vignetteTemplateName = "Default"
clientData.vignettes = {} :: vignetteMap

function clientData.isMovementLocked(): boolean
	return bucketUtilities.hasEnabledRequest(clientData.movementLocks)
end

function clientData.canPlayerMove(): boolean
	return not clientData.isMovementLocked()
end

function clientData.isPerspectiveLocked(): boolean
	return bucketUtilities.hasEnabledRequest(clientData.perspectiveLocks)
end

function clientData.isCameraLocked(): boolean
	return bucketUtilities.hasEnabledRequest(clientData.cameraLocks)
end

function clientData.isMobile(): boolean
	return userInputService.TouchEnabled and not userInputService.MouseEnabled and not userInputService.KeyboardEnabled
end

function clientData.getTotalSpeed(): number
	if not clientData.canPlayerMove() then
		return -1
	end

	local totalSpeed =
		bucketUtilities.getTotalModifier(clientConfig.movement.speedPresets.walking, clientData.speedModifiers)

	for _, speedMultiplier in pairs(clientData.speedMultipliers) do
		totalSpeed *= speedMultiplier
	end

	return totalSpeed
end

function clientData.getTotalFieldOfView(): number
	return bucketUtilities.getTotalModifier(clientConfig.camera.defaultFieldOfView, clientData.fieldOfViewModifiers)
end

return clientData
