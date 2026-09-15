local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local player = players.LocalPlayer
local playerGui = player.PlayerGui

local interfaceGui = playerGui:WaitForChild("Interface", 3)
local vignettes = interfaceGui.Vignettes

local acidVignette = vignettes.Acid
local baseVignettePosition = acidVignette.Position
local baseVignetteRotation = acidVignette.Rotation

local corrodingDefinition = {}
corrodingDefinition.endDuration = 0.5
corrodingDefinition.activeTween = nil
corrodingDefinition.connections = {}
corrodingDefinition.__vars = {
	shakeAmplitude = 6,
	shakeSpeed = 6,
	rotationAmplitude = 1.5,
	rotationSpeed = 3,
}

function corrodingDefinition.cancelTween()
	if corrodingDefinition.activeTween then
		corrodingDefinition.activeTween:Cancel()
		corrodingDefinition.activeTween = nil
	end
end

function corrodingDefinition.disconnectAll()
	for key, connection in corrodingDefinition.connections do
		connection:Disconnect()
		corrodingDefinition.connections[key] = nil
	end
end

function corrodingDefinition.build()
	local seedX = math.random() * 1000
	local seedY = math.random() * 1000
	local seedRotation = math.random() * 1000

	corrodingDefinition.cancelTween()
	corrodingDefinition.disconnectAll()

	corrodingDefinition.activeTween =
		tweenService:Create(acidVignette, TweenInfo.new(corrodingDefinition.endDuration), {
			ImageTransparency = 0,
		})

	corrodingDefinition.activeTween:Play()

	corrodingDefinition.connections.update = runService.RenderStepped:Connect(function(_deltaTime: number)
		local vars = corrodingDefinition.__vars
		local t = os.clock()

		local offsetX = (math.noise(t * vars.shakeSpeed, seedX) - 0.5) * 2 * vars.shakeAmplitude
		local offsetY = (math.noise(t * vars.shakeSpeed, seedY) - 0.5) * 2 * vars.shakeAmplitude
		local offsetRotation = (math.noise(t * vars.rotationSpeed, seedRotation) - 0.5) * 2 * vars.rotationAmplitude

		acidVignette.Position = baseVignettePosition + UDim2.fromOffset(offsetX, offsetY)
		acidVignette.Rotation = baseVignetteRotation + offsetRotation
	end)

	return {}, corrodingDefinition.connections
end

function corrodingDefinition.destroy()
	corrodingDefinition.cancelTween()

	corrodingDefinition.activeTween =
		tweenService:Create(acidVignette, TweenInfo.new(corrodingDefinition.endDuration), {
			ImageTransparency = 1,
		})

	corrodingDefinition.activeTween:Play()

	corrodingDefinition.activeTween.Completed:Once(function()
		acidVignette.Position = baseVignettePosition
		acidVignette.Rotation = baseVignetteRotation
	end)
end

return corrodingDefinition
