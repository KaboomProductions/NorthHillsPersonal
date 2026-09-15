export type kickState = {
	isPressureActive: boolean,
	pressureEndTime: number,
	pressureDirection: Vector2,
}

local kickHandler = {}

function kickHandler.createState(): kickState
	return {
		isPressureActive = false,
		pressureEndTime = 0,
		pressureDirection = Vector2.zero,
	}
end

function kickHandler.computeKickDisplacement(cursorPosition: Vector2, distance: number): Vector2
	local baseAngle

	if cursorPosition.Magnitude > 0.001 then
		baseAngle = math.atan2(cursorPosition.Y, cursorPosition.X)
		baseAngle = baseAngle + (math.random() - 0.5) * math.rad(270)
	else
		baseAngle = math.random() * math.pi * 2
	end

	return Vector2.new(math.cos(baseAngle), math.sin(baseAngle)) * distance
end

return kickHandler
