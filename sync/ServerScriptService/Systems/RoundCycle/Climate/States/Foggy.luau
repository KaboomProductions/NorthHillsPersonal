local replicatedStorage = game:GetService("ReplicatedStorage")

local precipitationType = require(replicatedStorage.SharedAssets.PrecipitationType)

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local climateStateValue = cycleValues.ClimateState

local foggyState = {}
foggyState.__config = {
	volumetrics = {
		layers = 170,
		spacing = 1.1,
	},

	cloudProperties = {
		Cover = 1,
		Density = 1,
	},

	globalWindProperties = {
		minStrength = 0,
		maxStrength = 1,
	},
}

function foggyState.enter()
	climateStateValue:RemoveTag("Windy")
	climateStateValue:SetAttribute("PrecipitationType", precipitationType.None)
end

return foggyState
