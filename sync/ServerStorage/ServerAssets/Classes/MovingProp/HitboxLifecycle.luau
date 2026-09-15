local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedClasses = replicatedStorage.SharedClasses

local hitboxController = require(sharedClasses.Hitbox)

local hitboxLifecycle = {}

function hitboxLifecycle.start(prop: BasePart, overlapParams: OverlapParams, sizeMultiplier: number)
	local hitbox = hitboxController.CreateHitbox()
	hitbox.OverlapParams = overlapParams
	hitbox.Size = prop.Size * sizeMultiplier
	hitbox.CFrame = prop.CFrame
	hitbox:Start()

	return hitbox
end

function hitboxLifecycle.stop(hitbox)
	if hitbox == nil then
		return
	end

	hitbox:Stop()
end

function hitboxLifecycle.update(hitbox, prop: BasePart)
	if hitbox == nil then
		return
	end

	hitbox.CFrame = prop.CFrame
end

return hitboxLifecycle
