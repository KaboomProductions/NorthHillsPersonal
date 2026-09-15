local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local spring = require(replicatedStorage.SharedClasses.Spring)

local pivotDoor = {}

local settledAngleThreshold = math.rad(0.15)
local settledVelocityThreshold = 0.01

type pivotDoorState = {
	doorSpring: any?,
	doorModel: Model?,
	pivotDriver: CFrameValue?,
	closedPivot: CFrame?,
	targetPivot: CFrame?,
	connections: { [string]: RBXScriptConnection? },
}

export type springSettings = {
	mass: number,
	force: number,
	damping: number,
	speed: number,
}

local function disconnectConnection(connections: { [string]: RBXScriptConnection? }, connectionKey: string)
	local connection = connections[connectionKey]
	if connection then
		connection:Disconnect()
		connections[connectionKey] = nil
	end
end

local function applyPivot(door: Model, pivotDriver: CFrameValue, pivot: CFrame)
	pivotDriver.Value = pivot
	door:PivotTo(pivot)
end

local function getRelativeYaw(basePivot: CFrame, targetPivot: CFrame): number
	local relativePivot = basePivot:ToObjectSpace(targetPivot)
	local _, yaw, _ = relativePivot:ToOrientation()
	return yaw
end

function pivotDoor.createPivotDriver(door: Model): CFrameValue
	local pivotDriverValue = Instance.new("CFrameValue")
	pivotDriverValue.Name = "PivotDriver"
	pivotDriverValue.Value = door:GetPivot()
	pivotDriverValue.Parent = door
	return pivotDriverValue
end

function pivotDoor.stopSpring(state: pivotDoorState)
	state.doorSpring = nil
	state.doorModel = nil
	state.pivotDriver = nil
	state.closedPivot = nil
	state.targetPivot = nil
	disconnectConnection(state.connections, "doorSpringStep")
end

local function ensureSpringConnection(state: pivotDoorState)
	if state.connections.doorSpringStep then
		return
	end

	state.connections.doorSpringStep = runService.Heartbeat:Connect(function(deltaTime)
		local activeSpring = state.doorSpring
		local door = state.doorModel
		local pivotDriver = state.pivotDriver
		local closedPivot = state.closedPivot
		local targetPivot = state.targetPivot
		if not activeSpring or not door or not pivotDriver or not closedPivot or not targetPivot then
			return
		end

		local currentYawPosition = activeSpring:update(deltaTime).X
		local nextPivot = closedPivot * CFrame.Angles(0, currentYawPosition, 0)
		applyPivot(door, pivotDriver, nextPivot)

		local targetYaw = getRelativeYaw(closedPivot, targetPivot)
		local isSettled = math.abs(activeSpring.target.X - currentYawPosition) <= settledAngleThreshold
			and math.abs(activeSpring.velocity.X) <= settledVelocityThreshold
		if not isSettled then
			return
		end

		activeSpring.position = Vector2.new(targetYaw, 0)
		activeSpring.velocity = Vector2.zero
		applyPivot(door, pivotDriver, targetPivot)
	end)
end

function pivotDoor.springPivot(
	state: pivotDoorState,
	door: Model,
	pivotDriver: CFrameValue,
	closedPivot: CFrame,
	targetPivot: CFrame,
	springSettings: springSettings,
	initialImpulse: Vector2?
)
	local currentPivot = pivotDriver.Value
	local currentYaw = getRelativeYaw(closedPivot, currentPivot)
	local targetYaw = getRelativeYaw(closedPivot, targetPivot)

	state.doorModel = door
	state.pivotDriver = pivotDriver
	state.closedPivot = closedPivot
	state.targetPivot = targetPivot

	if math.abs(targetYaw - currentYaw) <= settledAngleThreshold then
		local doorSpring = state.doorSpring
		if doorSpring then
			doorSpring.position = Vector2.new(targetYaw, 0)
			doorSpring.target = Vector2.new(targetYaw, 0)
			doorSpring.velocity = Vector2.zero
		end
		applyPivot(door, pivotDriver, targetPivot)
		return
	end

	local doorSpring = state.doorSpring
	if not doorSpring then
		doorSpring = spring.new(
			Vector2.new(currentYaw, 0),
			springSettings.mass,
			springSettings.force,
			springSettings.damping,
			springSettings.speed
		)
		state.doorSpring = doorSpring
		ensureSpringConnection(state)
	else
		doorSpring.position = Vector2.new(currentYaw, 0)
	end

	doorSpring.mass = springSettings.mass
	doorSpring.force = springSettings.force
	doorSpring.damping = springSettings.damping
	doorSpring.speed = springSettings.speed
	doorSpring.target = Vector2.new(targetYaw, 0)
	if initialImpulse then
		doorSpring:shove(initialImpulse)
	end
end

function pivotDoor.destroyDriver(pivotDriver: CFrameValue?)
	if pivotDriver then
		pivotDriver:Destroy()
	end
end

return pivotDoor
