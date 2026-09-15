local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local collectionService = game:GetService("CollectionService")

local sharedAssets = replicatedStorage.SharedAssets
local regionsMap = sharedAssets.Regions:GetChildren()

local assets = serverStorage.ServerAssets
local prefabs = assets.Prefabs
local targetPrefab = prefabs.Target

local componentsFolder = workspace.Components
local entitiesFolder = componentsFolder.Entities

local targetCacheRefreshIntervalSeconds = 0.15
local targetingController = {}
targetingController.__index = targetingController

export type nearestTargetInfo = {
	range: number?,
	canRaycast: boolean?,
	overrideCurrentTarget: boolean?,
	useTargetCache: boolean?,
	fieldOfView: number?,
}

export type targetData = {
	agent: Model,
	root: BasePart,
	humanoid: Humanoid,
	player: Player?,
	distance: number?,
	isRagdolled: boolean?,
}

function targetingController:refreshAvailableTargets()
	local now = os.clock()
	if now - self.lastTargetRefreshTime < targetCacheRefreshIntervalSeconds then
		return self.cachedAvailableTargets
	end

	self.lastTargetRefreshTime = now

	local availableTargets = {}
	local componentChildren = componentsFolder:GetChildren()

	for _, folder in componentChildren do
		if folder == entitiesFolder then
			continue
		end

		for _, character in folder:GetChildren() do
			if not character:IsA("Model") then
				continue
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = humanoid and (humanoid.RootPart or character:FindFirstChild("HumanoidRootPart"))

			if not humanoid or not rootPart then
				continue
			end

			if humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid.Health <= 0 then
				continue
			end

			table.insert(availableTargets, {
				agent = character,
				root = rootPart,
				humanoid = humanoid,
				isRagdolled = character:GetAttribute("Ragdolled") == true,
			})
		end
	end

	self.cachedAvailableTargets = availableTargets
	return availableTargets
end

function targetingController:isTargetVisible(target: targetData, range: number?): boolean
	if not target then
		return false
	end

	local effectiveRange = range or 500
	local originPart = self.rootPart
	local targetPart = target.root

	local direction = targetPart.Position - originPart.Position
	if direction.Magnitude > effectiveRange then
		return false
	end

	local visibilityRaycastParams = self.visibilityRaycastParams
	visibilityRaycastParams.FilterDescendantsInstances =
		{ self.agent, workspace.Ignore, collectionService:GetTagged("RaycastIgnore") }

	local raycastResult = workspace:Raycast(originPart.Position, direction, visibilityRaycastParams)
	return raycastResult ~= nil and raycastResult.Instance:IsDescendantOf(target.agent)
end

function targetingController:isTargetInFieldOfView(target: targetData, fieldOfView: number?): boolean
	if not fieldOfView then
		return true
	end

	local originPart = self.controller.headBone
	local targetPart = target.root

	local offset = targetPart.Position - originPart.WorldPosition
	local distanceToTarget = vector.magnitude(offset)

	if distanceToTarget <= 0.01 then
		return true
	end

	local directionToTarget = offset / distanceToTarget
	local lookVector = originPart.WorldCFrame.LookVector
	local dot = vector.dot(directionToTarget, lookVector)
	local fovCosThreshold = math.cos(math.rad(fieldOfView / 2))

	return dot >= fovCosThreshold
end

function targetingController:isTargetTurnedAway(target: targetData): boolean
	local originPart = self.rootPart
	local targetPart = target.root

	local directionToTarget = (targetPart.Position - originPart.Position).Unit
	local dotProduct = targetPart.CFrame.LookVector:Dot(directionToTarget)

	return dotProduct > 0.0
end

function targetingController:isTargetDead(target: targetData): boolean
	local humanoid = target.humanoid
	local agent = target.agent

	return not agent or not agent.Parent or humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid.Health <= 0
end

function targetingController:getPlayerFromTarget(target: targetData): Player?
	return players:GetPlayerFromCharacter(target.agent)
end

function targetingController:getTargetId(target: targetData): string
	local agent = target.agent
	local player = target.player

	local targetId = player and tostring(player.UserId) or agent:GetAttribute("TargetId")
	if not targetId then
		targetId = httpService:GenerateGUID()
		agent:SetAttribute("TargetId", targetId)
	end

	return tostring(targetId)
end

function targetingController:clearTargetCache()
	for _, cache in self.targetsFolder:GetChildren() do
		cache:Destroy()
		cache = nil
	end
end

function targetingController:updateTargetCache(target: targetData, action: string?): ObjectValue?
	local effectiveAction = action or "add"
	local targetId = self:getTargetId(target)
	local existingEntry = self.targetsFolder:FindFirstChild(targetId)

	if effectiveAction == "add" then
		if existingEntry then
			existingEntry:SetAttribute("LastSeen", os.clock())
			self.targetCacheLookup[targetId] = existingEntry
			return existingEntry
		end

		local newEntry = targetPrefab:Clone()
		newEntry.Name = targetId
		newEntry.Value = target.agent
		newEntry:SetAttribute("LastSeen", os.clock())
		newEntry.Parent = self.targetsFolder

		local playerValue = newEntry:FindFirstChild("Player")
		if playerValue then
			playerValue.Value = target.player
			if not target.player then
				playerValue:Destroy()
			end
		end

		self.targetCacheLookup[targetId] = newEntry
		return newEntry
	elseif effectiveAction == "subtract" then
		if existingEntry then
			existingEntry:Destroy()
		end

		self.targetCacheLookup[targetId] = nil
		return nil
	end

	return existingEntry
end

function targetingController:pruneStaleCache(
	target: targetData,
	cacheEntry: ObjectValue,
	staleThresholdSeconds: number?
)
	local threshold = staleThresholdSeconds or 1.5
	local lastSeen = cacheEntry:GetAttribute("LastSeen") or 0

	if os.clock() - lastSeen > threshold then
		self:updateTargetCache(target, "subtract")
	end
end

function targetingController:getAllTargetsInRange(info: nearestTargetInfo)
	local targetsInRange = {}

	local availableTargets = self:refreshAvailableTargets()
	local searchRange = info.range or 120

	for _, target in availableTargets do
		local rootPart = target.root
		local distanceToTarget = vector.magnitude(self.rootPart.Position - rootPart.Position)
		local canSee = not info.canRaycast or self:isTargetVisible(target)

		target.player = self:getPlayerFromTarget(target)
		target.distance = distanceToTarget

		if distanceToTarget <= searchRange and canSee then
			table.insert(targetsInRange, target)
		end
	end

	return targetsInRange
end

function targetingController:getAllTargetsOutsideRange(info: nearestTargetInfo)
	local targetsInRange = {}

	local availableTargets = self:refreshAvailableTargets()
	local searchRange = info.range or 120

	for _, target in availableTargets do
		local rootPart = target.root
		local distanceToTarget = vector.magnitude(self.rootPart.Position - rootPart.Position)

		target.player = self:getPlayerFromTarget(target)
		target.distance = distanceToTarget

		if distanceToTarget >= searchRange then
			table.insert(targetsInRange, target)
		end
	end

	return targetsInRange
end

function targetingController:getNearestTarget(info: nearestTargetInfo): targetData?
	local chosenTarget = nil
	local closestDistance = math.huge

	local chosenRagdolledTarget = nil
	local closestRagdolledDistance = math.huge

	local searchRange = info.range or 120
	local shouldOverride = if info.overrideCurrentTarget ~= nil then info.overrideCurrentTarget else true

	local fieldOfView = info.fieldOfView

	local availableTargets = self:refreshAvailableTargets()

	for _, target in availableTargets do
		local rootPart = target.root
		local distanceToTarget = vector.magnitude(rootPart.Position - self.rootPart.Position)

		target.player = self:getPlayerFromTarget(target)
		target.distance = distanceToTarget

		if distanceToTarget > searchRange then
			if info.useTargetCache then
				local cacheEntry = self:updateTargetCache(target, "check")
				if cacheEntry then
					self:pruneStaleCache(target, cacheEntry)
				end
			end

			continue
		end

		if not self:isTargetInFieldOfView(target, fieldOfView) then
			if info.useTargetCache then
				local cacheEntry = self:updateTargetCache(target, "check")
				if cacheEntry then
					self:pruneStaleCache(target, cacheEntry)
				end
			end

			continue
		end

		local canSee
		if info.useTargetCache then
			canSee = not info.canRaycast or self:isTargetVisible(target)
			local cacheEntry = self:updateTargetCache(target, "check")

			if canSee then
				if not cacheEntry then
					cacheEntry = self:updateTargetCache(target, "add")
				else
					cacheEntry:SetAttribute("LastSeen", os.clock())
				end
			elseif cacheEntry then
				self:pruneStaleCache(target, cacheEntry)
			end
		else
			canSee = not info.canRaycast or self:isTargetVisible(target)
		end

		if not canSee then
			continue
		end

		if target.isRagdolled then
			if distanceToTarget < closestRagdolledDistance then
				closestRagdolledDistance = distanceToTarget
				chosenRagdolledTarget = target
			end
		else
			if distanceToTarget < closestDistance then
				closestDistance = distanceToTarget
				chosenTarget = target
			end
		end
	end

	local finalTarget = chosenTarget or chosenRagdolledTarget

	if shouldOverride and getmetatable(self) and self.controller then
		self.controller.currentTarget = finalTarget
	end

	return finalTarget
end

function targetingController.new(controller)
	local self = setmetatable({}, targetingController)

	self.controller = controller
	self.agent = controller.agent
	self.rootPart = controller.rootPart
	self.targetsFolder = controller.targetsFolder

	local visibilityRaycastParams = RaycastParams.new()
	visibilityRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	visibilityRaycastParams.RespectCanCollide = true
	self.visibilityRaycastParams = visibilityRaycastParams

	self.targetCacheLookup = {}
	self.regionCacheLookup = {}

	self.cachedAvailableTargets = {}
	self.lastTargetRefreshTime = 0

	for _, regionFolder in regionsMap do
		if not regionFolder:IsA("Folder") then
			continue
		end

		self.regionCacheLookup[regionFolder.Name] = {}

		for _, regionPart in regionFolder:GetChildren() do
			if not regionPart:IsA("BasePart") or regionPart:GetAttribute("AmbienceType") == "Reveal" then
				continue
			end

			table.insert(self.regionCacheLookup[regionFolder.Name], regionPart)
		end
	end

	return self
end

function targetingController:destroy()
	table.clear(self.targetCacheLookup)
	table.clear(self.cachedAvailableTargets)
	self.controller = nil
end

return targetingController
