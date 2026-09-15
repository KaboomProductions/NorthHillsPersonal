local helpers = {}

function helpers.flattenXZ(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function helpers.safeNormalizedDirection(vector: Vector3): Vector3
	local magnitude = vector.Magnitude
	if magnitude <= 1e-6 then
		return Vector3.new(0, 0, -1)
	end

	return vector / magnitude
end

return helpers
