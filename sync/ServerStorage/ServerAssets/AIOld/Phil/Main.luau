local ServerStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local sharedUtilities = replicatedStorage.SharedUtilities
local bucketUtilities = require(sharedUtilities.BucketUtils)

local sharedAssets = replicatedStorage.SharedAssets
local regionsFolder = sharedAssets.Regions:GetChildren()

local PathParameters = require(ServerStorage.ServerAssets.Prefabs.PathParameters)
local animationUtilities = require(replicatedStorage.SharedUtilities.Animation)

local assets = serverStorage.ServerAssets
local aiFolder = aiFolder.StateMachine

local philAssets = aiFolder.Phil
local philComponents = philAssets.Components:GetChildren()
local philSounds = philAssets.Sounds
local philAnimations = require(philAssets.Animations)

local newPathfinding = require(aiFolder.NewPathfinding)
local stateMachine = require(aiFolder.StateMachine)
local targeting = require(aiFolder.Targeting)

local sharedConfig = require(philAssets.Config)
local combatConfig = require(philAssets.Config.Combat)

local philController = {}
philController.__index = philController

philController.__defaultTimers = {
	pathCompute = 0,
	lunge = 0,
	attack = 0,
	chase = 0,
	scream = 0,
	focusEntry = 0,
	flashstep = 0,
}

philController.__defaultFlags = {
	hasScreamedThisChase = false,
}

function philController:isActionReady(actionName: string, cooldownSeconds: number): boolean
	local lastTime = self.actionTimers[actionName] or 0
	return os.clock() - lastTime >= cooldownSeconds
end

function philController:recordActionTime(actionName: string)
	self.actionTimers[actionName] = os.clock()
end

function philController:getActionTime(actionName: string): number
	return self.actionTimers[actionName] or 0
end

function philController:getFlag(flagName: string): any
	return self.actionFlags[flagName]
end

function philController:setFlag(flagName: string, value: any)
	self.actionFlags[flagName] = value
end

--// State Management

function philController:setCanAttack(state: boolean)
	self.agent:SetAttribute("CanAttack", state)
end
function philController:setCanStun(state: boolean)
	self.agent:SetAttribute("CanStun", state)
end

function philController:canAttack(): boolean
	return self.agent:GetAttribute("CanAttack")
		and not self:isAttacking()
		and not self:isInactive()
		and self:isActionReady("attack", combatConfig.attackCooldownSeconds)
end

function philController:canSideAttack(): boolean
	return not self:isAttacking()
		and not self:isInactive()
		and self:isActionReady("backhandProp", combatConfig.backhandPropCooldownSeconds)
end

function philController:setMidAction(state: boolean)
	self.agent:SetAttribute("MidAction", state)
end

function philController:isMidAction(): boolean
	return self.agent:GetAttribute("MidAction") == true
end

function philController:isAttacking(): boolean
	return self.agent:GetAttribute("Attacking") == true
end

function philController:isInactive(): boolean
	return self.agent:GetAttribute("Stunned") == true
end

--// Orientation and Movement

function philController:turnToward(goalPosition: Vector3)
	local rootPart = self.rootPart
	local flatTarget = Vector3.new(goalPosition.X, rootPart.Position.Y, goalPosition.Z)

	self.rootAttachment.CFrame = CFrame.lookAt(rootPart.Position, flatTarget):Inverse()
end

function philController:toggleIKControl(state: boolean, target: BasePart)
	self.ikControl.Weight = state and 0.8 or 0

	if target then
		self.ikControl.Target = target
	end
end

function philController:setOrientationEnabled(isEnabled: boolean)
	self.alignOrientation.Enabled = isEnabled
	self.humanoid.AutoRotate = not isEnabled
end

function philController:isGoalInBuilding(goal: Vector3): string?
	for regionName, regionCache in self.regionCacheLookup do
		for _, regionPart in regionCache do
			if bucketUtilities.checkInRegion(regionPart, goal) then
				return regionName
			end
		end
	end

	return nil
end

function philController:hasLineOfSight(goalPosition: Vector3, extraExclude: { Instance }?): boolean
	local origin = self.rootPart.Position
	local delta = goalPosition - origin
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	local distance = vector.magnitude(flatDelta)

	if distance < 1e-3 then
		return true
	end

	local castDistance = math.max(distance - 3, 0)
	local excludeList = { self.agent }

	if castDistance <= 0 then
		return true
	end

	if extraExclude then
		for _, instance in extraExclude do
			table.insert(excludeList, instance)
		end
	end

	self.traversalRaycastParams.FilterDescendantsInstances = excludeList

	local castRadius = (self.pathParameters and self.pathParameters.AgentRadius or 2) + 1
	local castDirection = flatDelta.Unit * castDistance
	local result = workspace:Spherecast(origin, castRadius, castDirection, self.traversalRaycastParams)

	if not result then
		return true
	end

	return vector.magnitude(result.Position - origin) >= castDistance
end

function philController:stopTraversal()
	self.pathfinder:Stop()
	self.traversalMode = "direct"
	self.lastTraversalGoal = nil
	self.humanoid:MoveTo(self.rootPart.Position)
end

function philController:traverse(goal: Vector3 | BasePart | { root: BasePart }?)
	local goalPosition, shouldStop = self:getGoalPosition(goal)

	if shouldStop then
		self:stopTraversal()
		return
	end

	if goalPosition == nil then
		return
	end

	local now = os.clock()
	local goalChanged = self.lastTraversalGoal == nil or vector.magnitude(goalPosition - self.lastTraversalGoal) > 1.5

	if goalChanged or (now - self.lastLOSCheckTime) >= 0.25 then
		self.lastLOSCheckTime = now
		self.lastTraversalGoal = goalPosition

		if not self:hasLineOfSight(goalPosition) then
			self.lastObstructedTime = now
			self.traversalMode = "pathfinding"
		elseif (now - self.lastObstructedTime) >= 0.75 then
			self.traversalMode = "direct"
		end
	end

	if self.traversalMode == "pathfinding" then
		if self:isActionReady("pathCompute", sharedConfig.pathComputeIntervalSeconds) then
			self.pathfinder:Run(goalPosition)
			self:recordActionTime("pathCompute")
		end
	else
		self.humanoid:MoveTo(goalPosition)
	end
end

function philController:getGoalPosition(
	goal: Vector3 | BasePart | { root: BasePart, distance: number? }
): (Vector3?, boolean)
	if typeof(goal) == "Vector3" then
		return goal, false
	end

	if typeof(goal) == "Instance" and goal:IsA("BasePart") then
		return goal.Position, false
	end

	if typeof(goal) == "table" and goal.root then
		local targetPosition = goal.root.Position
		return targetPosition, false
	end

	return nil, false
end

--// Lunge Checks

function philController:canLunge(useMinimumRange: boolean?): boolean
	local shouldUseMinimumRange = if useMinimumRange ~= nil then useMinimumRange else true
	local ranges = sharedConfig.ranges
	local currentTarget = self.currentTarget

	local distanceToTarget = currentTarget and currentTarget.distance or math.huge

	if self:isMidAction() then
		return false
	end

	local minimumRange = shouldUseMinimumRange and ranges.lungeMinimum or 0
	return distanceToTarget >= minimumRange and distanceToTarget <= ranges.lungeMaximum
end

--// Animation Helpers

function philController:cancelTracksInDictionary(dictionary: { [string]: AnimationTrack })
	for _, track in dictionary do
		track:Stop()
	end
end

--// Eye Appearance

function philController:getEyeAttachments(): { Attachment }
	local attachments = {}

	for _, eyeValue in self.eyeValues do
		local eye = eyeValue.Value
		for _, attachment in eye:GetChildren() do
			if attachment:IsA("Attachment") then
				table.insert(attachments, attachment)
			end
		end
	end

	return attachments
end

function philController:setEyeState(stage: boolean | string)
	local isNormal = stage == true
	local isEnraged = stage == "enraged"

	for _, attachment in self:getEyeAttachments() do
		for _, instance in attachment:GetChildren() do
			if instance.Enabled == nil then
				continue
			end

			instance.Enabled = (instance:IsA("ParticleEmitter") and isNormal) or (instance:IsA("Light") and isEnraged)
		end
	end

	self.nightmareEyes.Transparency = isEnraged and 0 or 1
end

--// Lifecycle

function philController:preload()
	local statesFolder = philAssets.States
	local loadedStates = {}

	for _, stateModule in statesFolder:GetChildren() do
		if stateModule:IsA("ModuleScript") then
			loadedStates[stateModule.Name] = require(stateModule)
		end
	end

	for _, component in philComponents do
		component:Clone().Parent = self.agent
	end

	for actionName, animationList in philAnimations.actions do
		if not self.tracks[actionName] then
			self.tracks[actionName] = {}
		end

		for index, animationId in animationList do
			if typeof(animationId) == "table" then
				continue
			end

			self.tracks[actionName][index] = animationUtilities.loadAnimationById(self.animator, animationId, true)
		end
	end

	self.config.wandering = require(philAssets.Config.States.Wandering)
	self.config.focusing = require(philAssets.Config.States.Focusing)
	self.config.lunging = require(philAssets.Config.States.Lunging)
	self.config.searching = require(philAssets.Config.States.Searching)
	self.config.standingOff = require(philAssets.Config.States.StandingOff)
	self.config.transporting = require(philAssets.Config.States.Transporting)
	self.config.spitting = require(philAssets.Config.States.Spitting)

	self.pathfinder = newPathfinding.Humanoid(self.agent, self.pathParameters)
	self.speedController = require(script.SpeedController).new(self)
	self.moveSetAnimator = require(script.Animator).new(self)
	self.attacker = require(script.Attacker).new(self)
	self.health = require(script.Health).new(self)

	self.states = loadedStates
	self.stateMachine = stateMachine.new(self)
	self.targeting = targeting.new(self)
end

function philController:init()
	self:preload()

	self.stateMachine:change(self.states.Transporting)

	task.spawn(function()
		while true do
			local deltaTime = task.wait(1 / 20)

			if not getmetatable(self) or not self.isAlive then
				break
			end

			local success, errorMessage = pcall(function()
				self.pathfinder.Speed = self.humanoid.WalkSpeed
				self.stateMachine:update(deltaTime)
				self.speedController:update(deltaTime)
				self.health:update(deltaTime)
				self.moveSetAnimator:update()
			end)

			if not success then
				warn("[AI] Phil heartbeat error:", errorMessage)
			end
		end
	end)
end

function philController.new(info: { agent: Model, pathParameters: any? })
	local self = setmetatable({}, philController)

	local agent = info.agent
	local humanoid = agent:FindFirstChildOfClass("Humanoid") or agent:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
	local rootPart = agent.PrimaryPart or agent:WaitForChild("HumanoidRootPart")

	self.agent = agent
	self.humanoid = humanoid
	self.animator = animator
	self.rootPart = rootPart
	self.isAlive = true

	self.ikControl = self.humanoid:FindFirstChild("IKControl")
	self.ikControl.EndEffectorOffset = self.ikControl.EndEffectorOffset * CFrame.new(0, 2, 0)

	self.eyeValues = rootPart.Eyes:GetChildren()
	self.rootAttachment = rootPart.RootAttachment
	self.alignOrientation = rootPart:FindFirstChildOfClass("AlignOrientation")
	self.headBone = rootPart.HeadBone.Value

	self.meshParts = agent.Mesh
	self.nightmareEyes = self.meshParts.NightmareEyes_Mesh

	self.sounds = philSounds
	self.currentTarget = nil
	self.targetsFolder = agent.Targets

	self.actionTimers = table.clone(philController.__defaultTimers)
	self.actionFlags = table.clone(philController.__defaultFlags)
	self.randomGenerator = Random.new()

	self.traversalRaycastParams = RaycastParams.new()
	self.traversalRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.traversalRaycastParams.FilterDescendantsInstances = { agent }
	self.traversalRaycastParams.IgnoreWater = true

	self.traversalMode = "direct" :: "direct" | "pathfinding"
	self.lastLOSCheckTime = 0
	self.lastObstructedTime = -math.huge
	self.lastTraversalGoal = nil

	self.pathParameters = PathParameters
	self.config = {
		shared = sharedConfig,
		combat = combatConfig,
	}

	self.tracks = {
		moveSet = {
			idle = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.idle, true),

			walk = {
				forward = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.walk.forward, true),
				back = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.walk.backward, true),
				left = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.walk.left, true),
				right = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.walk.right, true),
			},

			run = {
				forward = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.run.forward, true),
				back = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.run.backward, true),
				left = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.run.left, true),
				right = animationUtilities.loadAnimationById(animator, philAnimations.moveSet.run.right, true),

				nearTargetForward = animationUtilities.loadAnimationById(
					animator,
					philAnimations.moveSet.run.nearTargetForward,
					true
				),
			},
		},

		standOff = {
			poses = {
				[1] = animationUtilities.loadAnimationById(animator, philAnimations.actions.standOff.poses[1], true),
				[2] = animationUtilities.loadAnimationById(animator, philAnimations.actions.standOff.poses[2], true),
				[3] = animationUtilities.loadAnimationById(animator, philAnimations.actions.standOff.poses[3], true),
			},
		},
	}

	self.regionCacheLookup = {}

	for _, regionFolder in regionsFolder do
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

	task.defer(self.init, self)

	return self
end

function philController:stopAllTracks()
	local function stopTrack(value: any)
		if typeof(value) == "Instance" and (value :: any).Stop then
			(value :: AnimationTrack):Stop()
		end
	end

	for _, trackOrGroup in self.tracks do
		stopTrack(trackOrGroup)

		if typeof(trackOrGroup) == "table" then
			for _, track in trackOrGroup do
				stopTrack(track)

				if typeof(track) == "table" then
					for _, subTrack in track do
						stopTrack(subTrack)
					end
				end
			end
		end
	end
end

function philController:destroy()
	self.isAlive = false

	if self.stateMachine then
		self.stateMachine:destroy()
	end

	self:stopAllTracks()

	if self.speedController then
		self.speedController:clearAll()
	end

	if self.attacker then
		self.attacker:destroy()
	end

	if self.pathfinder then
		self.pathfinder:Destroy()
	end

	if self.health then
		self.health:destroy()
	end

	if self.targeting then
		self.targeting:destroy()
	end

	self.agent:Destroy()

	setmetatable(self, nil)
end

return philController
