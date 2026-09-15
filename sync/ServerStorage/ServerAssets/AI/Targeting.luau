local ignore = workspace.Ignore

local targetingController = {}
targetingController.__index = targetingController

export type nearestTargetInfo = {
	range: number?,
	canRaycast: boolean?,
	overrideCurrentTarget: boolean?,
	useTargetCache: boolean?,
	fieldOfView: number?,
	ignoreRagdolled: boolean?,
}

export type targetData = {
	agent: Model,
	root: BasePart,
	humanoid: Humanoid,
	player: Player?,
	distance: number?,
	isRagdolled: boolean?,
}

function targetingController:isTargetDead(target: targetData): boolean
	local humanoid = target.humanoid
	local agent = target.agent

	return not agent or not agent.Parent or humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid.Health <= 0
end

function targetingController:getNearestTarget(info: nearestTargetInfo): targetData?
	info = info or {}

	local chosenTarget = nil
	local closestDistance = math.huge

	local chosenRagdolledTarget = nil
	local closestRagdolledDistance = math.huge

	local searchRange = info.range or 10000
	local shouldOverride = if info.overrideCurrentTarget ~= nil then info.overrideCurrentTarget else true
	local fieldOfView = info.fieldOfView
	local useTargetCache = info.useTargetCache
	local canRaycast = info.canRaycast
	local availableTargets = self.registry.refreshAvailableTargets(self)

	if canRaycast then
		self.raycastParams.FilterDescendantsInstances = { self.agent, ignore }
	end

	for _, target in availableTargets do
		if target.isRagdolled and info.ignoreRagdolled then
			continue
		end

		target.distance = vector.magnitude(target.root.Position - self.rootPart.Position)

		if target.distance > searchRange then
			if useTargetCache then
				self.registry.recordMiss(self, target)
			end

			continue
		end

		if not self.perception.isTargetInFieldOfView(self, target, fieldOfView) then
			if useTargetCache then
				self.registry.recordMiss(self, target)
			end

			continue
		end

		local canSee = not canRaycast or self.perception.isTargetVisible(self, target)

		if useTargetCache then
			local cacheEntry = self.registry.updateTargetCache(self, target, "check")

			if canSee then
				if cacheEntry then
					cacheEntry:SetAttribute("LastSeen", os.clock())
				else
					cacheEntry = self.registry.updateTargetCache(self, target, "add")
				end
			elseif cacheEntry then
				self.registry.pruneStaleCache(cacheEntry)
			end

			if cacheEntry then
				cacheEntry:SetAttribute("Distance", target.distance)
			end
		end

		if not canSee then
			continue
		end

		if target.isRagdolled then
			if target.distance < closestRagdolledDistance then
				closestRagdolledDistance = target.distance
				chosenRagdolledTarget = target
			end
		else
			if target.distance < closestDistance then
				closestDistance = target.distance
				chosenTarget = target
			end
		end
	end

	local finalTarget = chosenTarget or chosenRagdolledTarget

	if shouldOverride and getmetatable(self) and self.ai then
		self.ai.currentTarget = finalTarget
	end

	return finalTarget
end

function targetingController.new(ai)
	local self = setmetatable({}, targetingController)

	self.ai = ai
	self.agent = self.ai.agent
	self.rootPart = self.ai.rootPart
	self.behavior = self.ai.behaviorCache
	self.targetsFolder = self.ai.targetsFolder

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.RespectCanCollide = true
	self.raycastParams = raycastParams

	self.perception = require(script.Perception)
	self.registry = require(script.Registry)

	return self
end

return targetingController
