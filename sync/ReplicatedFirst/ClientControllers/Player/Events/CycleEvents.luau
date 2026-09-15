local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")

local player = players.LocalPlayer
local settingsConfig = player:WaitForChild("Settings", 3)
local photosensitivityModeSetting = settingsConfig.Gameplay:WaitForChild("Photosensitivity Mode", 1)

local networking = require(replicatedStorage.Communication.Networking)
local cyclePhase = require(replicatedStorage.SharedAssets.CyclePhase)
local lightingSchema = require(replicatedStorage.SharedAssets.Dictionaries.LightingSchema)

local valuesFolder = replicatedStorage:WaitForChild("Values")
local roundCycleValuesFolder = valuesFolder:WaitForChild("RoundCycle")
local timeCycleFolder = roundCycleValuesFolder:WaitForChild("TimeCycle")
local climateStateValue = roundCycleValuesFolder:WaitForChild("ClimateState")
local nightTimeValue = timeCycleFolder:WaitForChild("NightTime")
local cycleActiveValue = roundCycleValuesFolder:WaitForChild("CycleActive")
local transitionStateValue = timeCycleFolder:WaitForChild("TransitionState")

local settingsFolder = replicatedStorage:WaitForChild("Settings")
local roundCycleSettingsFolder = settingsFolder:WaitForChild("RoundCycle")
local transitionLengthValue = roundCycleSettingsFolder:WaitForChild("TransitionLength")
local lightingSettingsFolder = roundCycleSettingsFolder:WaitForChild("LightingSettings")

local maxThunderDistanceSeconds = 5
local nightThunderFlashBrightness = 1.5
local dayThunderFlashBrightness = 2
local thunderRecoverySeconds = 0.5
local minimumFlickerOnMilliseconds = 15
local maximumFlickerOnMilliseconds = 45
local minimumFlickerOffMilliseconds = 25
local maximumFlickerOffMilliseconds = 50
local minimumFlickerDecayPercent = 30
local maximumFlickerDecayPercent = 60
local minimumFlickerCount = 3
local maximumFlickerCount = 5
local minimumTransitionDurationSeconds = 0.05

local lightingPropertyNames = lightingSchema.propertyNames
local effectPropertyNamesByClassName = lightingSchema.effectPropertyNamesByClassName

local function resolveLightingFolder(stateString: string, climateStateName: string?): Folder?
	local resolvedClimateName = climateStateName or climateStateValue.Value

	local directory = lightingSettingsFolder:FindFirstChild(resolvedClimateName)
	if not directory then
		warn("[CycleEvents] No LightingSettings folder for climate state:", resolvedClimateName)
		return nil
	end

	local phaseFolder = if stateString == cyclePhase.Day
		then directory:FindFirstChild("Day")
		else directory:FindFirstChild("Night")

	if not phaseFolder then
		warn("[CycleEvents] Missing", stateString, "subfolder in LightingSettings for:", resolvedClimateName)
	end

	return phaseFolder
end

local function ensureLightingChild(templateInstance)
	local existingInstance = lighting:FindFirstChild(templateInstance.Name)

	if existingInstance and existingInstance.ClassName == templateInstance.ClassName then
		return existingInstance
	end

	local clonedInstance = templateInstance:Clone()
	clonedInstance.Parent = lighting

	return clonedInstance
end

local writabilityCache = {}
local readabilityCache = {}

local function canWriteProperty(targetInstance, propertyName: string): boolean
	local className = targetInstance.ClassName
	local cacheKey = className .. "." .. propertyName
	local cachedResult = writabilityCache[cacheKey]

	if cachedResult ~= nil then
		return cachedResult
	end

	local success = pcall(function()
		(targetInstance)[propertyName] = (targetInstance)[propertyName]
	end)

	writabilityCache[cacheKey] = success
	return success
end

local function tryReadProperty(sourceInstance, propertyName: string): (boolean, any)
	local className = sourceInstance.ClassName
	local cacheKey = className .. "." .. propertyName
	local isReadable = readabilityCache[cacheKey]

	if isReadable == false then
		return false, nil
	end

	local success, value = pcall(function()
		return (sourceInstance)[propertyName]
	end)

	if isReadable == nil then
		readabilityCache[cacheKey] = success
	end

	return success, value
end

local function buildTweenGoalsForEffect(templateEffect, lightingEffect)
	local propertyNames = effectPropertyNamesByClassName[templateEffect.ClassName]
	if not propertyNames then
		return {}
	end

	local goals = {}

	for _, propertyName in ipairs(propertyNames) do
		local readOk, value = tryReadProperty(templateEffect, propertyName)
		if readOk and canWriteProperty(lightingEffect, propertyName) then
			goals[propertyName] = value
		end
	end

	return goals
end

local function buildTweenGoalsForLighting(folder: Folder)
	local goals = {}

	for _, propertyName in ipairs(lightingPropertyNames) do
		local attributeValue = folder:GetAttribute(propertyName)
		if attributeValue ~= nil and canWriteProperty(lighting, propertyName) then
			goals[propertyName] = attributeValue
		end
	end

	return goals
end

local function applyLightingInstant(folder: Folder)
	local lightingGoals = buildTweenGoalsForLighting(folder)
	for propertyName, value in pairs(lightingGoals) do
		pcall(function()
			(lighting)[propertyName] = value
		end)
	end

	for _, templateChild in ipairs(folder:GetChildren()) do
		if templateChild:IsA("Sky") then
			continue
		end

		local lightingChild = ensureLightingChild(templateChild)

		pcall(function()
			(lightingChild).Enabled = (templateChild).Enabled
		end)

		local effectGoals = buildTweenGoalsForEffect(templateChild, lightingChild)
		for propertyName, value in pairs(effectGoals) do
			pcall(function()
				(lightingChild)[propertyName] = value
			end)
		end
	end
end

local cycleEventController = {}
cycleEventController.__index = cycleEventController

function cycleEventController:cancelTweens()
	for _, tween in pairs(self.activeTweens) do
		pcall(function()
			tween:Cancel()
		end)
	end

	table.clear(self.activeTweens)
end

function cycleEventController:tweenToFolder(targetFolder: Folder, durationSeconds: number)
	self.transitionToken += 1
	local tweenInformation = TweenInfo.new(durationSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local lightingGoals = buildTweenGoalsForLighting(targetFolder)
	self:cancelTweens()

	if next(lightingGoals) then
		local lightingTween = tweenService:Create(lighting, tweenInformation, lightingGoals)
		self.activeTweens[lighting] = lightingTween

		lightingTween:Play()
	end

	for _, templateChild in ipairs(targetFolder:GetChildren()) do
		if templateChild:IsA("Sky") then
			continue
		end

		local lightingChild = ensureLightingChild(templateChild)

		pcall(function()
			(lightingChild).Enabled = (templateChild).Enabled
		end)

		local effectGoals = buildTweenGoalsForEffect(templateChild, lightingChild)
		if next(effectGoals) then
			local effectTween = tweenService:Create(lightingChild, tweenInformation, effectGoals)
			self.activeTweens[lightingChild] = effectTween

			effectTween:Play()
		end
	end
end

function cycleEventController:transition(roundState: string, climateStateName: string?)
	local targetFolder = resolveLightingFolder(roundState, climateStateName)
	if not targetFolder then
		warn(
			"[CycleEvents] Transition aborted: could not resolve lighting folder for phase:",
			roundState,
			"climate:",
			climateStateName or climateStateValue.Value
		)
		return
	end

	local durationSeconds = math.max(minimumTransitionDurationSeconds, transitionLengthValue.Value)
	self:tweenToFolder(targetFolder, durationSeconds)
end

function cycleEventController:constructThunder(distanceTo: number)
	if photosensitivityModeSetting.Value then
		return
	end

	local originalBrightness = lighting.Brightness
	local distanceAlpha = math.clamp(1 - (distanceTo / maxThunderDistanceSeconds), 0, 1)
	local flashDelta = (nightTimeValue.Value and nightThunderFlashBrightness or dayThunderFlashBrightness)
		* distanceAlpha
	local peakBrightness = originalBrightness + flashDelta
	local flickerCount = math.random(minimumFlickerCount, maximumFlickerCount)

	task.spawn(function()
		for _ = 1, flickerCount do
			if photosensitivityModeSetting.Value then
				return
			end

			lighting.Brightness = peakBrightness
			task.wait(math.random(minimumFlickerOnMilliseconds, maximumFlickerOnMilliseconds) / 1000)
			lighting.Brightness = originalBrightness
				+ (peakBrightness - originalBrightness)
					* (math.random(minimumFlickerDecayPercent, maximumFlickerDecayPercent) / 100)
			task.wait(math.random(minimumFlickerOffMilliseconds, maximumFlickerOffMilliseconds) / 1000)
		end

		tweenService
			:Create(lighting, TweenInfo.new(thunderRecoverySeconds), {
				Brightness = originalBrightness,
			})
			:Play()
	end)
end

function cycleEventController:waitForCycleReady()
	if cycleActiveValue.Value and climateStateValue.Value ~= "nil" then
		return
	end

	local readySignal = Instance.new("BindableEvent")

	local readyConnections = {}

	readyConnections[1] = cycleActiveValue:GetPropertyChangedSignal("Value"):Connect(function()
		if cycleActiveValue.Value and climateStateValue.Value ~= "nil" then
			readySignal:Fire()
		end
	end)

	readyConnections[2] = climateStateValue:GetPropertyChangedSignal("Value"):Connect(function()
		if cycleActiveValue.Value and climateStateValue.Value ~= "nil" then
			readySignal:Fire()
		end
	end)

	readySignal.Event:Wait()

	for _, connection in ipairs(readyConnections) do
		connection:Disconnect()
	end
	readySignal:Destroy()
end

function cycleEventController:initializeOnJoin()
	if self.receivedStateSnapshot then
		return
	end

	self:waitForCycleReady()

	local isTransitioning = transitionStateValue.Value
	local isNight = nightTimeValue.Value
	local currentClimateName = climateStateValue.Value

	if isTransitioning then
		local nextStateString = isNight and cyclePhase.Day or cyclePhase.Night
		local targetFolder = resolveLightingFolder(nextStateString, currentClimateName)

		if targetFolder then
			local durationSeconds = math.max(minimumTransitionDurationSeconds, transitionLengthValue.Value)
			self:tweenToFolder(targetFolder, durationSeconds)
		else
			warn(
				"[CycleEvents] initializeOnJoin: mid-transition but could not resolve lighting folder for",
				nextStateString,
				"climate:",
				currentClimateName
			)
		end

		return
	end

	local currentStateString = isNight and cyclePhase.Night or cyclePhase.Day
	local currentFolder = resolveLightingFolder(currentStateString, currentClimateName)

	if currentFolder then
		self:cancelTweens()
		applyLightingInstant(currentFolder)
	else
		warn(
			"[CycleEvents] initializeOnJoin: could not resolve lighting folder for",
			currentStateString,
			"climate:",
			currentClimateName
		)
	end
end

function cycleEventController:applyStateSnapshot(stateSnapshot)
	if type(stateSnapshot) ~= "table" then
		return
	end

	self.receivedStateSnapshot = true

	if
		stateSnapshot.cycleActive ~= true
		or stateSnapshot.climateStateName == nil
		or stateSnapshot.climateStateName == "nil"
	then
		return
	end

	if stateSnapshot.isTransitioning then
		local nextStateString = stateSnapshot.isNight and cyclePhase.Day or cyclePhase.Night
		local targetFolder = resolveLightingFolder(nextStateString, stateSnapshot.climateStateName)

		if targetFolder then
			local durationSeconds = math.max(minimumTransitionDurationSeconds, transitionLengthValue.Value)
			self:tweenToFolder(targetFolder, durationSeconds)
		end

		return
	end

	local currentStateString = stateSnapshot.isNight and cyclePhase.Night or cyclePhase.Day
	local currentFolder = resolveLightingFolder(currentStateString, stateSnapshot.climateStateName)

	if currentFolder then
		self:cancelTweens()
		applyLightingInstant(currentFolder)
	end
end

function cycleEventController.new()
	local self = setmetatable({}, cycleEventController)
	self.activeTweens = {}
	self.transitionToken = 0
	self.connections = {}
	self.receivedStateSnapshot = false

	self.connections.transition = networking.events.roundCycleTransition.OnClientEvent:Connect(function(transitionData)
		local roundState = transitionData.phaseString
		local climateStateName = transitionData.climateStateName

		if not roundState or not climateStateName then
			warn("[CycleEvents] Received malformed transition data:", transitionData)
			return
		end

		self:transition(roundState, climateStateName)
	end)

	self.connections.cycleStateUpdate = networking.events.cycleStateUpdate.OnClientEvent:Connect(function(stateSnapshot)
		self:applyStateSnapshot(stateSnapshot)
	end)

	self.connections.thunder = networking.events.thunder.OnClientEvent:Connect(function(distanceTo: number)
		self:constructThunder(distanceTo)
	end)

	networking.events.markRoundCycleEventsReady:FireServer()
	task.delay(0.5, function()
		if getmetatable(self) ~= nil then
			self:initializeOnJoin()
		end
	end)

	return self
end

function cycleEventController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	self:cancelTweens()

	table.clear(self.connections)
end

return cycleEventController
