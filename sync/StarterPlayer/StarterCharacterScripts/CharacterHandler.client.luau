local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local runService = game:GetService("RunService")

local characterControllers = require(replicatedFirst.ClientUtilities.CharacterControllers)
local clientRuntime = require(replicatedFirst.ClientData.ClientRuntime)

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
local connections = {}
local cleanedUp = false

local function cleanup()
	if cleanedUp then
		return
	end
	cleanedUp = true

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	characterControllers.destroyAll()
	table.clear(connections)
end

local function loadControllers()
	cleanup()
	cleanedUp = false

	if not clientRuntime.hasLoadedPlayerControllers or character == nil then
		repeat
			runService.RenderStepped:Wait()
		until clientRuntime.hasLoadedPlayerControllers
	end

	local characterControllersFolder = replicatedFirst.ClientControllers.Character
	characterControllers.loadControllers(characterControllersFolder)

	connections.died = humanoid.Died:Once(cleanup)
	connections.removing = player.CharacterRemoving:Connect(function(removedCharacter)
		if removedCharacter == character then
			cleanup()
		end
	end)
	connections.deleted = script.Destroying:Once(cleanup)
end

task.defer(loadControllers)
