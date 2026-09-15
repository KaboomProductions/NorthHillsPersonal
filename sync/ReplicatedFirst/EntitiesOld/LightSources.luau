local collectionService = game:GetService("CollectionService")
local players = game:GetService("Players")

local lightSourcesController = {}
lightSourcesController.__index = lightSourcesController

local player = players.LocalPlayer
local settingsConfig = player:WaitForChild("Settings", 3)
local photosensitivityModeSetting = settingsConfig.Gameplay:WaitForChild("Photosensitivity Mode", 1)

local lightTag = "LightSource"
local interfereTag = "InterfereWithLights"

local triggerRadius = 70
local releaseRadius = 80
local queryInterval = 0.15

local function lightEffect(light)
	local base = light.Brightness

	return {
		apply = function(factor)
			light.Brightness = base * factor
		end,

		restore = function()
			light.Brightness = base
		end,
	}
end

local function surfaceAppearanceEffect(sa)
	local base = sa.EmissiveStrength

	return {
		apply = function(factor)
			sa.EmissiveStrength = base * factor
		end,

		restore = function()
			sa.EmissiveStrength = base
		end,
	}
end

local function scaleNumberSequence(seq, factor)
	local keypoints = {}

	for _, kp in ipairs(seq.Keypoints) do
		local value = 1 - (1 - kp.Value) * factor
		table.insert(keypoints, NumberSequenceKeypoint.new(kp.Time, math.clamp(value, 0, 1), kp.Envelope))
	end

	return NumberSequence.new(keypoints)
end

local function beamEffect(beam)
	local baseBrightness = beam.Brightness
	local baseTransparency = beam.Transparency

	return {
		apply = function(factor)
			beam.Brightness = baseBrightness * factor
			beam.Transparency = scaleNumberSequence(baseTransparency, factor)
		end,

		restore = function()
			beam.Brightness = baseBrightness
			beam.Transparency = baseTransparency
		end,
	}
end

local function particleEffect(emitter)
	local baseSeq = emitter.Transparency

	return {
		apply = function(factor)
			emitter.Transparency = scaleNumberSequence(baseSeq, factor)
		end,

		restore = function()
			emitter.Transparency = baseSeq
		end,
	}
end

local function bulbEffect(part)
	local baseColor = part.Color
	local h, s, v = baseColor:ToHSV()

	return {
		apply = function(factor)
			part.Color = Color3.fromHSV(h, s, math.clamp(v * factor, 0, 1))
		end,

		restore = function()
			part.Color = baseColor
		end,
	}
end

local function isDirectLight(inst)
	return inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight")
end

function lightSourcesController:getEntities()
	if not self.instance then
		return {}
	end

	return self.instance:getEntities()
end

function lightSourcesController:anchorPosition(anchor)
	if anchor:IsA("BasePart") then
		return anchor.Position
	elseif anchor:IsA("Model") then
		return anchor:GetPivot().Position
	end

	for _, inst in ipairs(anchor:GetDescendants()) do
		if inst:IsA("BasePart") then
			return inst.Position
		end
	end

	return Vector3.zero
end

function lightSourcesController:findTaggedAnchor(part)
	local current = part

	while current do
		if collectionService:HasTag(current, lightTag) then
			return current
		end

		current = current.Parent
	end

	return nil
end

function lightSourcesController:getAnchorState(anchor)
	local state = self.anchorCache[anchor]

	if state then
		return state
	end

	state = {
		position = self:anchorPosition(anchor),
		effects = {},
		flickering = false,
		seed = math.random() * 1000,
	}

	local hasBulbPart = false
	local lightHostParts = {}
	local lightHostSeen = {}

	for _, inst in ipairs(anchor:GetDescendants()) do
		if isDirectLight(inst) then
			table.insert(state.effects, lightEffect(inst))
			local host = inst.Parent

			if host and host:IsA("BasePart") and not lightHostSeen[host] then
				lightHostSeen[host] = true
				table.insert(lightHostParts, host)
			end
		elseif inst:IsA("SurfaceAppearance") and inst.EmissiveStrength > 0 then
			table.insert(state.effects, surfaceAppearanceEffect(inst))
		elseif inst:IsA("Beam") then
			table.insert(state.effects, beamEffect(inst))
		elseif inst:IsA("ParticleEmitter") then
			table.insert(state.effects, particleEffect(inst))
		elseif inst:IsA("BasePart") and inst.Name == "Bulb" then
			table.insert(state.effects, bulbEffect(inst))
			hasBulbPart = true
		end
	end

	if not hasBulbPart then
		for _, host in ipairs(lightHostParts) do
			table.insert(state.effects, bulbEffect(host))
		end
	end

	self.anchorCache[anchor] = state

	return state
end

function lightSourcesController:refreshFilter()
	self.overlapParams.FilterDescendantsInstances = collectionService:GetTagged(lightTag)
end

function lightSourcesController.new(parentInstance: any)
	local self = setmetatable({}, lightSourcesController)
	self.instance = parentInstance

	self.anchorCache = {}
	self.activeFlickering = {}
	self.accumulator = 0

	self.overlapParams = OverlapParams.new()
	self.overlapParams.FilterType = Enum.RaycastFilterType.Include
	self.overlapParams.FilterDescendantsInstances = collectionService:GetTagged(lightTag)

	self.tagConnections = {
		collectionService:GetInstanceAddedSignal(lightTag):Connect(function()
			self:refreshFilter()
		end),

		collectionService:GetInstanceRemovedSignal(lightTag):Connect(function()
			self:refreshFilter()
		end),
	}

	return self
end

function lightSourcesController:destroy()
	for _, connection in self.tagConnections do
		connection:Disconnect()
	end

	for _, state in self.anchorCache do
		for _, effect in state.effects do
			pcall(effect.restore)
		end
	end

	table.clear(self.tagConnections)
	table.clear(self.activeFlickering)
	table.clear(self.anchorCache)
	self.instance = nil
	setmetatable(self, nil)
end

function lightSourcesController:update(deltaTime)
	self.accumulator = self.accumulator + deltaTime

	local nearbySet = {}
	local now = os.clock()

	if self.accumulator >= queryInterval then
		self.accumulator = 0

		for _, interferePart in ipairs(collectionService:GetTagged(interfereTag)) do
			if photosensitivityModeSetting.Value then
				break
			end

			if interferePart:IsA("BasePart") then
				local origin = interferePart.Position
				local nearby = workspace:GetPartBoundsInRadius(origin, releaseRadius, self.overlapParams)

				for _, hitPart in ipairs(nearby) do
					local anchor = self:findTaggedAnchor(hitPart)

					if anchor then
						local state = self:getAnchorState(anchor)
						nearbySet[state] = true

						if vector.magnitude(state.position - origin) <= triggerRadius and not state.flickering then
							state.flickering = true
							self.activeFlickering[state] = state
						end
					end
				end
			end
		end

		for state in pairs(self.activeFlickering) do
			if not nearbySet[state] then
				state.flickering = false

				for _, effect in ipairs(state.effects) do
					effect.restore()
				end

				self.activeFlickering[state] = nil
			end
		end
	end

	for _, state in pairs(self.activeFlickering) do
		local noiseFormula = math.noise(now * 8, state.seed) * 0.65 + math.noise(now * 23, state.seed + 50) * 0.4
		local factor = math.clamp(0.75 + noiseFormula, 0.05, 1.3)

		for _, effect in ipairs(state.effects) do
			effect.apply(factor)
		end
	end
end

return lightSourcesController
