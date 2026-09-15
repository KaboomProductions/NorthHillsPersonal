local replicatedStorage = game:GetService("ReplicatedStorage")

local precipitationType = require(replicatedStorage.SharedAssets.PrecipitationType)

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local climateStateValue = cycleValues.ClimateState

local dryState = {}
dryState.__config = {
	cloudProperties = {
		Cover = 0,
		Density = 0,
	},

	globalWindProperties = {
		minStrength = 0,
		maxStrength = 1,
	},
}

function dryState.enter()
	climateStateValue:RemoveTag("Windy")
	climateStateValue:SetAttribute("PrecipitationType", precipitationType.None)
end

return dryState
