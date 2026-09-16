local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userSettings = UserSettings()
local userGameSettings = userSettings:GetService("UserGameSettings")

local clientControllers = replicatedFirst.ClientControllers
local mouseController = require(clientControllers.Player.Interface.Mouse)
local menuController = require(clientControllers.Menu)
local Replica = require(replicatedStorage.ExternalLibraries.replica)
local inventoryRemotes = require(replicatedStorage.Communication.InventoryRemotes)

userGameSettings:SetGamepadCameraSensitivityVisible(true)
inventoryRemotes.waitForClient()
Replica.RequestData()

mouseController.new()
menuController.new()

-- Edit shit
