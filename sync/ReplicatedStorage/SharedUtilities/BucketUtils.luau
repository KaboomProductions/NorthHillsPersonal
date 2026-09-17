export type booleanRequestTable = { [string]: boolean }
export type numberModifierTable = { [string]: number }

local bucketUtilities = {}

function bucketUtilities.hasEnabledRequest(requestsBySource: booleanRequestTable): boolean
	for _, isEnabled in pairs(requestsBySource) do
		if isEnabled then
			return true
		end
	end

	return false
end

function bucketUtilities.getTotalModifier(baseValue: number, modifiersBySource: numberModifierTable): number
	local totalValue = baseValue

	for _, modifierValue in pairs(modifiersBySource) do
		totalValue += modifierValue
	end

	return totalValue
end

function bucketUtilities.getRandomPositionInPart(part: BasePart): Vector3
	local size = part.Size
	local halfX = size.X / 2
	local halfZ = size.Z / 2

	local randomX = (math.random() * size.X) - halfX
	local randomZ = (math.random() * size.Z) - halfZ
	local worldOffset = part.CFrame:PointToWorldSpace(Vector3.new(randomX, 0, randomZ))

	return Vector3.new(worldOffset.X, part.Position.Y, worldOffset.Z)
end

function bucketUtilities.getVelocityPrediction(part: BasePart, multiplier: number): Vector3
	return part.CFrame:VectorToObjectSpace(part.AssemblyLinearVelocity) * multiplier
end

function bucketUtilities.checkInRegion(region: BasePart, origin: Vector3, padding: number?)
	local localPos = region.CFrame:PointToObjectSpace(origin)
	local halfSize = region.Size * 0.5 + Vector3.one * (padding or 0)

	return math.abs(localPos.X) <= halfSize.X
		and math.abs(localPos.Y) <= halfSize.Y
		and math.abs(localPos.Z) <= halfSize.Z
end

function bucketUtilities.attachParticlesOnInstance(info: {
	particleHolder: any,
	parentTo: BasePart | Attachment,
	startEnabled: boolean?,
})
	info.particleHolder = info.particleHolder:GetChildren()

	if info.startEnabled == nil then
		info.startEnabled = false
	end

	local returnedEffects = {}

	for _, effect in info.particleHolder do
		local newEffect = effect:Clone()
		newEffect.Enabled = info.startEnabled
		newEffect.Parent = info.parentTo

		table.insert(returnedEffects, newEffect)
	end

	return returnedEffects
end

function bucketUtilities.emitParticles(effects: { ParticleEmitter })
	for _, effect in effects do
		if not effect:IsA("ParticleEmitter") then
			continue
		end

		local emitCount = effect:GetAttribute("EmitCount") or 1
		local emitDelay = effect:GetAttribute("EmitDelay") or 0

		task.delay(emitDelay, function()
			effect:Emit(emitCount)
		end)
	end
end

function bucketUtilities.cleanUpEffects(effects: { any })
	for _, effect in effects do
		effect:Destroy()
		effect = nil
	end
end

function bucketUtilities.fetchMaxLifetimeForParticles(effects: { ParticleEmitter })
	local currentLifetime = 0

	for _, effect in effects do
		if not effect:IsA("ParticleEmitter") then
			continue
		end

		if effect.Lifetime.Max > currentLifetime then
			currentLifetime = effect.Lifetime.Max
		end
	end

	return currentLifetime
end

function bucketUtilities.applyPropertiesToInstance(instance: Instance?, properties: { any })
	if not instance or not properties then
		return
	end

	for property, value in properties do
		instance[property] = value
	end
end

return bucketUtilities
