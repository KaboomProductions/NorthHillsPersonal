local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)
local networking = require(replicatedStorage.Communication.Networking)

local streamingReplicationController = {}
local cameraPositionTolerance = 1

function streamingReplicationController.onEvent(player: Player, initialCFrame: unknown)
	-- Reset is allocation-free and must remain available after a burst of requests.
	if initialCFrame == nil then
		player.ReplicationFocus = nil
		return
	end
	if not remoteGuard.allow(player, "streaming", 4, 1) or not remoteGuard.isFiniteCFrame(initialCFrame) then
		return
	end
	local ignore = workspace:FindFirstChild("Ignore")
	local other = ignore and ignore:FindFirstChild("Other")
	local cameras = other and other:FindFirstChild("MenuCams")
	if cameras == nil then
		return
	end
	for _, camera in cameras:GetChildren() do
		if camera:IsA("BasePart") and (camera.Position - (initialCFrame :: CFrame).Position).Magnitude <= cameraPositionTolerance then
			player.ReplicationFocus = camera
			return
		end
	end
end

function streamingReplicationController.init()
	networking.events.replicateStreaming.OnServerEvent:Connect(streamingReplicationController.onEvent)
end

return streamingReplicationController
