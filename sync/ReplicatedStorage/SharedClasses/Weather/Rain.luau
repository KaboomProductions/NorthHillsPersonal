local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local collectionService = game:GetService("CollectionService")

local player = players.LocalPlayer
local currentCamera = workspace.CurrentCamera

local gameValues = replicatedStorage.Values
local roundCycleValues = gameValues.RoundCycle
local climateStateValue = roundCycleValues.ClimateState

local sharedAssets = replicatedStorage:WaitForChild("SharedAssets")
local effectsFolder = sharedAssets:WaitForChild("Effects")
local weatherEffects = effectsFolder:WaitForChild("Weather")

local rainVisuals = weatherEffects:WaitForChild("Rain")
local splashEffect = rainVisuals.Splash
local mistEffect = rainVisuals.Mist
local puddleEffect = rainVisuals.Puddle
local hitEffect = rainVisuals.Hit
local dropletTypes = rainVisuals.DropletTypes

local rainController = {}
rainController.__index = rainController
rainController.__vars = {
	defaultStudsUp = 90,
	directionStrength = 100,
	rainyOffset = 3,
	emitCount = 3,
	offsetMin = 4,
	offsetMax = 7,
	updateRate = 0.02,
	clutterRate = 2.5,
}

local refreshTimestamp = os.clock()
local rng = Random.new()

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

function rainController:calculateRainPosition(): CFrame
	local cameraCFrame = currentCamera.CFrame
	local downwardPosition = self.downwardPosition

	local forward = cameraCFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude > 0.001 then
		forward = forward.Unit
	else
		forward = Vector3.new(0, 0, -1)
	end

	local right = cameraCFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z)

	if vector.magnitude(right) > 0.001 then
		right = right.Unit
	else
		right = Vector3.new(1, 0, 0)
	end

	local forwardOffset = rng:NextNumber(downwardPosition.Z * 0.25, downwardPosition.Z)
	local sideBias = rng:NextNumber(-1, 1)
	sideBias = sideBias * math.abs(sideBias)
	local sideOffset = sideBias * downwardPosition.X * 0.5

	local position = self.upwardPosition + forward * forwardOffset + right * sideOffset
	return CFrame.new(position)
end

function rainController:createNewAttachment(attachmentName: string): Attachment
	local newAttachment = Instance.new("Attachment")
	newAttachment.Parent = workspace.Terrain
	newAttachment.CFrame = self:calculateRainPosition() * CFrame.Angles(math.rad(-90), 0, 0)
	newAttachment.Name = attachmentName or "attachment"

	return newAttachment
end

function rainController:handleClutter()
	local stateValues = self.__vars
	local clutterObjects = self.clutterObjects

	if #clutterObjects <= 0 then
		return
	end

	for index = #clutterObjects, 1, -1 do
		local clutter = clutterObjects[index]
		if typeof(clutter) ~= "table" then
			continue
		end

		local lifetime = os.clock() - clutter.createdTimestamp
		if lifetime > stateValues.clutterRate then
			for _, object in pairs(clutter.objects) do
				object:Destroy()
			end

			table.remove(clutterObjects, index)
		end
	end
end

function rainController:clearClutter()
	local clutterObjects = self.clutterObjects

	for _, clutter in pairs(clutterObjects) do
		if typeof(clutter) ~= "table" then
			continue
		end

		for _, object in pairs(clutter.objects) do
			object:Destroy()
		end
	end

	table.clear(clutterObjects)
end

function rainController:toggle(isEnabled: boolean)
	local nextState = isEnabled == true
	if self.isActive == nextState then
		return
	end

	self.isActive = nextState

	if not nextState then
		self:clearClutter()
	end
end

function rainController:castRain(precipitationType: number)
	local stateValues = self.__vars
	local dropletVisual = precipitationType > 0.5
			and (precipitationType <= 1 and dropletTypes.Light or dropletTypes.Heavy)
		or nil
	local emitAmount = math.max(1, math.floor(math.lerp(1, 4, precipitationType)))

	if precipitationType == 0 or dropletVisual == nil then
		return
	end

	local floorAttachmentSide = self:createNewAttachment("floor1")
	local floorAttachmentY = self:createNewAttachment("floor2")
	local skyAttachment = self:createNewAttachment("sky")

	local baseDirection = skyAttachment.CFrame.LookVector

	local randomDirection = baseDirection
		+ Vector3.new(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.15, 0.15))

	randomDirection = randomDirection.Unit

	local raycastResult =
		workspace:Raycast(floorAttachmentSide.Position, randomDirection * stateValues.directionStrength, raycastParams)

	if raycastResult == nil or vector.magnitude(raycastResult.Position - floorAttachmentSide.Position) < 1 then
		floorAttachmentSide:Destroy()
		floorAttachmentY:Destroy()
		skyAttachment:Destroy()
		return
	end
	local hitPosition = raycastResult.Position
	skyAttachment.WorldCFrame = CFrame.new(hitPosition, hitPosition + raycastResult.Normal)

	local randomOffset = rng:NextNumber(stateValues.offsetMin, stateValues.offsetMax)
	floorAttachmentSide.WorldPosition += Vector3.new(randomOffset, 0, randomOffset)
	floorAttachmentY.WorldPosition = floorAttachmentSide.WorldPosition + Vector3.new(0, stateValues.rainyOffset, 0)

	local splashClone = splashEffect:Clone()
	local puddleClone = puddleEffect:Clone()
	local hitClone = hitEffect:Clone()
	local dropletClone = dropletVisual:Clone()

	if precipitationType > 1 then
		local mistClone = mistEffect:Clone()
		mistClone.Parent = floorAttachmentSide
		mistClone.Attachment0 = floorAttachmentSide
		mistClone.Attachment1 = skyAttachment

		mistClone.TextureLength = math.random(60, 80)
		mistClone.TextureSpeed = rng:NextNumber(0.5, 1.5)
		mistClone.Width0 = math.random(15, 30)
		mistClone.Width1 = math.random(15, 30)
	end

	splashClone.Parent = skyAttachment
	puddleClone.Parent = skyAttachment
	hitClone.Parent = skyAttachment
	splashClone:Emit(math.random(1, 2))
	hitClone:Emit(math.random(emitAmount - 1, emitAmount + 1))
	puddleClone:Emit(math.random(emitAmount - 1, emitAmount + 1))

	dropletClone.Parent = floorAttachmentSide
	dropletClone.Attachment0 = floorAttachmentSide
	dropletClone.Attachment1 = skyAttachment

	table.insert(self.clutterObjects, {
		objects = { floorAttachmentSide, floorAttachmentY, skyAttachment, dropletClone, splashClone },
		createdTimestamp = os.clock(),
	})
end

function rainController:update()
	if not self.isActive then
		return
	end

	local stateValues = self.__vars
	local precipitationType = climateStateValue:GetAttribute("PrecipitationType")

	local intensity = math.clamp(precipitationType, 0, 1)
	local newRate = stateValues.updateRate / math.max(intensity, 0.15)
	local spread = math.lerp(20, 45, intensity)

	if (os.clock() - refreshTimestamp) < newRate then
		return
	else
		refreshTimestamp = os.clock()
	end

	local cameraCFrame = currentCamera.CFrame
	self.upwardPosition = cameraCFrame.Position + Vector3.new(0, stateValues.defaultStudsUp, 0)
	self.downwardPosition = Vector3.new(spread, 0, spread)

	local castCount = math.max(1, math.floor(math.lerp(2, 5, intensity)))

	for _ = 1, castCount do
		self:castRain(precipitationType)
	end

	self:handleClutter()
end

function rainController.new()
	local self = setmetatable({}, rainController)
	self.__vars = table.clone(rainController.__vars)
	self.isActive = false
	self.clutterObjects = {}
	self.upwardPosition = nil
	self.downwardPosition = nil

	raycastParams.FilterDescendantsInstances =
		{ workspace.Ignore, workspace.Components, collectionService:GetTagged("RaycastIgnore") }

	self.characterAddedConnection = player.CharacterAdded:Connect(function()
		raycastParams.FilterDescendantsInstances =
			{ workspace.Ignore, workspace.Components, collectionService:GetTagged("RaycastIgnore") }
	end)

	runService:UnbindFromRenderStep("RainClient")
	runService:BindToRenderStep("RainClient", Enum.RenderPriority.Camera.Value, function()
		self:update()
	end)

	return self
end

function rainController:destroy()
	runService:UnbindFromRenderStep("RainClient")
	self.characterAddedConnection:Disconnect()

	self:clearClutter()
	setmetatable(self, nil)
end

return rainController
