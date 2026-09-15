local rayCastingUtilities = {}
local maximumAimDistanceStuds = 50
local maximumRaycastPasses = 8
local minimumRemainingDistanceStuds = 0.05
local ignoredHitTransparency = 0.95
local ignoredHitTags = { "RaycastIgnore", "CanSeeThrough", "CanQueryFalse" }

local cachedRaycastParams = RaycastParams.new()
cachedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
cachedRaycastParams.IgnoreWater = true

function rayCastingUtilities.isIgnoredHit(instance: Instance): boolean
	if not instance then
		return true
	end

	local part: BasePart? = instance:IsA("BasePart") and instance or instance:FindFirstAncestorWhichIsA("BasePart")
	if not part then
		return true
	end

	for _, tagName in ignoredHitTags do
		if part:HasTag(tagName) then
			return true
		end
	end

	if part.Transparency >= ignoredHitTransparency then
		return true
	end

	if part.CanCollide == false then
		return true
	end

	return false
end

function rayCastingUtilities.raycastUntilBlockingHit(
	origin: Vector3,
	direction: Vector3,
	raycastParams: RaycastParams
): RaycastResult?
	local destination = origin + direction
	local remainingOrigin = origin
	local remainingDirection = direction

	for _ = 1, maximumRaycastPasses do
		local raycastResult = workspace:Raycast(remainingOrigin, remainingDirection, raycastParams)
		if raycastResult == nil or not rayCastingUtilities.isIgnoredHit(raycastResult.Instance) then
			return raycastResult
		end

		raycastParams:AddToFilter(raycastResult.Instance)
		remainingOrigin = raycastResult.Position + remainingDirection.Unit * 0.01
		remainingDirection = destination - remainingOrigin
		if remainingDirection.Magnitude <= minimumRemainingDistanceStuds then
			break
		end
	end

	return nil
end

function rayCastingUtilities.getAimPosition(camera: Camera, player: Player): Vector3?
	if not camera then
		return nil
	end

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * maximumAimDistanceStuds

	local character = player.Character

	local ignoreFolder = workspace:FindFirstChild("Ignore")
	local componentsFolder = workspace:FindFirstChild("Components")
	local charactersFolder = componentsFolder and componentsFolder:FindFirstChild("Characters")

	local filterInstances = {}

	if character then
		table.insert(filterInstances, character)
	end

	if ignoreFolder then
		table.insert(filterInstances, ignoreFolder)
	end

	if charactersFolder then
		table.insert(filterInstances, charactersFolder)
	end

	cachedRaycastParams.FilterDescendantsInstances = filterInstances

	local blockingHit = rayCastingUtilities.raycastUntilBlockingHit(origin, direction, cachedRaycastParams)
	return if blockingHit == nil then origin + direction else blockingHit.Position
end

return rayCastingUtilities
