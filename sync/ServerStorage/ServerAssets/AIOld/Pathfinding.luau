--[[
-------------------------------------------------------------------

Created by: @V3N0M_Z
Reference: https://v3n0m-z.github.io/RBLX-SimplePath/
License: MIT

---------------------------------------------------------------------
]]

--[[

Modified by BawakFurry to fix vital issues.

Note: Commented out non-humanoid agent handlers to slightly improve on performance		<------ READ

]]

--// Third-party module (SimplePath by @V3N0M_Z, modified by BawakFurry).

local DEFAULT_SETTINGS = {

	COMPARISON_DELTA = 0.25,

	TIME_VARIANCE = 0.07,

	COMPARISON_CHECKS = 3,

	JUMP_WHEN_STUCK = true,
}

local DEBUG = true

---------------------------------------------------------------------

local PathfindingService = game:GetService("PathfindingService")
local tags = game:GetService("CollectionService")

local function output(func, msg)
	func(((func == error and "SimplePath Error: ") or "SimplePath: ") .. msg)
end
local Path = {
	StatusType = {
		Idle = "Idle",
		Active = "Active",
	},
	ErrorType = {
		LimitReached = "LimitReached",
		TargetUnreachable = "TargetUnreachable",
		ComputationError = "ComputationError",
		AgentStuck = "AgentStuck",
		AlreadyCalculating = "AlreadyCalculating",
		ForceDestroy = "ForceDestroy",
	},
}
Path.DebugPrints = DEBUG
Path.alive_paths = 0

Path.__index = function(table, index)
	if index == "Stopped" and not table._humanoid then
		output(error, "Attempt to use Path.Stopped on a non-humanoid.")
	end
	return (table._events[index] and table._events[index].Event)
		or (index == "LastError" and table._lastError)
		or (index == "Status" and table._status)
		or Path[index]
end

--Used to visualize waypoints
local visualWaypoint = Instance.new("Part")
visualWaypoint.Size = Vector3.new(0.3, 0.3, 0.3)
visualWaypoint.Anchored = true
visualWaypoint.CanCollide = false
visualWaypoint.CastShadow = false
visualWaypoint.CanQuery = false
visualWaypoint.CanTouch = false
visualWaypoint.Material = Enum.Material.Neon
visualWaypoint.Shape = Enum.PartType.Block

--[[ PRIVATE FUNCTIONS ]]
--
local function declareError(self, errorType)
	self._lastError = errorType
	self._events.Error:Fire(errorType)
end

--Create visual waypoints
local function createVisualWaypoints(waypoints)
	local visualWaypoints = {}
	for _, waypoint in ipairs(waypoints) do
		local visualWaypointClone = visualWaypoint:Clone()
		visualWaypointClone.Position = waypoint.Position
		visualWaypointClone.Parent = workspace
		visualWaypointClone.Color = (waypoint == waypoints[#waypoints] and Color3.fromRGB(0, 255, 0))
			or (waypoint.Action == Enum.PathWaypointAction.Jump and Color3.fromRGB(255, 0, 0))
			or Color3.fromRGB(255, 139, 0)
		table.insert(visualWaypoints, visualWaypointClone)
	end
	return visualWaypoints
end

--Destroy visual waypoints
local function destroyVisualWaypoints(waypoints)
	if waypoints then
		for _, waypoint in ipairs(waypoints) do
			waypoint:Destroy()
		end
	end
	return
end

--Make NPC jump
local function setJumpState(self)
	if
		self._humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
		and self._humanoid:GetState() ~= Enum.HumanoidStateType.Freefall
	then
		self._humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

--Primary move function
local function move(self)
	if self._waypoints[self._currentWaypoint].Action == Enum.PathWaypointAction.Jump then
		setJumpState(self)
	end
	self._humanoid:MoveTo(self._waypoints[self._currentWaypoint].Position)
end

--Disconnect MoveToFinished connection when pathfinding ends
local function disconnectMoveConnection(self)
	if self._moveConnection then
		self._moveConnection:Disconnect()
		self._moveConnection = nil
	end
end

--Fire the WaypointReached event
local function invokeWaypointReached(self)
	local lastWaypoint = self._waypoints[self._currentWaypoint - 1]
	local nextWaypoint = self._waypoints[self._currentWaypoint]
	self._events.WaypointReached:Fire(self._agent, lastWaypoint, nextWaypoint)
end

local function moveToFinished(self, reached)
	--Stop execution if Path is destroyed
	if not getmetatable(self) then
		return
	end
	if not self._agent or not self._humanoid then
		return
	end

	if reached and self._currentWaypoint + 1 <= #self._waypoints then --Waypoint reached
		if self._currentWaypoint + 1 < #self._waypoints then
			invokeWaypointReached(self)
		end
		self._currentWaypoint += 1
		move(self)
	elseif reached then --Target reached, pathfinding ends
		disconnectMoveConnection(self)
		self._status = Path.StatusType.Idle
		self._visualWaypoints = destroyVisualWaypoints(self._visualWaypoints)
		self._events.Reached:Fire(self._agent, self._waypoints[self._currentWaypoint])
	else --Target unreachable
		disconnectMoveConnection(self)
		self._status = Path.StatusType.Idle
		self._visualWaypoints = destroyVisualWaypoints(self._visualWaypoints)
		declareError(self, self.ErrorType.TargetUnreachable)
	end
end

--Refer to Settings.COMPARISON_CHECKS
local function comparePosition(self)
	if self._currentWaypoint and self._waypoints and self._currentWaypoint >= #self._waypoints then
		return
	end

	self._position._count = (
		vector.magnitude(self._agent:GetPivot().Position - self._position._last) <= 0.25
		and (self._position._count + 1)
	) or 0
	self._position._last = self._agent:GetPivot().Position

	if self._position._count >= self._settings.COMPARISON_CHECKS then
		declareError(self, self.ErrorType.AgentStuck)

		if self._settings.JUMP_WHEN_STUCK then
			if math.random(1, 2) == 1 then
				self:Stop()
				self._humanoid:MoveTo((self._agent.PrimaryPart.CFrame * CFrame.new(0, 0, 10)).Position)

				return true
			else
				setJumpState(self)
			end
		end
	end

	return
end

--[[ CONSTRUCTOR ]]
--
function Path.new(agent, agentParameters, override)
	if not (agent and agent:IsA("Model") and agent.PrimaryPart) then
		output(error, "Pathfinding agent must be a valid Model Instance with a set PrimaryPart.")
	end

	if agentParameters["WaypointSpacing"] == nil then
		agentParameters["WaypointSpacing"] = 2
	end

	local self = setmetatable({
		_settings = override or DEFAULT_SETTINGS,
		_events = {
			Reached = Instance.new("BindableEvent"),
			WaypointReached = Instance.new("BindableEvent"),
			Blocked = Instance.new("BindableEvent"),
			Error = Instance.new("BindableEvent"),
			Stopped = Instance.new("BindableEvent"),
		},
		_agent = agent,
		_humanoid = agent:FindFirstChildOfClass("Humanoid"),
		_path = PathfindingService:CreatePath(agentParameters),
		_status = "Idle",
		_t = 0,
		_position = {
			_last = Vector3.new(),
			_count = 0,
		},
		_last_task = 0,
	}, Path)

	--Configure settings
	for setting, value in pairs(DEFAULT_SETTINGS) do
		self._settings[setting] = self._settings[setting] == nil and value or self._settings[setting]
	end

	--Path blocked connection
	self._blockedConnection = self._path.Blocked:Connect(function(...)
		if self._currentWaypoint then
			if (self._currentWaypoint <= ... and self._currentWaypoint + 1 >= ...) and self._humanoid then
				setJumpState(self)
				self._events.Blocked:Fire(self._agent, self._waypoints[...])
			end
		end
	end)

	--Set network owner to server to prevent "hops"
	if self._agent.PrimaryPart and self._agent.PrimaryPart.Anchored == false then
		pcall(self._agent.PrimaryPart.SetNetworkOwner, self._agent.PrimaryPart, nil)
	end

	Path.alive_paths += 1

	return self
end

--[[ NON-STATIC METHODS ]]
--
function Path:Destroy()
	self._destroying = true

	Path.alive_paths -= 1
	if self._blockedConnection then
		self._blockedConnection:Disconnect()
		self._blockedConnection = nil
	end
	if self._events then
		for _, event in pairs(self._events) do
			event:Destroy()
		end
	end

	if rawget(self, "_visualWaypoints") then
		self._visualWaypoints = destroyVisualWaypoints(self._visualWaypoints)
	end

	if self._path then
		self._path:Destroy()
	end

	setmetatable(self, nil)
	for k, _ in pairs(self) do
		self[k] = nil
	end
end

function Path:Stop()
	--[[if not self._humanoid then
		output(error, "Attempt to call Path:Stop() on a non-humanoid.")
		
		return
	end]]

	if self._status == Path.StatusType.Idle then
		return
	end

	if self._task then
		pcall(function()
			task.cancel(self._task)
		end)
	end

	disconnectMoveConnection(self)
	self._status = Path.StatusType.Idle
	self._visualWaypoints = destroyVisualWaypoints(self._visualWaypoints)

	if self._events and self._events.Stopped then
		self._events.Stopped:Fire(self._agent)
	end

	self._task = nil
end

function Path:Run(target)
	if self._destroying then
		return
	end

	if self._task ~= nil then
		local now = os.clock()

		if now - self._last_task <= 2 then
			declareError(self, self.ErrorType.AlreadyCalculating)
			return
		else
			self._task = nil
			self._last_task = now
		end
	end

	-- Run
	self._task = task.spawn(function()
		local success, message = pcall(function()
			self._last_task = os.clock()

			if not self._humanoid or not self._agent or (self._agent and not self._agent.PrimaryPart) then
				declareError(self, self.ErrorType.ForceDestroy)
				return
			end

			if not self._agent:IsDescendantOf(game.Workspace) then
				declareError(self, self.ErrorType.ForceDestroy)
				return
			end

			if tags:HasTag(self._agent, "Disabled") then
				--it's natural for units to have been disabled
				--self._task = nil
				return
			end

			--Parameter check
			if not (target and (typeof(target) == "Vector3" or target:IsA("BasePart"))) then
				output(error, "Pathfinding target must be a valid Vector3 or BasePart.")

				--self._task = nil
				return
			end

			--Refer to Settings.TIME_VARIANCE
			if os.clock() - self._t <= self._settings.TIME_VARIANCE and self._humanoid then
				declareError(self, self.ErrorType.LimitReached)

				--self._task = nil
				return
			elseif self._humanoid then
				self._t = os.clock()
			end

			-- Do comparison check before computing path
			if comparePosition(self) then
				return
			end

			--Compute path
			local pathComputed, errorMessage = pcall(function()
				self._path:ComputeAsync(
					self._agent:GetPivot().Position,
					(typeof(target) == "Vector3" and target) or target.Position
				)
			end)

			--Make sure path computation is successful
			if
				not pathComputed or (self._path and self._path.Status == Enum.PathStatus.NoPath)
				--or (self._path and #self._path:GetWaypoints() < 2) then
				--or (self._humanoid and self._humanoid.FloorMaterial == Enum.Material.Air)
			then
				if DEBUG then
					warn(errorMessage, self._path.Status)
				end

				self._visualWaypoints = destroyVisualWaypoints(self._visualWaypoints)
				declareError(self, self.ErrorType.ComputationError)

				--self._task = nil
				return
			end

			--Set status to active; pathfinding starts
			self._status = (self._humanoid and Path.StatusType.Active) or Path.StatusType.Idle
			self._target = target

			--Initialize waypoints
			local success2, _message = pcall(function()
				self._waypoints = self._path:GetWaypoints()
			end)

			if not success2 or not self._waypoints then
				if self._agent == nil then
					declareError(self, self.ErrorType.ForceDestroy)
				end

				return
			end

			local closest, distance = 3, math.huge -- 3 is default
			local totalWaypoints = #self._waypoints

			local _agentOrientation, agentSize = self._agent:GetBoundingBox()
			local agentPos = self._agent:GetPivot().Position + Vector3.new(0, -agentSize.Y / 2, 0)

			for i, v in ipairs(self._waypoints) do
				if not self._agent or not v then
					break
				end

				local waypointPos = v.Position
				local distFromMe = vector.magnitude(agentPos - waypointPos)

				if distFromMe < distance then
					distance = distFromMe
					closest = i
				end
			end

			closest += 1

			if closest > totalWaypoints then
				closest = totalWaypoints
			end

			self._currentWaypoint = closest
			self._modifierId = (self._waypoints and self._waypoints[self._currentWaypoint])
				and self._waypoints[self._currentWaypoint].Label

			-- Visualize waypoints (commented out for performance)
			destroyVisualWaypoints(self._visualWaypoints)
			self._visualWaypoints = DEBUG and createVisualWaypoints(self._waypoints)

			-- Create a new move connection if it doesn't exist already
			self._moveConnection = self._humanoid
				and (
					self._moveConnection
					or self._humanoid.MoveToFinished:Connect(function(reached)
						moveToFinished(self, reached)
					end)
				)

			-- Begin pathfinding
			if self._humanoid then
				self._humanoid:MoveTo(self._waypoints[self._currentWaypoint].Position)
			end
		end)

		self._task = nil

		if not success then
			error(message)
		end
	end)
end

function Path:GetCurrentWaypointPosition(): Vector3?
	local waypoints = self._waypoints
	local currentWaypoint = self._currentWaypoint

	if not waypoints or not currentWaypoint or not waypoints[currentWaypoint] then
		return nil
	end

	return waypoints[currentWaypoint].Position
end

function Path:GetCurrentWaypointIndex(): number?
	return self._currentWaypoint
end

function Path:GetNextWaypointPosition(): Vector3?
	local waypoints = self._waypoints
	local currentWaypoint = self._currentWaypoint
	local nextWaypoint = currentWaypoint and (currentWaypoint + 1) or nil

	if not waypoints or not nextWaypoint or not waypoints[nextWaypoint] then
		return nil
	end

	return waypoints[nextWaypoint].Position
end

function Path:GetTargetPosition(): Vector3?
	local target = self._target

	if not target then
		return nil
	end

	return if typeof(target) == "Vector3" then target else target.Position
end

function Path:GetWaypoints(): { PathWaypoint }?
	return self._waypoints
end

return Path
