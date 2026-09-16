local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local climateGraph = require(script.Graph)

local ignoreFolder = workspace.Ignore
local effectsFolder = ignoreFolder.Effects
local windEffectParts = effectsFolder.Wind:GetChildren()

local terrain = workspace.Terrain
local clouds = terrain.Clouds

local gameValues = replicatedStorage.Values
local cycleValues = gameValues.RoundCycle
local volumetricValues = gameValues.Volumetrics

local spacingValue = volumetricValues.Spacing
local layersValue = volumetricValues.Layers

local transitionStateValue = cycleValues.TimeCycle.TransitionState
local climateStateValue = cycleValues.ClimateState

local defaultVolumetricLayers = 110
local defaultVolumetricSpacing = 1.25
local defaultEscalateWeight = 0.5

local stateHistory: { string } = {}
local historySize = 5
local meanReversionStrength = 0.25
local midpointSeverity = 3.5

local function recordStateInHistory(stateName: string)
	table.insert(stateHistory, stateName)
	if #stateHistory > historySize then
		table.remove(stateHistory, 1)
	end
end

local function getRandomWindVector(minStrength: number, maxStrength: number): Vector3
	local angle = math.random() * math.pi * 2
	local strength = math.random(minStrength, maxStrength)

	return Vector3.new(math.cos(angle), 0, math.sin(angle)) * strength
end

local function computeAverageSeverity(): number?
	if #stateHistory == 0 then
		return nil
	end

	local totalSeverity = 0
	for _, historicStateName in ipairs(stateHistory) do
		local graphEntry = climateGraph[historicStateName]
		totalSeverity += graphEntry and graphEntry.severity or 0
	end

	return totalSeverity / #stateHistory
end

type ClimateState = {
	enter: (() -> ())?,
	exit: (() -> ())?,
	update: ((deltaTime: number) -> ())?,
	__config: {
		windEffects: boolean?,
		volumetrics: { layers: number?, spacing: number? }?,
		nightLengthMultiplier: number?,
	}?,
}

local currentState: ClimateState? = nil
local statesByName: { [string]: ClimateState } = {}

local climateController = {}

function climateController.refreshStates()
	local newStates: { [string]: ClimateState } = {}

	for _, stateModule in ipairs(script.States:GetChildren()) do
		if not stateModule:IsA("ModuleScript") then
			continue
		end

		local isSuccess, stateResult = pcall(require, stateModule)
		if isSuccess then
			newStates[stateModule.Name] = stateResult
		end
	end

	statesByName = newStates
end

function climateController.preload()
	climateController.refreshStates()

	local stateNames = {}
	for stateName in pairs(statesByName) do
		table.insert(stateNames, stateName)
	end

	local initialStateName = stateNames[math.random(#stateNames)]

	--// Seed fake history by walking deescalation edges backwards from the
	--// initial state, so mean reversion is active from the very first decide()
	local fakeHistory = {}
	local walkName = initialStateName
	for _ = 1, historySize do
		table.insert(fakeHistory, 1, walkName)
		local walkEntry = climateGraph[walkName]
		local nextWalk = walkEntry and walkEntry.deEscalate
		if nextWalk and climateGraph[nextWalk] then
			walkName = nextWalk
		end
	end

	for _, historyStateName in ipairs(fakeHistory) do
		recordStateInHistory(historyStateName)
	end

	climateController.loadState(statesByName.Wet) -- [initialStateName]
end

function climateController.applyEffects(state: ClimateState)
	local stateConfig = state.__config or {}
	local isWindEnabled = stateConfig.windEffects or false
	local cloudProperties = stateConfig.cloudProperties or {}
	local volumetrics = stateConfig.volumetrics or {}
	local globalWindProperties = stateConfig.globalWindProperties or {}

	for _, part in pairs(windEffectParts) do
		if not part:IsA("BasePart") then
			continue
		end

		local beam = part:FindFirstChildOfClass("Beam")
		if beam ~= nil then
			beam.Enabled = isWindEnabled
		end
	end

	local globalWindTween = tweenService:Create(workspace, TweenInfo.new(10), {
		GlobalWind = getRandomWindVector(globalWindProperties.minStrength or 0, globalWindProperties.maxStrength or 0),
	})

	local cloudsTween = tweenService:Create(clouds, TweenInfo.new(5), {
		Cover = cloudProperties.Cover or 0,
		Density = cloudProperties.Density or 0,
		Color = cloudProperties.Color or Color3.new(1, 1, 1),
	})

	cloudsTween:Play()
	globalWindTween:Play()

	layersValue.Value = volumetrics.layers or defaultVolumetricLayers
	spacingValue.Value = volumetrics.spacing or defaultVolumetricSpacing
end

function climateController.getCurrentConfig(): { [string]: any }
	if currentState and currentState.__config then
		return currentState.__config
	end
	return {}
end

function climateController.loadState(state: ClimateState)
	if currentState and currentState.exit then
		currentState.exit()
	end

	currentState = state

	for stateName, registeredState in pairs(statesByName) do
		if registeredState ~= state then
			continue
		end

		climateStateValue.Value = stateName
		recordStateInHistory(stateName)
		break
	end

	climateController.applyEffects(state)

	task.spawn(function()
		repeat
			task.wait()
		until not transitionStateValue.Value

		if currentState and currentState.enter then
			currentState.enter()
		end
	end)

	task.defer(function()
		if not currentState then
			return
		end

		while currentState == state and currentState.update do
			local deltaTime = task.wait(1 / 5)
			currentState.update(deltaTime)
		end
	end)
end

function climateController.decide()
	local currentStateName = climateStateValue.Value
	local graphEntry = climateGraph[currentStateName]

	if not graphEntry then
		warn("[Climate] No graph entry for current state:", currentStateName, "— falling back to Dry")
		climateController.loadState(statesByName.Wet)
		return
	end

	--// Mean reversion: high recent severity pushes toward de-escalation,
	--// low recent severity pushes toward escalation, creating natural cycles
	local baseWeight = graphEntry.escalateWeight or defaultEscalateWeight
	local adjustedWeight = baseWeight
	local averageSeverity = computeAverageSeverity()

	if averageSeverity then
		local normalizedDeviation = (averageSeverity - midpointSeverity) / midpointSeverity
		adjustedWeight = math.clamp(baseWeight - normalizedDeviation * meanReversionStrength, 0.05, 0.95)
	end

	local shouldEscalate = math.random() < adjustedWeight
	local nextStateName: string? = nil

	if shouldEscalate and graphEntry.escalate then
		nextStateName = graphEntry.escalate
	elseif not shouldEscalate and graphEntry.deEscalate then
		nextStateName = graphEntry.deEscalate
	end

	local nextState = statesByName.Wet -- nextStateName and statesByName[nextStateName] or statesByName.Dry

	if nextState ~= nil then
		climateController.loadState(nextState)
	end
end

return climateController
