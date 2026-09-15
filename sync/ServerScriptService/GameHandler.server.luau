local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")
local serverStorage = game:GetService("ServerStorage")

local sharedAssets = replicatedStorage.SharedAssets
local mappingFolder = sharedAssets.Mapping:GetChildren()

local serverAssets = serverStorage.ServerAssets
local playerMemoryController = require(serverAssets.PlayerMemory)

local bootstrapUtilities = require(replicatedStorage.SharedUtilities.Bootstrap)
local playerData = require(serverScriptService.GameHandler.PlayerData)
local playerSettings = require(serverScriptService.GameHandler.PlayerSettings)
local eventsController = require(serverScriptService.Controllers.Events)
local statusEffectsController = require(serverScriptService.Controllers.StatusEffects)
local playerControllerModule = require(serverScriptService.Controllers.Player)
local projectilesController = require(serverScriptService.Controllers.Projectiles)
local starterItemsController = require(serverScriptService.Controllers.StarterItems)
local propSpawner = require(serverScriptService.Systems.PropSpawner)
local inventorySystemModule = require(serverScriptService.Systems.Inventory)
local inventorySystem = inventorySystemModule.new()

local foligen = (require :: any)(serverScriptService:FindFirstChild("Foligen")) -- Rojo was bitching
foligen.generate()
playerSettings.init()

local playerControllersByUserId: { [number]: any } = {}

local manuallyStartedSystemNames = {
	Inventory = true,
	PropSpawner = true,
}

local function getSystemModules(): { ModuleScript }
	local systemModules: { ModuleScript } = {}

	for _, child in ipairs(serverScriptService.Systems:GetChildren()) do
		if child:IsA("ModuleScript") and not manuallyStartedSystemNames[child.Name] then
			table.insert(systemModules, child)
		end
	end

	return systemModules
end

local function generateBuildingMaps()
	for _, buildingFolder in mappingFolder do
		playerMemoryController.mapping[buildingFolder.Name] = {
			floor = {},
			rooms = {},
		}

		for _, floorFolder in buildingFolder.Floor:GetChildren() do
			playerMemoryController.mapping[buildingFolder.Name].floor[floorFolder.Name] = floorFolder:GetChildren()
		end

		for _, roomPart in buildingFolder.Rooms:GetChildren() do
			playerMemoryController.mapping[buildingFolder.Name].rooms[roomPart.Name] = roomPart
		end
	end

	--{ [buildingName] = { rooms = { BasePart }, floor = { Folder } }
end

local function onPlayerAdded(player: Player)
	local userId = player.UserId
	if playerControllersByUserId[userId] then
		return
	end

	local isLoaded = playerData.load(player)
	if not isLoaded then
		player:Kick("Failed to load your data — please rejoin")
		return
	end

	playerSettings.ensureSettings(player)
	if not inventorySystem:loadForPlayer(player) then
		playerData.release(player)
		player:Kick("Failed to load your inventory — please rejoin")
		return
	end
	playerControllersByUserId[userId] = playerControllerModule.new(player)
	starterItemsController.onPlayerAdded(player)
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	local controller = playerControllersByUserId[userId]

	if controller then
		controller:destroy()
		playerControllersByUserId[userId] = nil
	end

	starterItemsController.onPlayerRemoving(player)
	inventorySystem:unloadForPlayer(player)
	playerData.release(player)
end

generateBuildingMaps()

eventsController.init()
statusEffectsController.init()
projectilesController.init()
starterItemsController.init(inventorySystem)

--// Spawned props must exist before the interactables system scans tagged instances.
propSpawner.spawnPlaceholderProps()
bootstrapUtilities.startModules(getSystemModules())

players.PlayerAdded:Connect(onPlayerAdded)
players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(players:GetPlayers()) do
	onPlayerAdded(player)
end
