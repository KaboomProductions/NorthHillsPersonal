local replicatedStorage = game:GetService("ReplicatedStorage")

local precipitationType = require(replicatedStorage.SharedAssets.PrecipitationType)

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local climateStateValue = cycleValues.ClimateState

local wetState = {}
wetState.__config = {
	cloudProperties = {
		Cover = 0.7,
		Density = 0.3,
	},

	globalWindProperties = {
		minStrength = 3,
		maxStrength = 4,
	},
}

function wetState.enter()
	climateStateValue:RemoveTag("Windy")
	climateStateValue:SetAttribute("PrecipitationType", precipitationType.Wet)
end

return wetState
