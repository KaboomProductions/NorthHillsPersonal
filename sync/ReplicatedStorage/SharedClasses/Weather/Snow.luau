local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local sharedAssets = replicatedStorage:WaitForChild("SharedAssets")
local effectsFolder = sharedAssets:WaitForChild("Effects")
local weatherEffects = effectsFolder:WaitForChild("Weather")
local snowParticle = weatherEffects:WaitForChild("Snow")

local snowController = {}
snowController.__index = snowController

local clientRuntime = require(replicatedFirst.ClientData.ClientRuntime)
local config = require(script:WaitForChild("Config", 2))

local player = players.LocalPlayer
local currentCamera = workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()

local currentStage = config.stages[1]
local positionConfig = config.positioning

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local ignore = workspace.Ignore
local terrain = workspace.Terrain

function snowController:createNewAttachment(attachmentName: string): Attachment
	local attachment = Instance.new("Attachment")
	attachment.CFrame = CFrame.Angles(math.rad(-90), 0, 0)
	attachment.Name = attachmentName
	attachment.Parent = terrain
	attachment.Visible = config.debugMode or false

	return attachment
end

function snowController:handleClutter()
	if #self.clutterObjects <= 0 then
		return
	end

	for index = #self.clutterObjects, 1, -1 do
		local clutter = self.clutterObjects[index]
		if typeof(clutter) ~= "table" then
			continue
		end

		local objects = clutter.objects
		local lifetime = os.clock() - clutter.createdTimestamp

		if lifetime > config.clutterCleanRate then
			for _, object in pairs(objects) do
				if object:IsA("Beam") then
					coroutine.wrap(function()
						local fadeStartTime = os.clock()
						local transparency = object.Transparency

						while os.clock() - fadeStartTime < 1 do
							local alpha = os.clock() - fadeStartTime
							local keypoints = {}

							for _, keypoint in pairs(transparency.Keypoints) do
								table.insert(
									keypoints,
									NumberSequenceKeypoint.new(
										keypoint.Time,
										math.clamp(keypoint.Value + alpha, 0, 1),
										keypoint.Envelope
									)
								)
							end

							object.Transparency = NumberSequence.new(keypoints)
							runService.RenderStepped:Wait()
						end
						object:Destroy()
					end)()
				else
					object:Destroy()
				end
			end

			table.remove(self.clutterObjects, index)
		end
	end
end

function snowController:castRay(info: { origin: Vector3, direction: Vector3 }): RaycastResult?
	return workspace:Raycast(info.origin, info.direction, raycastParams)
end

function snowController:calculateSkyPosition(): CFrame
	local positions = self.positions
	local skyPosition = positions.sky
	local floorPosition = positions.floor

	local rng = clientRuntime.rng
	local offsetX = rng:NextNumber(-floorPosition.X / 2, floorPosition.X / 2)
	local offsetY = rng:NextNumber(-floorPosition.Y / 2, floorPosition.Y / 2)
	local offsetZ = rng:NextNumber(-floorPosition.Z / 2, floorPosition.Z / 2)

	return CFrame.new(skyPosition) * CFrame.new(offsetX, offsetY, offsetZ)
end

function snowController:cast()
	local stageSettings = currentStage.settings
	local rng = clientRuntime.rng

	local skyAttachment = self:createNewAttachment("sky")
	local floorAttachment = self:createNewAttachment("floor")

	skyAttachment.CFrame = self:calculateSkyPosition()

	local windBias = self.windDirection
	local baseDirection = Vector3.new(
		rng:NextNumber(stageSettings.offset.min, stageSettings.offset.max),
		-1,
		rng:NextNumber(stageSettings.offset.min, stageSettings.offset.max)
	)
	local offsetDirection = baseDirection + windBias

	if offsetDirection.Magnitude == 0 then
		offsetDirection = Vector3.new(0, -1, 0)
	end

	offsetDirection = offsetDirection.Unit * config.raycastRange

	local floorRaycastResult = self:castRay({
		origin = skyAttachment.WorldPosition,
		direction = offsetDirection,
	})

	if floorRaycastResult ~= nil then
		floorAttachment.WorldPosition = floorRaycastResult.Position
		skyAttachment.Orientation = Vector3.zero

		local beamSettings = stageSettings.beam
		local beamTextureId = currentStage.textures[math.random(1, #currentStage.textures)]

		local newBeam = snowParticle:Clone()
		newBeam.Attachment0 = skyAttachment
		newBeam.Attachment1 = floorAttachment

		newBeam.Texture = "rbxassetid://" .. beamTextureId

		newBeam.Width0 = rng:NextNumber(beamSettings.width.min, beamSettings.width.max)
		newBeam.Width1 = newBeam.Width0

		newBeam.CurveSize0 = rng:NextNumber(beamSettings.curve0.min, beamSettings.curve0.max)

		newBeam.TextureSpeed = rng:NextNumber(beamSettings.textureSpeed.min, beamSettings.textureSpeed.max)
		newBeam.TextureLength = rng:NextNumber(beamSettings.textureLength.min, beamSettings.textureLength.max)

		local beamTween = tweenService:Create(
			newBeam,
			TweenInfo.new(rng:NextNumber(stageSettings.tweenDuration.min, stageSettings.tweenDuration.max)),
			{
				CurveSize0 = rng:NextNumber(beamSettings.curve0.min, beamSettings.curve0.max),
				TextureSpeed = rng:NextNumber(beamSettings.textureSpeed.min, beamSettings.textureSpeed.max),
			}
		)

		newBeam.Parent = skyAttachment
		beamTween:Play()

		table.insert(self.clutterObjects, {
			objects = { newBeam, skyAttachment, floorAttachment },
			createdTimestamp = os.clock(),
		})
	else
		skyAttachment:Destroy()
		floorAttachment:Destroy()
	end
end

function snowController:update()
	local stageSettings = currentStage.settings
	local rng = clientRuntime.rng

	local cameraCFrame = currentCamera.CFrame
	local characterRoot = character.PrimaryPart
	local velocity = characterRoot.AssemblyLinearVelocity

	local positions = self.positions
	positions.sky = (cameraCFrame.Position + (velocity * 2)) + Vector3.yAxis * stageSettings.ystuds
	positions.floor = Vector3.new(
		rng:NextInteger(positionConfig.min, positionConfig.max),
		0,
		rng:NextInteger(positionConfig.min, positionConfig.max)
	)

	raycastParams.FilterDescendantsInstances = { character, ignore }

	self:cast()
end

function snowController:initialize()
	local lastUpdateTimestamp = os.clock()

	runService:BindToRenderStep("SnowClient", Enum.RenderPriority.Camera.Value, function()
		self:handleClutter()
		character = player.Character

		if character ~= nil then
			local now = os.clock()
			if (now - lastUpdateTimestamp) > (currentStage.updateRate or 0.1) and self.isActive then
				lastUpdateTimestamp = os.clock()
			else
				return
			end

			self:update()
		end
	end)
end

function snowController.new()
	local self = setmetatable({}, snowController)
	self.isActive = false
	self.clutterObjects = {}
	self.windDirection = Vector3.new(0.25, 0, 0)
	self.positions = {
		sky = Vector3.zero,
		floor = Vector3.zero,
	}

	task.spawn(function()
		self:initialize()
	end)

	return self
end

function snowController:toggle(isEnabled: boolean)
	self.isActive = isEnabled or false
end

function snowController:destroy()
	local clutterObjects = self.clutterObjects
	for _, clutter in pairs(clutterObjects) do
		if typeof(clutter) == "table" then
			for _, object in pairs(clutter.objects) do
				object:Destroy()
			end
		end
	end

	runService:UnbindFromRenderStep("SnowClient")

	table.clear(clutterObjects)
	setmetatable(self, nil)
end

return snowController
