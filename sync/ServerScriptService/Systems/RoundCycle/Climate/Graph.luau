--// Climate transition graph
--//
--// Each node defines where it can escalate and de-escalate to,
--// its severity level (1 = calmest, 6 = most intense), and
--// its base chance to escalate vs de-escalate (before mean reversion).
--//
--//   Dry (1) <──> Clear (2) <──> Windy (3) <──> Foggy (4) ──> Rainy (5) <──> Stormy (6)
--//                                               Clear <── Foggy
--//                                  Clear <── Wet (4) ──> Rainy
--//                                            Clear <── Rainy

local climateGraph = {
	Dry = {
		escalate = nil,
		deEscalate = "Clear",
		severity = 1,
		escalateWeight = 0.5,
	},

	Clear = {
		escalate = "Windy",
		deEscalate = "Dry",
		severity = 2,
		escalateWeight = 0.3,
	},

	Windy = {
		escalate = "Foggy",
		deEscalate = "Clear",
		severity = 3,
		escalateWeight = 0.5,
	},

	Foggy = {
		escalate = "Rainy",
		deEscalate = "Clear",
		severity = 4,
		escalateWeight = 0.5,
	},

	Wet = {
		escalate = "Rainy",
		deEscalate = "Clear",
		severity = 4,
		escalateWeight = 0.5,
	},

	Rainy = {
		escalate = "Stormy",
		deEscalate = "Foggy",
		severity = 5,
		escalateWeight = 0.5,
	},

	Stormy = {
		escalate = nil,
		deEscalate = "Rainy",
		severity = 6,
		escalateWeight = 0.5,
	},
}

return table.freeze(climateGraph)
