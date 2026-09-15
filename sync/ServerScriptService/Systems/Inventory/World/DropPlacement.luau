--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local dropPlacement = {}

function dropPlacement.calculate(player: Player, worldItems: Folder, requestedDirection: Vector3?): CFrame?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	local lookVector: Vector3
	if protocol.isFiniteVector3(requestedDirection) then
		lookVector = requestedDirection :: Vector3
	else
		lookVector = root.CFrame.LookVector
	end
	local horizontal = Vector3.new(lookVector.X, 0, lookVector.Z)
	if horizontal.Magnitude < 0.001 then
		horizontal = Vector3.zAxis
	else
		horizontal = horizontal.Unit
	end

	local position = root.Position + horizontal * 4
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character, worldItems }
	local ground = workspace:Raycast(position, Vector3.yAxis * -64, raycastParams)
	if ground then
		position = Vector3.new(position.X, ground.Position.Y, position.Z)
	else
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hipHeight = if humanoid then humanoid.HipHeight else 2
		position -= Vector3.yAxis * (root.Size.Y / 2 + hipHeight)
	end
	return CFrame.lookAt(position, position + horizontal)
end

return dropPlacement
