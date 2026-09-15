local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local debris = game:GetService("Debris")
local serverStorage = game:GetService("ServerStorage")

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local audioUtils = require(sharedUtilities.AudioUtils)

local effects = sharedAssets.Effects
local sounds = effects.Sounds

local projectileSounds = sounds.Projectiles
local spitSounds = projectileSounds.Spit
local damageSounds = spitSounds.Damage:GetChildren()

return {
	castBehavior = {
		MaxDistance = 150,
		Acceleration = Vector3.yAxis * -workspace.Gravity / 2,
	},

	onStartup = function(_cast) end,

	onRayHit = function(_cast, raycastResult, _segmentVelocity, _bullet)
		local part = raycastResult.Instance
		local position = raycastResult.Position

		if part then
			local character = part:FindFirstAncestorOfClass("Model")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = humanoid and humanoid.RootPart or character and character.PrimaryPart or nil

			if runService:IsServer() then
				local serverAssets = serverStorage.ServerAssets
				local classes = serverAssets.Classes

				local spitPuddleController = require(classes.SpitPuddle)
				spitPuddleController.new(position)

				if humanoid ~= nil then
					humanoid:TakeDamage(5)
				end
			else
				audioUtils.playSound({
					sound = damageSounds[math.random(1, #damageSounds)],
					parent = rootPart,
				})
			end
		end
	end,

	onCastTerminated = function(cast)
		if runService:IsClient() then
			runService.PreRender:Wait()
		end

		local rayInfo = cast.RayInfo
		local cosmeticBulletObject = rayInfo.CosmeticBulletObject

		if cosmeticBulletObject then
			if cosmeticBulletObject:IsA("BasePart") then
				cosmeticBulletObject.Transparency = 1
			end

			for _, object in cosmeticBulletObject:QueryDescendants("[Enabled = true]") do
				object.Enabled = false
			end

			debris:AddItem(cosmeticBulletObject, 1)
		end
	end,

	onLengthChanged = function(_cast, lastPoint, rayDirection, displacement, _segmentVelocity, projectile)
		if projectile then
			local currentPoint = lastPoint + (rayDirection * displacement)
			local start = lastPoint + (rayDirection * displacement / 2)

			projectile:PivotTo(CFrame.new(start, currentPoint))
		end
	end,
}
