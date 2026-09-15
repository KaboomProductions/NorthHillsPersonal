local debris = game:GetService("Debris")
local runService = game:GetService("RunService")

return {
	castBehavior = {
		MaxDistance = 300,
		Acceleration = Vector3.yAxis * -workspace.Gravity,
	},

	onStartup = function(_cast) end,

	onRayHit = function(_cast) end,

	onCastTerminated = function(cast)
		if not runService:IsClient() then
			return
		end
		runService.PreRender:Wait()
		local rayInfo = cast.RayInfo
		local cosmetic = rayInfo and rayInfo.CosmeticBulletObject
		if cosmetic then
			debris:AddItem(cosmetic, 1)
		end
	end,

	onLengthChanged = function(cast, lastPoint, direction, length, _segmentVelocity, projectile)
		if projectile == nil then
			return
		end
		local userData = cast.UserData
		userData.spinAmount = (userData.spinAmount or 0) - 0.18
		local currentPoint = lastPoint + direction * length
		projectile:PivotTo(
			CFrame.new(currentPoint, currentPoint + direction) * CFrame.Angles(userData.spinAmount, 0, 0)
		)
	end,
}
