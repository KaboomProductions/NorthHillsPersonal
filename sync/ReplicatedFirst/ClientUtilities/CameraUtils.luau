local cameraUtilities = {}

function cameraUtilities.getCurrentCamera(): Camera
	local currentCamera = workspace.CurrentCamera

	while currentCamera == nil do
		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
		currentCamera = workspace.CurrentCamera
	end

	return currentCamera
end

return cameraUtilities
