--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.CapacityConfig = {
	displayName = "Backpack",
	description = "Consume to unlock five additional storage slots.",
	imageId = 0,
	controllerClass = nil,
	persistentAttributes = {},
	stack = nil,
	storageCapacityIncrease = 5,
}

return config
