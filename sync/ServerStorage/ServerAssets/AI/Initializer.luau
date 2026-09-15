local serverStorage = game:GetService("ServerStorage")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local regionsFolder = sharedAssets.Regions:GetChildren()

local sharedUtilities = replicatedStorage.SharedUtilities
local animationUtilities = require(sharedUtilities.Animation)
local bucketUtilities = require(sharedUtilities.BucketUtils)

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI

local behaviors = aiAssets.Behaviors
local stateMachineController = require(aiAssets.StateMachine)
local targetingController = require(aiAssets.Targeting)
local pathfindingController = require(aiAssets.Pathfinding)
local speedController = require(aiAssets.Speed)

local aiController = {}
aiController.__index = aiController
aiController.cachedRegions = {}
aiController.defaultPathParameters = {
	AgentHeight = 3,
	AgentRadius = 1.2,
	AgentCanJump = false,
}

export type AI = {
	agent: Model,
	behaviorType: string,

	agentParameters: {
		AgentHeight: number,
		AgentRadius: number,
		WaypointSpacing: number,
		AgentCanJump: boolean,
		Costs: { number },
	},
}

function aiController:preload()
	local newBehavior = behaviors:FindFirstChild(self.behaviorType)
	local availableStates = newBehavior and newBehavior.States
	local availableActions = newBehavior and newBehavior.Actions
	local availableUtils = newBehavior and newBehavior.Utils

	if not newBehavior or not availableStates then
		return
	end

	for _, state in availableStates:GetChildren() do
		if not state:IsA("ModuleScript") then
			continue
		end

		self.cachedStates[state.Name] = require(state)
	end

	for _, util in availableUtils:GetChildren() do
		if not util:IsA("ModuleScript") then
			continue
		end

		self.cachedUtils[util.Name] = require(util)
	end

	if availableActions then
		for _, action in availableActions:GetChildren() do
			if not action:IsA("ModuleScript") then
				continue
			end

			self.cachedActions[action.Name] = require(action)
		end
	end

	if not aiController.cachedRegions then
		for _, regionFolder in regionsFolder do
			if not regionFolder:IsA("Folder") then
				continue
			end

			aiController.cachedRegions[regionFolder.Name] = {}

			for _, regionPart in regionFolder:GetChildren() do
				if not regionPart:IsA("BasePart") or regionPart:GetAttribute("AmbienceType") == "Reveal" then
					continue
				end

				table.insert(aiController.cachedRegions[regionFolder.Name], regionPart)
			end
		end
	end

	self.targetsFolder = Instance.new("Folder")
	self.targetsFolder.Name = "Targets"
	self.targetsFolder.Parent = self.agent

	self.config = require(newBehavior.Configuration)
	self.sharedConfig = self.config.shared
	self.walkSpeedConfig = self.sharedConfig.walkSpeeds
	self.rangeConfig = self.sharedConfig.ranges
	self.cooldownConfig = self.sharedConfig.cooldowns
	self.cachedTracks = animationUtilities.sortRecursively(self.trueAnimator, self.config.animations)

	self.cachedBehavior = require(newBehavior).new(self)
	self.animator = require(newBehavior.Animator).new(self)
	self.sounds = newBehavior:FindFirstChild("Sounds")

	self.stateMachine = stateMachineController.new(self)
	self.pathfinder = pathfindingController.Humanoid(self.agent, self.agentParameters)
	self.speed = speedController.new(self)

	self.targeting = targetingController.new(self)
	self.perception = self.targeting.perception

	self.startingState = self.cachedBehavior.startingState
end

function aiController:setAnimatorEnabled(state: boolean)
	self.animator:setEnabled(state)
end

function aiController:isActionReady(actionName: string, cooldownSeconds: number): boolean
	return os.clock() - self:getActionTime(actionName) >= cooldownSeconds
end

function aiController:recordActionTime(actionName: string)
	self.actionTimers[actionName] = os.clock()
end

function aiController:getActionTime(actionName: string): number
	return self.actionTimers[actionName] or 0
end

function aiController:getActionFlag(flagName: string): any
	return self.actionFlags[flagName]
end

function aiController:recordActionFlag(flagName: string, value: any)
	self.actionFlags[flagName] = value
end

function aiController:setState(stateName: string)
	self.stateMachine:change(self.cachedStates[stateName])
end

function aiController:getActionJanitor(actionName: string)
	local janitor = self.actionJanitors[actionName]
	local connections = {}

	if janitor then
		return janitor
	end

	janitor = {
		add = function(connection: RBXScriptConnection): RBXScriptConnection
			table.insert(connections, connection)
			return connection
		end,

		clear = function()
			for _, connection in connections do
				connection:Disconnect()
			end

			table.clear(connections)
		end,
	}

	self.actionJanitors[actionName] = janitor

	return janitor
end

function aiController:runAction(actionName: string, extraInfo: { any }?)
	local action = self.cachedActions[actionName]
	extraInfo = extraInfo or {}

	if not action then
		return
	end

	if action.canRun and not action.canRun(self, extraInfo) then
		return
	end

	action.run(self, extraInfo)
end

function aiController:isGoalInBuilding(goal: Vector3): string?
	for regionName, regionCache in aiController.cachedRegions do
		for _, regionPart in regionCache do
			if bucketUtilities.checkInRegion(regionPart, goal) then
				return regionName
			end
		end
	end

	return nil
end

function aiController:cancelTraverse()
	self.pathfinder:Stop()
	self.humanoid:MoveTo(self.rootPart.Position)
end

function aiController:traverseTo(goal: Vector3)
	self.pathfinder:Run(goal)
end

function aiController:init()
	self:preload()

	if self.startingState then
		self:setState(self.startingState)
	else
		self:destroy()
		return
	end

	for utilIndex, util in self.cachedUtils do
		self.cachedUtils[utilIndex] = util.new(self)
	end

	self.connections.heartbeat = runService.Heartbeat:Connect(function(deltaTime: number)
		self.stateMachine:update(deltaTime)
		self.speed:update(deltaTime)

		if self.cachedBehavior.update then
			self.cachedBehavior:update(deltaTime)
		end

		for _, util in self.cachedUtils do
			if not getmetatable(util) then
				continue
			end

			if util.update then
				util:update(deltaTime)
			end
		end

		self.animator:update()
	end)
end

function aiController.new(startInfo: AI)
	local self = setmetatable({}, aiController)

	self.agent = startInfo.agent
	self.humanoid = self.agent:FindFirstChildOfClass("Humanoid")
	self.trueAnimator = self.humanoid:FindFirstChildOfClass("Animator")
	self.rootPart = self.humanoid.RootPart

	self.behaviorType = startInfo.behaviorType
	self.agentParameters = startInfo.agentParameters or self.defaultPathParameters

	self.cachedStates = {}
	self.cachedActions = {}
	self.cachedTracks = {}
	self.cachedUtils = {}

	self.actionFlags = {}
	self.actionTimers = {}

	self.actionJanitors = {}
	self.connections = {}

	task.spawn(self.init, self)

	return self
end

function aiController:destroy()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	for _, action in self.cachedActions do
		if action.destroy then
			action.destroy(self)
		end
	end

	for _, util in self.cachedUtils do
		if util.destroy then
			util:destroy()
		end
	end

	for _, janitor in self.actionJanitors do
		janitor.clear()
	end

	if self.cachedBehavior then
		self.cachedBehavior:destroy()
	end

	if self.stateMachine then
		self.stateMachine:destroy()
	end

	if self.animator then
		self.animator:destroy()
	end

	if self.targeting then
		self.targeting:destroy()
	end

	if self.speed then
		self.speed:destroy()
	end

	if self.pathfinder then
		self.pathfinder:Destroy()
	end

	setmetatable(self, nil)
end

return aiController
