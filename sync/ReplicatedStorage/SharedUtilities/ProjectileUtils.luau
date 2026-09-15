local projectileUtils = {}

function projectileUtils.generatePathPoints(origin, velocity, gravity, deltaTime, steps)
	local points = {}

	local pos = origin
	local vel = velocity

	for _index = 1, steps do
		table.insert(points, pos)

		vel = vel + gravity * deltaTime
		pos = pos + vel * deltaTime
	end

	return points
end

return projectileUtils
