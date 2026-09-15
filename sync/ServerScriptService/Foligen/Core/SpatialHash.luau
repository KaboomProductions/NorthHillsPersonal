export type spatialHashInstance = {
	cellSize: number,
	buckets: { [string]: { Vector3 } },
	hasNearbyPosition: (self: spatialHashInstance, position: Vector3, minimumDistance: number) -> boolean,
	insert: (self: spatialHashInstance, position: Vector3) -> (),
}

--||------------------------------------------------------------------||
--||                   Foligen Module | SpatialHash                   ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Tracks nearby placements efficiently for spacing checks.        ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local spatialHash = {}
spatialHash.__index = spatialHash

local function getCellKey(cellX: number, cellZ: number): string
	return ("%d:%d"):format(cellX, cellZ)
end

function spatialHash:hasNearbyPosition(position: Vector3, minimumDistance: number): boolean
	local cellSize = self.cellSize
	local cellX = math.floor(position.X / cellSize)
	local cellZ = math.floor(position.Z / cellSize)
	local minimumDistanceSquared = minimumDistance * minimumDistance

	for offsetX = -1, 1 do
		for offsetZ = -1, 1 do
			local bucket = self.buckets[getCellKey(cellX + offsetX, cellZ + offsetZ)]
			if bucket == nil then
				continue
			end

			for _, nearbyPosition in ipairs(bucket) do
				local positionDelta = nearbyPosition - position
				local distanceSquared = (positionDelta.X * positionDelta.X) + (positionDelta.Z * positionDelta.Z)
				if distanceSquared < minimumDistanceSquared then
					return true
				end
			end
		end
	end

	return false
end

function spatialHash:insert(position: Vector3)
	local cellSize = self.cellSize
	local cellX = math.floor(position.X / cellSize)
	local cellZ = math.floor(position.Z / cellSize)
	local cellKey = getCellKey(cellX, cellZ)
	local bucket = self.buckets[cellKey]

	if bucket == nil then
		bucket = {}
		self.buckets[cellKey] = bucket
	end

	table.insert(bucket, position)
end

function spatialHash.fromFolder(folder: Instance, cellSize: number): spatialHashInstance
	local self = setmetatable({}, spatialHash)

	self.cellSize = math.max(0.01, cellSize)
	self.buckets = {} :: { [string]: { Vector3 } }

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			self:insert(child:GetPivot().Position)
		end
	end

	return self
end

return spatialHash
