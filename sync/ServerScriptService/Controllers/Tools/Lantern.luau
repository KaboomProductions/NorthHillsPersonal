local lanternController = {}
lanternController.__index = lanternController

local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local remoteGuard = require(game:GetService("ServerStorage").ServerUtilities.RemoteGuard)

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local effects = sharedAssets.Effects
local sounds = effects.Sounds
local toolSounds = sounds.Tools
local lanternSounds = toolSounds.Lantern

local audioUtilities = require(sharedUtilities.AudioUtils)
local autoRigUtility = require(serverStorage.ServerUtilities.AutoRig)
local itemUtilities = require(sharedUtilities.ItemUtils)

local attributeConstants = require(sharedAssets.Attributes)
local toolAttributes = attributeConstants.tool

local swingingAssemblyDensity = 0.01

local function getSwingingAssembly(tool: Instance): (BasePart?, HingeConstraint?)
	local base = tool:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		return nil, nil
	end

	return base, base:FindFirstChildOfClass("HingeConstraint")
end

local function prepareSwingingAssembly(tool: Instance)
	local base, hinge = getSwingingAssembly(tool)
	if not base then
		return
	end

	local properties = base.CurrentPhysicalProperties
	base.CustomPhysicalProperties = PhysicalProperties.new(
		swingingAssemblyDensity,
		properties.Friction,
		properties.Elasticity,
		properties.FrictionWeight,
		properties.ElasticityWeight
	)

	if hinge then
		hinge.Enabled = false
	end
end

local function positionSwingingAssembly(tool: Instance): (BasePart?, HingeConstraint?)
	local base, hinge = getSwingingAssembly(tool)
	if not base or not hinge then
		return nil, nil
	end

	local attachment0 = hinge.Attachment0
	local attachment1 = hinge.Attachment1
	if not attachment0 or not attachment1 then
		return nil, nil
	end

	local baseAttachment = if attachment0:IsDescendantOf(base) then attachment0 else attachment1
	local targetAttachment = if baseAttachment == attachment0 then attachment1 else attachment0
	base.CFrame = targetAttachment.WorldCFrame * baseAttachment.CFrame:Inverse()
	base.AssemblyLinearVelocity = Vector3.zero
	base.AssemblyAngularVelocity = Vector3.zero

	return base, hinge
end

function lanternController:cacheEffects()
	self.effects = {}

	for _, descendant in ipairs(self.tool:GetDescendants()) do
		if descendant:IsA("Light") then
			table.insert(self.effects, descendant)
		end
	end
end

function lanternController:preload()
	prepareSwingingAssembly(self.tool)

	self.mainRemote = Instance.new("RemoteEvent")
	self.mainRemote.Name = "MainRemote"
	self.mainRemote.Parent = self.tool

	self.handle = self.tool:FindFirstChild("Handle")
	self.light = self.tool:FindFirstChild("Light")
	self.lightAppearance = self.light:FindFirstChild("SurfaceAppearance")

	self.tool:GetAttribute(toolAttributes.toggled, false)

	self:cacheEffects()
	self:registerToggle()
end

function lanternController:playSound(newSound, pitch)
	self:stopActiveSound()

	if not newSound then
		return
	end

	self.activeSound = audioUtilities.playSound({
		sound = newSound,
		volume = newSound.Volume,
		parent = self.handle,
		playbackSpeed = pitch,
	})
end

function lanternController:stopActiveSound()
	audioUtilities.stopSound(self.activeSound)
	self.activeSound = nil
end

function lanternController:cleanupRigArtifacts()
	for _, descendant in ipairs(self.character:GetDescendants()) do
		if descendant == self.tool then
			continue
		end

		if itemUtilities.isRigArtifact(descendant, self.tool.Name) then
			descendant:Destroy()
		end
	end
end

function lanternController:onMainEvent(event: string)
	if event == "activate" then
		self:activate()
	elseif event == "activateSilent" then
		self:activateSilent()
	end
end

function lanternController:init()
	self:preload()
	self.isEquipping = false

	self.connections.onMainEvent = self.mainRemote.OnServerEvent:Connect(function(eventPlayer: Player, event: string)
		if
			eventPlayer ~= self.player
			or typeof(event) ~= "string"
			or (event ~= "activate" and event ~= "activateSilent")
			or not remoteGuard.allow(eventPlayer, "lightToggle", 8, 1)
		then
			return
		end

		self:onMainEvent(event)
	end)
end

function lanternController:cancelToggleTweens()
	for _, tween in self.toggleTweens do
		tween:Cancel()
		tween:Destroy()
	end

	table.clear(self.toggleTweens)
end

function lanternController:registerToggle()
	self:cancelToggleTweens()

	self:playSound(self.tool:GetAttribute(toolAttributes.toggled) and lanternSounds.On or lanternSounds.Off)

	for _, object in self.effects do
		if not object:GetAttribute("Brightness") then
			object:SetAttribute("Brightness", object.Brightness)
		end

		if not object.Enabled then
			object.Brightness = 0
			object.Enabled = true
		end

		table.insert(
			self.toggleTweens,
			tweenService:Create(object, TweenInfo.new(0.1), {
				Brightness = self.tool:GetAttribute(toolAttributes.toggled) and object:GetAttribute("Brightness") or 0,
			})
		)
	end

	table.insert(
		self.toggleTweens,
		tweenService:Create(self.lightAppearance, TweenInfo.new(0.1), {
			EmissiveStrength = self.tool:GetAttribute(toolAttributes.toggled) and 40 or 0,
		})
	)

	for _, tween in self.toggleTweens do
		tween:Play()
	end
end

function lanternController.new(player, character, tool, config)
	local self = setmetatable({}, lanternController)

	self.tool = tool
	self.player = player
	self.character = character

	self.config = config
	self.connections = {}
	self.effects = {}
	self.toggleTweens = {}

	self:init()

	return self
end

function lanternController:activate()
	if self.isEquipping then
		return
	end

	if not self.tool:GetAttribute(toolAttributes.equipped) then
		return
	end

	self.tool:SetAttribute(toolAttributes.toggled, not self.tool:GetAttribute(toolAttributes.toggled))

	self:registerToggle()
end

function lanternController:activateSilent()
	if self.isEquipping then
		return
	end

	if not self.tool:GetAttribute(toolAttributes.equipped) then
		return
	end

	self.tool:SetAttribute(toolAttributes.toggled, not self.tool:GetAttribute(toolAttributes.toggled))

	self:registerToggle()
end

function lanternController:equip()
	if self.isEquipping then
		return
	end

	self.isEquipping = true

	if self.tool.Parent ~= self.character then
		self.isEquipping = false
		return
	end
	prepareSwingingAssembly(self.tool)

	self.tool:SetAttribute(toolAttributes.equipped, true)
	self.tool:SetAttribute(toolAttributes.toggled, false)
	self:registerToggle()

	self:cleanupRigArtifacts()

	self:playSound(lanternSounds.Equip)

	if self.config and self.config.rigging then
		autoRigUtility.rig({
			tool = self.tool,
			config = self.config.rigging,
			character = self.character,
		})
	end

	local swingingBase, hinge = positionSwingingAssembly(self.tool)
	if swingingBase and hinge then
		task.spawn(function()
			runService.Heartbeat:Wait()
			task.wait(0.1)
			if getmetatable(self) == nil or self.tool.Parent ~= self.character then
				return
			end
			local updatedSwingingBase, updatedHinge = positionSwingingAssembly(self.tool)
			if updatedSwingingBase and updatedHinge then
				updatedHinge.Enabled = true
			end
		end)
	end

	self.isEquipping = false
end

function lanternController:unequip()
	self.tool:SetAttribute(toolAttributes.equipped, false)
	self.tool:SetAttribute(toolAttributes.toggled, false)

	self:playSound(lanternSounds.Unequip)

	self:registerToggle()
end

function lanternController:destroy()
	self:stopActiveSound()
	self.tool:SetAttribute(toolAttributes.equipped, false)
	self.tool:SetAttribute(toolAttributes.toggled, false)
	self:registerToggle()

	--// The final off-tween is still playing; releasing the handles immediately would freeze the lights on.
	local finishingTweens = self.toggleTweens
	self.toggleTweens = {}
	task.delay(0.2, function()
		for _, finishingTween in finishingTweens do
			finishingTween:Cancel()
			finishingTween:Destroy()
		end
	end)

	if self.character ~= nil then
		self:cleanupRigArtifacts()
	end

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	setmetatable(self, nil)
end

return lanternController
