local replicatedStorage = game:GetService("ReplicatedStorage")

local precipitationType = require(replicatedStorage.SharedAssets.PrecipitationType)

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local climateStateValue = cycleValues.ClimateState

local rainyState = {}
rainyState.__config = {
	cloudProperties = {
		Cover = 0.8,
		Density = 0.6,
	},

	globalWindProperties = {
		minStrength = 7.5,
		maxStrength = 10,
	},
}

function rainyState.enter()
	climateStateValue:AddTag("Windy")
	climateStateValue:SetAttribute("PrecipitationType", precipitationType.Rain)
end

return rainyState
