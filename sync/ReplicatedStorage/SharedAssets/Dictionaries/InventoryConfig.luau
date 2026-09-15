local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)
local limits = protocol.Limits

return table.freeze({
	starterHotbar = table.freeze({
		"TacticalShovel",
		"Tomahawk",
		"FireAxe",
		"FellingAxe",
		"Flashlight",
		"Crowbar",
		"Shovel",
		"Lantern",
	}),
	hotbarCapacity = limits.hotbarCapacity,
	storageCapacityDefault = limits.storageCapacityDefault,
	storageCapacityIncrease = limits.storageCapacityIncrease,
	storageCapacityMaximum = limits.storageCapacityMaximum,
})
