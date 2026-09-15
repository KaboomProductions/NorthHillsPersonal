-- Dynamic slots and setting definitions must never be recursively reconciled into saved values.
-- StarterItems owns the spawn loadout; the hydrator owns the inventory schema.
return {
	Settings = {},
	Inventory = {},
}
