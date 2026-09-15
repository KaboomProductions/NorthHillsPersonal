local replicatedStorage = game:GetService("ReplicatedStorage")

local precipitationType = require(replicatedStorage.SharedAssets.PrecipitationType)

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local climateStateValue = cycleValues.ClimateState

local windyState = {}
windyState.__config = {
	windEffects = true,

	cloudProperties = {
		Cover = 0.9,
		Density = 0.1,
		Color = Color3.fromRGB(93, 93, 93),
	},

	globalWindProperties = {
		minStrength = 10,
		maxStrength = 15,
	},
}

function windyState.enter()
	climateStateValue:AddTag("Windy")
	climateStateValue:SetAttribute("PrecipitationType", precipitationType.None)
end

return windyState
