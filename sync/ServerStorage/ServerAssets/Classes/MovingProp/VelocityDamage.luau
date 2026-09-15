local velocityDamage = {}

function velocityDamage.isAboveVelocityThreshold(velocityMagnitude: number, minimumVelocity: number): boolean
	return velocityMagnitude >= minimumVelocity
end

function velocityDamage.calculateDamageFromVelocity(config: {
		baseDamage: number,
		maximumDamage: number,
		velocity: number,
		minimumVelocity: number,
		maximumVelocity: number,
	}): number
	
	local baseDamage = config.baseDamage
	local maximumDamage = config.maximumDamage
	local minimumVelocity = config.minimumVelocity
	local maximumVelocity = config.maximumVelocity
	local velocity = config.velocity

	if maximumVelocity <= minimumVelocity then
		return maximumDamage
	end

	local clampedVelocity = math.clamp(velocity, minimumVelocity, maximumVelocity)
	local alpha = (clampedVelocity - minimumVelocity) / (maximumVelocity - minimumVelocity)

	return baseDamage + ((maximumDamage - baseDamage) * alpha)
end

return velocityDamage
