local replicatedStorage = game:GetService("ReplicatedStorage")

local settingsDictionary = require(replicatedStorage.SharedAssets.PlayerSettings)
local inventoryConfig = require(replicatedStorage.SharedAssets.Dictionaries.InventoryConfig)

local function deepCopy(source: { [string]: any }): { [string]: any }
	local copy = {}
	for key, value in pairs(source) do
		if typeof(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local starterHotbar = {}
for index, itemType in ipairs(inventoryConfig.starterHotbar) do
	starterHotbar[tostring(index)] = {
		itemType = itemType,
		stackCount = 1,
		attributes = {},
	}
end

return {
	Settings = deepCopy(settingsDictionary),
	Inventory = {
		schemaVersion = 2,
		hotbar = starterHotbar,
		storage = {
			["1"] = {
				itemType = "BaseballBat",
				stackCount = 1,
				attributes = {},
			},
			["2"] = {
				itemType = "Backpack",
				stackCount = 1,
				attributes = {},
			},
		},
		storageCapacity = inventoryConfig.storageCapacityDefault,
		materials = {
			Nails = 50,
			DuctTape = 10,
		},
	},
}
