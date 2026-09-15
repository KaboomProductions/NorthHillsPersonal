local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)
local limits = protocol.Limits

return table.freeze({
	hotbarCapacity = limits.hotbarCapacity,
	storageCapacityDefault = limits.storageCapacityDefault,
	storageCapacityIncrease = limits.storageCapacityIncrease,
	storageCapacityMaximum = limits.storageCapacityMaximum,
})
