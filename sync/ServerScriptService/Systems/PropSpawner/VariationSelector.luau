local propSpawnerSettings = require(script.Parent.Config)
local variationSelectionSettings = propSpawnerSettings.variationSelection

export type PlacedProp = {
	position: Vector3,
	variation: PVInstance,
}

local variationSelector = {}
variationSelector.__index = variationSelector
variationSelector.__vars = {
	influenceRadiusStuds = variationSelectionSettings.influenceRadiusStuds,
	influenceFalloffPower = variationSelectionSettings.influenceFalloffPower,
	tieToleranceThreshold = variationSelectionSettings.tieToleranceThreshold,
}

local function getCellKey(cellX: number, cellY: number, cellZ: number): string
	return ("%d:%d:%d"):format(cellX, cellY, cellZ)
end

function variationSelector:getCellCoordinates(position: Vector3): (number, number, number)
	local cellSize = self.__vars.influenceRadiusStuds
	return math.floor(position.X / cellSize), math.floor(position.Y / cellSize), math.floor(position.Z / cellSize)
end

function variationSelector:getPlacementsByCellKey(className: string): { [string]: { PlacedProp } }
	local placementsByCellKey = self.placementsByClassName[className]
	if placementsByCellKey == nil then
		placementsByCellKey = {}
		self.placementsByClassName[className] = placementsByCellKey
	end

	return placementsByCellKey
end

function variationSelector:calculatePenaltiesByVariation(className: string, position: Vector3): { [PVInstance]: number }
	local stateValues = self.__vars
	local influenceRadiusStuds = stateValues.influenceRadiusStuds
	local placementsByCellKey = self:getPlacementsByCellKey(className)
	local penaltiesByVariation: { [PVInstance]: number } = {}
	local cellX, cellY, cellZ = self:getCellCoordinates(position)

	for offsetX = -1, 1 do
		for offsetY = -1, 1 do
			for offsetZ = -1, 1 do
				local placements = placementsByCellKey[getCellKey(cellX + offsetX, cellY + offsetY, cellZ + offsetZ)]
				if placements == nil then
					continue
				end

				for _, placement in ipairs(placements) do
					local distanceStuds = (placement.position - position).Magnitude
					if distanceStuds >= influenceRadiusStuds then
						continue
					end

					local closeness = 1 - (distanceStuds / influenceRadiusStuds)
					local currentPenalty = penaltiesByVariation[placement.variation] or 0
					penaltiesByVariation[placement.variation] = currentPenalty
						+ closeness ^ stateValues.influenceFalloffPower
				end
			end
		end
	end

	return penaltiesByVariation
end

function variationSelector:selectVariation(className: string, position: Vector3, variations: { PVInstance }): PVInstance
	if #variations == 1 then
		return variations[1]
	end

	local tieToleranceThreshold = self.__vars.tieToleranceThreshold
	local penaltiesByVariation = self:calculatePenaltiesByVariation(className, position)
	local leastRepeatedVariations: { PVInstance } = {}
	local lowestPenalty = math.huge

	for _, variation in ipairs(variations) do
		local penalty = penaltiesByVariation[variation] or 0

		if penalty < lowestPenalty - tieToleranceThreshold then
			lowestPenalty = penalty
			table.clear(leastRepeatedVariations)
			table.insert(leastRepeatedVariations, variation)
		elseif penalty <= lowestPenalty + tieToleranceThreshold then
			table.insert(leastRepeatedVariations, variation)
		end
	end

	return leastRepeatedVariations[self.randomGenerator:NextInteger(1, #leastRepeatedVariations)]
end

function variationSelector:recordPlacement(className: string, position: Vector3, variation: PVInstance)
	local placementsByCellKey = self:getPlacementsByCellKey(className)
	local cellX, cellY, cellZ = self:getCellCoordinates(position)
	local cellKey = getCellKey(cellX, cellY, cellZ)
	local placements = placementsByCellKey[cellKey]

	if placements == nil then
		placements = {}
		placementsByCellKey[cellKey] = placements
	end

	table.insert(placements, {
		position = position,
		variation = variation,
	})
end

function variationSelector.new(randomGenerator: Random?)
	local self = setmetatable({}, variationSelector)

	self.__vars = table.clone(variationSelector.__vars)
	self.placementsByClassName = {} :: { [string]: { [string]: { PlacedProp } } }
	self.randomGenerator = randomGenerator or Random.new()

	return self
end

return variationSelector
