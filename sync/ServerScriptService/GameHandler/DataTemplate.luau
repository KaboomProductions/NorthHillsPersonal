--// Reconcile fills absent keys recursively, so slots and setting definitions must never live in this template.
--// Controllers/StarterItems owns the spawn loadout; the inventory hydrator owns the inventory schema.
return {
	Settings = {},
	Inventory = {},
	Money = 0,
	Survivals = 0,
}
