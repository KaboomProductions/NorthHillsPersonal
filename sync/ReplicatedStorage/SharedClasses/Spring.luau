local spring = {}
spring.__index = spring

local iterations = 64

function spring.new(zeroVector: Vector3? | Vector2?, mass: number?, force: number?, damping: number?, speed: number?)
	local zeroVelocity = if typeof(zeroVector) == "Vector3" then Vector3.zero else Vector2.zero

	local self = setmetatable({
		target = zeroVector,
		position = zeroVector,
		velocity = zeroVelocity,

		mass = mass or 5,
		force = force or 50,
		damping = damping or 4,
		speed = speed or 4,
	}, spring)

	return self
end

function spring:shove(force: Vector3 | Vector2)
	local xForce = force.X
	local yForce = force.Y
	local zForce = nil

	if typeof(force) == "Vector3" then
		zForce = force.Z
	end

	if xForce ~= xForce or xForce == math.huge or xForce == -math.huge then
		xForce = 0
	end
	if yForce ~= yForce or yForce == math.huge or yForce == -math.huge then
		yForce = 0
	end

	if zForce ~= nil then
		if zForce ~= zForce or zForce == math.huge or zForce == -math.huge then
			zForce = 0
		end
		self.velocity += Vector3.new(xForce, yForce, zForce)
	else
		self.velocity += Vector2.new(xForce, yForce)
	end
end

function spring:update(deltaTime: number)
	local scaledDeltaTime = math.min(deltaTime, 1) * self.speed / iterations

	for _ = 1, iterations do
		local iterationForce = self.target - self.position
		local acceleration = (iterationForce * self.force) / self.mass
		acceleration -= self.velocity * self.damping

		self.velocity += acceleration * scaledDeltaTime
		self.position += self.velocity * scaledDeltaTime
	end

	return self.position
end

return spring
