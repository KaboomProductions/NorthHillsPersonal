local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local debris = game:GetService("Debris")

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local audioUtils = require(sharedUtilities.AudioUtils)

local effects = sharedAssets.Effects
local sounds = effects.Sounds
local toolSounds = sounds.Tools

return {
	castBehavior = {
		MaxDistance = math.huge,
		Acceleration = Vector3.yAxis * -workspace.Gravity / 2,
	},

	onStartup = function(cast)
		local userData = cast.UserData
		local rayInfo = cast.RayInfo

		if userData and rayInfo then
			local cosmeticBulletObject = rayInfo.CosmeticBulletObject
			local specialInfo = userData.specialInfo
			local trueId = specialInfo.trueId

			if trueId ~= nil then
				local neededSounds = toolSounds:FindFirstChild(trueId)
				local spinningSound = neededSounds:FindFirstChild("Spinning")

				if spinningSound then
					audioUtils.playSound({
						sound = spinningSound,
						parent = cosmeticBulletObject,
						playbackSpeed = math.random(900, 1100) / 1000,
					})
				end
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
			debris:AddItem(cosmeticBulletObject, 1)
		end
	end,

	onLengthChanged = function(cast, lastPoint, rayDirection, displacement, _segmentVelocity, projectile)
		local userData = cast.UserData
		userData.spinAmount = userData.spinAmount or 0
		userData.spinAmount = userData.spinAmount - 0.15

		if projectile then
			local currentPoint = lastPoint + (rayDirection * displacement)
			local start = lastPoint + (rayDirection * displacement / 2)

			projectile:PivotTo(CFrame.new(start, currentPoint) * CFrame.Angles(userData.spinAmount, 0, 0))
		end
	end,
}
