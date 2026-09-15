local resultDefinitions = {}
resultDefinitions.moneyFormat = "+$%s"
resultDefinitions.mainFormat = resultDefinitions.moneyFormat .. " %s"

resultDefinitions.survived = {
	label = "for surviving",
	reward = 1000,
	order = 1,
}

resultDefinitions.nonSurvived = {
	label = "-50% for failing to survive the night",
	noGain = true,
	resultColor = Color3.fromRGB(255, 80, 80),
	order = 100,
}

resultDefinitions.inGroup = {
	label = "for being in the Roblox group",
	reward = 500,
	resultColor = Color3.fromRGB(255, 208, 81),
	resultSize = UDim2.fromScale(0.95, 0.064),
	order = 2,
}

resultDefinitions.damageDealt = {
	label = "dealing %s units of damage to enemies",
	mode = "scaled",
	pointsPerUnit = 1,
	cap = 1000,
	order = 3,
}

return table.freeze(resultDefinitions)
