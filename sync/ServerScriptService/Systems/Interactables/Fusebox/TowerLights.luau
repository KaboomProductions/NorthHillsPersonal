local tweenService = game:GetService("TweenService")

local towerLightsController = {}
towerLightsController.__index = towerLightsController
towerLightsController.__vars = {
	isToggled = false,
}

local lightOnTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.In)
local lightOffTweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function towerLightsController:preload()
	local instance = self.instance
	local lightsFolder = instance:FindFirstChild("Lights")

	if lightsFolder == nil then
		self:destroy()
		return
	end

	instance:SetAttribute("Toggled", false)
	self.lightObjects = lightsFolder:GetChildren()

	self.connections.toggled = instance:GetAttributeChangedSignal("Toggled"):Connect(function()
		self.__vars.isToggled = instance:GetAttribute("Toggled")

		for _, lightObject in self.lightObjects do
			self:handleLight(lightObject)
		end
	end)
end

local function playTrackedTween(self, trackedTween: Tween)
	self.activeTweens[trackedTween] = true
	trackedTween.Completed:Once(function()
		self.activeTweens[trackedTween] = nil
	end)
	trackedTween:Play()
end

function towerLightsController:handleLight(lightObject: Instance)
	local stateValues = self.__vars
	local isToggled = stateValues.isToggled
	local desiredBrightness = isToggled and 10 or 0
	local tweenInfo = isToggled and lightOnTweenInfo or lightOffTweenInfo

	local cachedLightsByObject = self.cachedLightsByObject
	local cachedLights = cachedLightsByObject[lightObject]

	if not cachedLights then
		cachedLights = {}
		cachedLightsByObject[lightObject] = cachedLights

		local floodLight = lightObject:FindFirstChild("FloodLight")
		if floodLight then
			for _, descendant in floodLight:GetDescendants() do
				if descendant:IsA("Light") or descendant:IsA("Beam") then
					table.insert(cachedLights, descendant)
				end
			end
		end
	end

	for _, lightInstance in cachedLights do
		if lightInstance:IsA("Light") then
			playTrackedTween(
				self,
				tweenService:Create(lightInstance, tweenInfo, {
					Brightness = desiredBrightness,
				})
			)
		elseif lightInstance:IsA("Beam") then
			lightInstance.Enabled = true

			local previousMultiplier = lightInstance:FindFirstChild("TransparencyMultiplier")
			if previousMultiplier then
				previousMultiplier:Destroy()
			end

			local transparencyMultiplier = Instance.new("NumberValue")
			transparencyMultiplier.Name = "TransparencyMultiplier"
			transparencyMultiplier.Value = isToggled and 1 or 0
			transparencyMultiplier.Parent = lightInstance

			local multiplierTween = tweenService:Create(transparencyMultiplier, tweenInfo, {
				Value = isToggled and 0 or 1,
			})

			local multiplierChangedConnection = transparencyMultiplier
				:GetPropertyChangedSignal("Value")
				:Connect(function()
					lightInstance.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.762 + transparencyMultiplier.Value),
						NumberSequenceKeypoint.new(0.542, 0.313 + transparencyMultiplier.Value),
						NumberSequenceKeypoint.new(0.94, 0 + transparencyMultiplier.Value),
						NumberSequenceKeypoint.new(1, 1),
					})
				end)

			multiplierTween.Completed:Once(function()
				multiplierChangedConnection:Disconnect()
				transparencyMultiplier:Destroy()
			end)
			playTrackedTween(self, multiplierTween)
		end
	end
end

function towerLightsController:toggle(forcedState: boolean?)
	local stateValues = self.__vars
	local nextState = if forcedState ~= nil then forcedState else not stateValues.isToggled
	self.instance:SetAttribute("Toggled", nextState)
end

function towerLightsController.new(instance: Instance)
	local self = setmetatable({}, towerLightsController)

	self.instance = instance
	self.connections = {}
	self.cachedLightsByObject = {}
	self.activeTweens = {}
	self.__vars = table.clone(towerLightsController.__vars)

	self:preload()

	return self
end

function towerLightsController:destroy()
	if getmetatable(self) == nil then
		return
	end

	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	for activeTween in pairs(self.activeTweens) do
		activeTween:Cancel()
		activeTween:Destroy()
	end

	table.clear(self.connections)
	table.clear(self.activeTweens)
	table.clear(self.cachedLightsByObject)
	setmetatable(self, nil)
end

return towerLightsController
