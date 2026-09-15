local replicatedStorage = game:GetService("ReplicatedStorage")

local precipitationType = require(replicatedStorage.SharedAssets.PrecipitationType)

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local climateStateValue = cycleValues.ClimateState

local clearState = {}
clearState.__config = {
	cloudProperties = {
		Cover = 0.729,
		Density = 0.048,
	},

	globalWindProperties = {
		minStrength = 0,
		maxStrength = 1,
	},
}

function clearState.enter()
	climateStateValue:RemoveTag("Windy")
	climateStateValue:SetAttribute("PrecipitationType", precipitationType.None)
end

return clearState
