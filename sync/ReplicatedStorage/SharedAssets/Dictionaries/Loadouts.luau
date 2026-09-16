--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

export type LoadoutItem = {
	itemType: string,
	stackCount: number?,
	attributes: { [string]: boolean | number | string }?,
	preferredZone: protocol.Zone?,
	preferredIndex: number?,
}

export type Loadout = {
	id: string,
	displayName: string,
	items: { LoadoutItem },
	materials: { [string]: number },
}

export type Kit = Loadout & {
	gamePassId: number,
}

local hotbar: protocol.Zone = protocol.Zones.hotbar
local storage: protocol.Zone = protocol.Zones.storage

local starterLoadout: Loadout = {
	id = "Starter",
	displayName = "Starter Loadout",

	items = {
		{ itemType = "Flashlight", preferredZone = hotbar, preferredIndex = 1 },
		{ itemType = "Lantern", preferredZone = hotbar, preferredIndex = 2 },
		{ itemType = "FireAxe", preferredZone = hotbar, preferredIndex = 3 },
		{ itemType = "Crowbar", preferredZone = hotbar, preferredIndex = 4 },
		{ itemType = "Tomahawk", preferredZone = hotbar, preferredIndex = 5 },
		{ itemType = "BaseballBat", preferredZone = storage, preferredIndex = 6 },

		{ itemType = "Backpack", preferredZone = storage, preferredIndex = 1 },
	},

	materials = {
		Nails = 50,
		DuctTape = 10,
	},
}

local kitsById: { [string]: Kit } = {
	--// MedicalKit = {
	--// 	id = "MedicalKit",
	--// 	displayName = "Medical Kit",
	--// 	gamePassId = 0,

	--// 	items = {
	--// 		{ itemType = "Bandage", stackCount = 5, preferredZone = hotbar, preferredIndex = 9 },
	--// 		{ itemType = "Painkillers", stackCount = 2 },
	--// 	},

	--// 	materials = {
	--// 		DuctTape = 20,
	--// 	},
	--// },
}

local function getItemTypes(loadout: Loadout): { string }
	local itemTypes: { string } = {}
	for _, loadoutItem in ipairs(loadout.items) do
		table.insert(itemTypes, loadoutItem.itemType)
	end
	return itemTypes
end

return table.freeze({
	starter = starterLoadout,
	kits = kitsById,
	getItemTypes = getItemTypes,
})
