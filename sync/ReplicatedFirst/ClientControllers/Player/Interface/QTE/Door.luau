local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local clientData = require(replicatedFirst.ClientData)
local mouseController = require(replicatedFirst.ClientControllers.Player.Interface.Mouse)
local networking = require(replicatedStorage.Communication.Networking)
local doorConfig = require(script.Config)
local cursorHandler = require(script.Cursor)
local kickHandler = require(script.Kicks)
local fillBarHandler = require(script.FillBar)
local shakeHandler = require(script.Shake)

local player = players.LocalPlayer

local doorController = {}
doorController.__index = doorController
doorController.__vars = {
	isActive = false,
	isInitialized = false,
	cursorPosition = Vector2.zero,
	currentHexagonThreshold = doorConfig.hexagonThreshold,
	targetHexagonThreshold = doorConfig.hexagonThreshold,
	currentHexagonRotation = 0,
	targetHexagonRotation = 0,
	fillProgress = 0,
	displayedFillProgress = 0,
	screenShake = 0,
}

local function getExponentialAlpha(speed: number, deltaTime: number): number
	return 1 - math.exp(-speed * deltaTime)
end

function doorController:preload()
	local interface = player.PlayerGui:WaitForChild("Interface")
	local quickTimeEvents = interface:FindFirstChild("QuickTimeEvents")
	if not quickTimeEvents then
		return false
	end

	local door = quickTimeEvents:FindFirstChild("Door")
	if not door then
		return false
	end

	self.container = door
	self.cursor = door:WaitForChild("cursor")
	self.circle = door:WaitForChild("burshcircle")
	self.baseCircleRotation = self.circle.Rotation
	self.baseCircleSize = self.circle.Size

	if doorConfig.showDetectionDebugVisualizer then
		local debugHexagon = self.circle:Clone()
		debugHexagon.Name = "DetectionVisualizer"
		debugHexagon.AnchorPoint = Vector2.new(0.5, 0.5)
		debugHexagon.Visible = false
		debugHexagon.ZIndex = self.circle.ZIndex + 1

		if debugHexagon:IsA("ImageLabel") or debugHexagon:IsA("ImageButton") then
			debugHexagon.ImageColor3 = Color3.fromRGB(255, 96, 96)
			debugHexagon.ImageTransparency = 0.45
		end

		if debugHexagon:IsA("GuiObject") then
			debugHexagon.BackgroundTransparency = 1
		end

		debugHexagon.Parent = door
		self.debugHexagon = debugHexagon
	end

	local barContainer = door:WaitForChild("bar")
	self.fillBars, self.fillBarGradients = fillBarHandler.setupGradients(barContainer)

	self:cacheBaseTransparencies()

	local transparencyValue = Instance.new("NumberValue")
	transparencyValue.Value = 0
	transparencyValue.Changed:Connect(function(alpha)
		self:setTransparencyAlpha(alpha)
	end)
	self.transparencyValue = transparencyValue

	self.container.Visible = false
	return true
end

local TWEEN_IN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local TRANSPARENCY_PROPERTIES = {
	"BackgroundTransparency",
	"TextTransparency",
	"TextStrokeTransparency",
	"ImageTransparency",
}

function doorController:cacheBaseTransparencies()
	local cache = {}
	local container = self.container

	for _, descendant in container:GetDescendants() do
		if
			not descendant:IsA("GuiObject")
			and not descendant:IsA("TextLabel")
			and not descendant:IsA("TextButton")
			and not descendant:IsA("ImageLabel")
			and not descendant:IsA("ImageButton")
		then
			continue
		end

		local entry = {}
		for _, property in TRANSPARENCY_PROPERTIES do
			local success, value = pcall(function()
				return descendant[property]
			end)
			if success and typeof(value) == "number" then
				entry[property] = value
			end
		end

		if next(entry) then
			cache[descendant] = entry
		end
	end

	self.baseTransparencies = cache
end

function doorController:setTransparencyAlpha(alpha: number)
	for descendant, properties in self.baseTransparencies do
		for property, baseValue in properties do
			descendant[property] = baseValue + (1 - baseValue) * alpha
		end
	end
end

function doorController:updateTargetHexagon()
	local circle = self.circle
	local circleCenter = self.circleCenter
	local thresholdScale = self.__vars.currentHexagonThreshold / doorConfig.hexagonThreshold
	local baseCircleSize = self.baseCircleSize
	local scaledSize = UDim2.new(
		baseCircleSize.X.Scale * thresholdScale,
		math.round(baseCircleSize.X.Offset * thresholdScale),
		baseCircleSize.Y.Scale * thresholdScale,
		math.round(baseCircleSize.Y.Offset * thresholdScale)
	)

	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(circleCenter.X, circleCenter.Y)
	circle.Size = scaledSize
	circle.Rotation = self.baseCircleRotation + self.__vars.currentHexagonRotation

	local debugHexagon = self.debugHexagon
	if debugHexagon then
		debugHexagon.Visible = true
		debugHexagon.Position = UDim2.fromScale(circleCenter.X, circleCenter.Y)
		debugHexagon.Size = scaledSize
		debugHexagon.Rotation = circle.Rotation
	end
end

function doorController:init()
	local isReady = self:preload()
	if not isReady then
		return
	end

	self.__vars.isInitialized = true

	self.connections.startDoorQte = networking.events.startDoorQte.OnClientEvent:Connect(function(door)
		self.targetDoor = door
		self:start()
	end)

	self.connections.doorQteKick = networking.events.doorQteKick.OnClientEvent:Connect(function(distance)
		if self.__vars.isActive then
			self:applyKick(distance)
		end
	end)

	self.connections.doorQtePressure = networking.events.doorQtePressure.OnClientEvent:Connect(function(payload)
		if not self.__vars.isActive then
			return
		end

		local kickState = self.kickState
		kickState.isPressureActive = true
		kickState.pressureEndTime = os.clock() + payload.duration
		kickState.pressureDirection = Vector2.new(payload.directionX, payload.directionY)
	end)

	self.connections.endDoorQte = networking.events.endDoorQte.OnClientEvent:Connect(function()
		self:stop()
	end)
end

function doorController:start()
	local stateValues = self.__vars
	if stateValues.isActive or not stateValues.isInitialized then
		return
	end

	stateValues.isActive = true
	stateValues.cursorPosition = Vector2.zero
	stateValues.currentHexagonThreshold = doorConfig.hexagonThreshold
	stateValues.targetHexagonThreshold = doorConfig.hexagonThreshold
	stateValues.currentHexagonRotation = 0
	stateValues.targetHexagonRotation = 0
	stateValues.fillProgress = 1
	stateValues.displayedFillProgress = 1
	stateValues.screenShake = 0

	self.kickState = kickHandler.createState()

	self.mouseLockToken = mouseController.acquireLock("doorQte")
	clientData.movementLocks.qte = true
	clientData.perspectiveLocks.qte = true
	clientData.cameraLocks.qte = true

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	self.circleCenter = cursorHandler.computeCircleCenter(self.circle, self.container)
	local container = self.container
	self:setTransparencyAlpha(1)
	container.Visible = true
	if self.debugHexagon then
		self.debugHexagon.Visible = true
	end
	self.circle.AnchorPoint = Vector2.new(0.5, 0.5)
	self.cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	self.cursor.Position = UDim2.fromScale(self.circleCenter.X, self.circleCenter.Y)
	self:updateTargetHexagon()
	fillBarHandler.renderGradients(self.fillBarGradients, 1)

	if self.activeTween then
		self.activeTween:Cancel()
	end
	self.transparencyValue.Value = 1
	self.activeTween = tweenService:Create(self.transparencyValue, TWEEN_IN, { Value = 0 })
	self.activeTween:Play()

	runService:BindToRenderStep("DoorQTE_Update", Enum.RenderPriority.Camera.Value + 10, function(deltaTime)
		self:update(deltaTime)
	end)
end

function doorController:stop()
	local stateValues = self.__vars
	if not stateValues.isActive then
		return
	end

	stateValues.isActive = false

	mouseController.releaseLock(self.mouseLockToken)
	self.mouseLockToken = nil
	clientData.movementLocks.qte = nil
	clientData.perspectiveLocks.qte = nil
	clientData.cameraLocks.qte = nil

	local container = self.container
	if self.activeTween then
		self.activeTween:Cancel()
	end
	self.activeTween = tweenService:Create(self.transparencyValue, TWEEN_OUT, { Value = 1 })
	self.activeTween:Play()
	self.activeTween.Completed:Once(function()
		runService:UnbindFromRenderStep("DoorQTE_Update")
		container.Visible = false
		if self.debugHexagon then
			self.debugHexagon.Visible = false
		end
		self:setTransparencyAlpha(0)
	end)
end

function doorController:applyKick(kickDistance: number)
	local stateValues = self.__vars
	local displacement = kickHandler.computeKickDisplacement(stateValues.cursorPosition, kickDistance)
	local newPosition = cursorHandler.clamp(stateValues.cursorPosition + displacement)

	stateValues.cursorPosition = newPosition
	stateValues.screenShake = shakeHandler.addScreenShake(stateValues.screenShake, kickDistance)
	stateValues.fillProgress = fillBarHandler.applyKickDrain(stateValues.fillProgress, kickDistance)

	local kickStrength = math.clamp(kickDistance / doorConfig.kickDistance, 0, 1)
	local scaleRange = doorConfig.hexagonKickScaleMax - doorConfig.hexagonKickScaleMin
	local randomScale = doorConfig.hexagonKickScaleMin + math.random() * scaleRange
	local scaledKickFactor = 1 + (randomScale - 1) * kickStrength
	stateValues.targetHexagonThreshold = doorConfig.hexagonThreshold * scaledKickFactor
	stateValues.targetHexagonRotation = (math.random() * 2 - 1) * doorConfig.hexagonRotationMaxDegrees * kickStrength

	shakeHandler.applyFovBump(kickDistance)
end

function doorController:update(deltaTime: number)
	local stateValues = self.__vars
	local currentTime = os.clock()
	local containerSize = self.container.AbsoluteSize
	local scaleReturnAlpha = getExponentialAlpha(doorConfig.hexagonScaleReturnSpeed, deltaTime)
	local scaleLerpAlpha = getExponentialAlpha(doorConfig.hexagonScaleLerpSpeed, deltaTime)
	local rotationReturnAlpha = getExponentialAlpha(doorConfig.hexagonRotationReturnSpeed, deltaTime)
	local rotationLerpAlpha = getExponentialAlpha(doorConfig.hexagonRotationLerpSpeed, deltaTime)

	stateValues.targetHexagonThreshold += (doorConfig.hexagonThreshold - stateValues.targetHexagonThreshold) * scaleReturnAlpha
	stateValues.currentHexagonThreshold += (stateValues.targetHexagonThreshold - stateValues.currentHexagonThreshold) * scaleLerpAlpha
	stateValues.targetHexagonRotation += (0 - stateValues.targetHexagonRotation) * rotationReturnAlpha
	stateValues.currentHexagonRotation += (stateValues.targetHexagonRotation - stateValues.currentHexagonRotation) * rotationLerpAlpha

	self:updateTargetHexagon()

	local cursorPosition = stateValues.cursorPosition
	cursorPosition = cursorHandler.applyMouseInput(cursorPosition, containerSize)
	cursorPosition = cursorHandler.applyDrift(cursorPosition, currentTime, deltaTime)
	stateValues.cursorPosition = cursorPosition

	if stateValues.isActive then
		local kickState = self.kickState

		if kickState.isPressureActive then
			if currentTime >= kickState.pressureEndTime then
				kickState.isPressureActive = false
			else
				local pushDisplacement = kickState.pressureDirection * doorConfig.pressurePushSpeed * deltaTime
				stateValues.cursorPosition = stateValues.cursorPosition + pushDisplacement
				stateValues.screenShake = math.max(stateValues.screenShake, doorConfig.pressureShakeIntensity)
				stateValues.fillProgress =
					math.max(0, stateValues.fillProgress - doorConfig.pressureDrainSpeed * deltaTime)
			end
		end
	end

	stateValues.cursorPosition = cursorHandler.clamp(stateValues.cursorPosition)
	cursorPosition = stateValues.cursorPosition

	local isPressureActive = stateValues.isActive and self.kickState and self.kickState.isPressureActive
	local jitterMultiplier = isPressureActive and doorConfig.pressureJitterMultiplier or 1

	stateValues.screenShake = shakeHandler.decayScreenShake(stateValues.screenShake, deltaTime)
	local uiShakeOffset = shakeHandler.computeUiShakeOffset(stateValues.screenShake)

	local visualOffset = cursorHandler.computeVisualOffset(currentTime, jitterMultiplier)
	local circleCenter = self.circleCenter
	local displayPosition = cursorPosition + visualOffset + uiShakeOffset
	self.cursor.Position = UDim2.fromScale(circleCenter.X + displayPosition.X, circleCenter.Y + displayPosition.Y)
	self.container.Position = UDim2.fromScale(0.5 + uiShakeOffset.X, 0.5 + uiShakeOffset.Y)

	shakeHandler.applyCameraShake(workspace.CurrentCamera.CFrame, stateValues.screenShake)

	if not stateValues.isActive then
		return
	end

	local distanceFromCenter = cursorPosition.Magnitude
	stateValues.fillProgress = fillBarHandler.updateProgress(
		stateValues.fillProgress,
		distanceFromCenter,
		deltaTime,
		stateValues.currentHexagonThreshold
	)
	stateValues.displayedFillProgress =
		fillBarHandler.smoothDisplayProgress(stateValues.displayedFillProgress, stateValues.fillProgress, deltaTime)
	fillBarHandler.renderGradients(self.fillBarGradients, stateValues.displayedFillProgress)

	if stateValues.fillProgress <= 0 then
		networking.events.doorQteFailed:FireServer()
		self:stop()
	end
end

function doorController.new()
	local self = setmetatable({}, doorController)

	self.connections = {}
	self.__vars = table.clone(doorController.__vars)

	self.container = nil
	self.cursor = nil
	self.circle = nil
	self.baseCircleRotation = 0
	self.baseCircleSize = UDim2.fromScale(0, 0)
	self.circleCenter = Vector2.new(0.5, 0.5)
	self.fillBars = {}
	self.fillBarGradients = {}
	self.kickState = nil
	self.mouseLockToken = nil
	self.targetDoor = nil
	self.debugDot = nil
	self.debugHexagon = nil
	self.activeTween = nil
	self.transparencyValue = nil
	self.baseTransparencies = {}

	task.defer(self.init, self)

	return self
end

function doorController:destroy()
	self:stop()

	if self.activeTween then
		self.activeTween:Cancel()
	end

	if self.transparencyValue then
		self.transparencyValue:Destroy()
	end

	local connections = self.connections
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return doorController
