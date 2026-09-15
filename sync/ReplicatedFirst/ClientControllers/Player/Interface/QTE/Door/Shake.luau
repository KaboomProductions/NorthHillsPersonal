local workspace = game:GetService("Workspace")

local doorConfig = require(script.Parent.Config)

local shakeHandler = {}

function shakeHandler.decayScreenShake(screenShake: number, deltaTime: number): number
	return screenShake * math.exp(-doorConfig.kickScreenShakeDecay * deltaTime)
end

function shakeHandler.addScreenShake(screenShake: number, kickDistance: number): number
	return screenShake + kickDistance * doorConfig.kickScreenShakeIntensity / doorConfig.kickDistance
end

function shakeHandler.computeUiShakeOffset(screenShake: number): Vector2
	if screenShake <= 0.0001 then
		return Vector2.zero
	end

	return Vector2.new((math.random() - 0.5) * 2 * screenShake, (math.random() - 0.5) * 2 * screenShake)
end

function shakeHandler.applyCameraShake(frozenCFrame: CFrame, _screenShake: number)
	workspace.CurrentCamera.CFrame = frozenCFrame
end

function shakeHandler.applyFovBump(kickDistance: number)
	local camera = workspace.CurrentCamera
	local kickStrength = kickDistance / doorConfig.kickDistance
	camera.FieldOfView = camera.FieldOfView + kickStrength * doorConfig.kickFovBump
end

return shakeHandler
