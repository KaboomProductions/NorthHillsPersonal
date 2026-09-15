local runService = game:GetService("RunService")
local debris = game:GetService("Debris")

return {
	castBehavior = {
		MaxDistance = 1000,
		Acceleration = Vector3.yAxis * -workspace.Gravity / 2,
	},

	onStartup = function(_cast) end,

	onRayHit = function(_cast, _raycastResult, _segmentVelocity, _bullet) end,

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
