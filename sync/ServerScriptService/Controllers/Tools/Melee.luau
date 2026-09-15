local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities
local sharedClasses = replicatedStorage.SharedClasses

local hitboxUtility = require(sharedClasses.Hitbox)
local audioUtilities = require(sharedUtilities.AudioUtils)
local autoRigUtility = require(serverStorage.ServerUtilities.AutoRig)
local itemUtilities = require(sharedUtilities.ItemUtils)

local attributeConstants = require(sharedAssets.Attributes)
local toolAttributes = attributeConstants.tool

local effects = sharedAssets.Effects
local sounds = effects.Sounds
local toolSounds = sounds.Tools

local components = workspace.Components
local entities = components.Entities

local meleeController = {}
meleeController.__index = meleeController

type MeleeConfig = {
	chargeDepleteDuration: number?,
	chargeDepleteWaitTime: number?,
	chargeHoldDuration: number?,
	cooldownTime: number,
	damage: {
		min: number,
		max: number,
	},
	heavySwingThreshold: number?,
	hitboxDelayTime: number,
	hitboxSize: Vector3,
	rigging: { [string]: unknown }?,
	swingLastingTime: number,
	maxCharge: number?,
}

function meleeController:preload()
	self.mainRemote = Instance.new("RemoteEvent")
	self.mainRemote.Name = "MainRemote"
	self.mainRemote.Parent = self.tool

	self.handle = self.tool:FindFirstChild("Handle")
	self.trailEffect = self.handle:FindFirstChild("Trail")
	self.sounds = toolSounds:FindFirstChild(self.tool.Name)

	self.overlapParams = OverlapParams.new()
	self.overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	self.overlapParams.RespectCanCollide = true
end

function meleeController:playSound(newSound, pitch)
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

function meleeController:stopActiveSound()
	audioUtilities.stopSound(self.activeSound)
	self.activeSound = nil
end

function meleeController:cleanupRigArtifacts()
	for _, descendant in ipairs(self.character:GetDescendants()) do
		if descendant == self.tool then
			continue
		end

		if itemUtilities.isRigArtifact(descendant, self.tool.Name) then
			descendant:Destroy()
		end
	end
end

function meleeController:cleanupCharging()
	if self.connections.updateCharge then
		self.connections.updateCharge:Disconnect()
		self.connections.updateCharge = nil
	end

	self.chargeTimerId += 1

	self:stopActiveSound()

	self.isCharging = false
	self.stateStartTime = nil

	self.tool:SetAttribute("Charging", false)
	self.tool:SetAttribute("ChargeStrength", 0)
end

function meleeController:getChargeCycleDuration(): number
	return math.max(self.meleeConfig.chargeHoldDuration or 0, 0)
		+ math.max(self.meleeConfig.chargeDepleteWaitTime or 0, 0)
		+ math.max(self.meleeConfig.chargeDepleteDuration or 0, 0)
end

function meleeController:getChargeSnapshot(
	now: number?
): { chargeAlpha: number, targetCharge: number, hasDepleted: boolean }
	if self.stateStartTime == nil then
		return {
			chargeAlpha = 0,
			targetCharge = 0,
			hasDepleted = false,
		}
	end

	local holdDuration = math.max(self.meleeConfig.chargeHoldDuration or 0, 0)
	local waitDuration = math.max(self.meleeConfig.chargeDepleteWaitTime or 0, 0)
	local depleteDuration = math.max(self.meleeConfig.chargeDepleteDuration or 0, 0)
	local elapsed = math.max((now or os.clock()) - self.stateStartTime, 0)

	local chargeAlpha = 0
	local hasDepleted = false

	if holdDuration <= 0 then
		chargeAlpha = 1
	else
		chargeAlpha = math.clamp(elapsed / holdDuration, 0, 1)
	end

	if elapsed > holdDuration then
		if elapsed <= holdDuration + waitDuration then
			chargeAlpha = 1
		elseif depleteDuration <= 0 then
			chargeAlpha = 0
			hasDepleted = true
		else
			local depleteElapsed = elapsed - holdDuration - waitDuration
			local depleteAlpha = math.clamp(depleteElapsed / depleteDuration, 0, 1)
			chargeAlpha = 1 - depleteAlpha
			hasDepleted = depleteAlpha >= 1
		end
	end

	return {
		chargeAlpha = chargeAlpha,
		targetCharge = chargeAlpha * (self.meleeConfig.maxCharge or 0),
		hasDepleted = hasDepleted,
	}
end

function meleeController:onMainEvent(event: string)
	if event == "activate" then
		self:activate()
	elseif event == "deactivate" then
		self:deactivate()
	end
end

function meleeController:dealDamage(humanoid: Humanoid, isHeavySwing: boolean)
	local character = self.character
	local primaryPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")

	local damageResult = nil
	local damageSettings = self.meleeConfig.damage
	local minDamage = damageSettings.min
	local maxDamage = damageSettings.max

	local chargeAlpha = self.chargeAlpha or 0
	local subscriptAlpha = chargeAlpha ^ 1.5
	local newDamage = minDamage + (maxDamage - minDamage) * subscriptAlpha

	local agent = humanoid:FindFirstAncestorOfClass("Model")
	local takeDamageFunction = agent:FindFirstChild("TakeDamage")

	if takeDamageFunction then
		damageResult = takeDamageFunction:Invoke({
			eventType = "melee",
			cframe = primaryPart.CFrame,
			damage = newDamage,
			player = self.player,
			isHeavyAttack = isHeavySwing,
		})

		self.mainRemote:FireClient(self.player, "hitOnEntity")
	else
		humanoid:TakeDamage(newDamage)
	end

	if not self.hitSounds and self.sounds:FindFirstChild("Hits") then
		self.hitSounds = self.sounds.Hits:GetChildren()
	end

	if self.hitSounds and damageResult ~= "blocked" then
		local newHitSound = self.hitSounds[math.random(1, #self.hitSounds)]

		audioUtilities.playSound({
			sound = newHitSound,
			volume = newHitSound.Volume,
			parent = agent.PrimaryPart or self.handle,
		})
	end

	self.mainRemote:FireClient(self.player, "createHitmarker", damageResult)
end

function meleeController:createHitbox()
	self.overlapParams.FilterDescendantsInstances = { self.character }

	local newHitbox = hitboxUtility.CreateHitbox()
	newHitbox.Visualizer = false
	newHitbox.OverlapParams = self.overlapParams
	newHitbox.Size = self.meleeConfig.hitboxSize
	newHitbox.CFrame = self.rootPart
	newHitbox.Offset = CFrame.new(0, 0, -newHitbox.Size.Z / 2)
	newHitbox:Start()

	self.currentHitbox = newHitbox
end

local function cancelScheduledThread(scheduledThread: thread?)
	if scheduledThread == nil or coroutine.running() == scheduledThread then
		return
	end
	if coroutine.status(scheduledThread) ~= "dead" then
		task.cancel(scheduledThread)
	end
end

function meleeController:cancelSwing()
	self.swingGeneration = (self.swingGeneration or 0) + 1
	self.trailEffect.Enabled = false

	if self.connections.hitboxTouched then
		self.connections.hitboxTouched:Disconnect()
		self.connections.hitboxTouched = nil
	end

	if self.currentHitbox then
		self.currentHitbox:Destroy()
		self.currentHitbox = nil
	end

	--// task.delay handles are suspended rather than running, so a status check alone would never cancel them.
	cancelScheduledThread(self.swingThread)
	self.swingThread = nil
	cancelScheduledThread(self.swingEndThread)
	self.swingEndThread = nil
end

function meleeController:registerSwing(isHeavySwing: boolean)
	self:cancelSwing()
	local swingGeneration = self.swingGeneration

	self.trailEffect.Enabled = true
	self:playSound(self.sounds and self.sounds:FindFirstChild("Swing"), math.random(900, 1100) / 1000)

	self.swingThread = task.delay(self.meleeConfig.hitboxDelayTime, function()
		self.swingThread = nil
		if self.swingGeneration ~= swingGeneration or getmetatable(self) == nil then
			return
		end

		self:createHitbox()

		self.connections.hitboxTouched = self.currentHitbox.Touched:Connect(function(hit: BasePart, humanoid: Humanoid)
			if self.swingGeneration ~= swingGeneration or not hit:IsDescendantOf(entities) then
				return
			end

			if humanoid then
				self:dealDamage(humanoid, isHeavySwing)
			end
		end)

		self.swingEndThread = task.delay(self.meleeConfig.swingLastingTime, function()
			self.swingEndThread = nil
			if self.swingGeneration == swingGeneration and self.cancelSwing then
				self:cancelSwing()
			end
		end)
	end)
end

function meleeController:init()
	self:preload()

	self.connections.onMainEvent = self.mainRemote.OnServerEvent:Connect(function(eventPlayer: Player, event: string)
		if eventPlayer ~= self.player then
			return
		end

		self:onMainEvent(event)
	end)
end

function meleeController.new(player: Player, character: Model, tool: Tool, meleeConfig: MeleeConfig)
	local self = setmetatable({}, meleeController)

	self.tool = tool
	self.player = player
	self.character = character

	self.humanoid = self.character and self.character:FindFirstChildOfClass("Humanoid")
	self.rootPart = self.humanoid and self.humanoid.RootPart or self.character.PrimaryPart

	self.meleeConfig = meleeConfig
	self.connections = {}
	self.chargeTimerId = 0
	self.swingGeneration = 0
	self.swingThread = nil
	self.swingEndThread = nil

	self:init()

	return self
end

function meleeController:activate()
	if self.isActivated or self.player:GetAttribute("MeleeCooldown") or self.isCharging then
		return
	end

	self.isActivated = true
	self.isCharging = true

	self.tool:SetAttribute("Charging", true)
	self.tool:SetAttribute("ChargeStrength", 0)

	self.stateStartTime = os.clock()
	self.chargeTimerId += 1
	local chargeTimerId = self.chargeTimerId
	local chargeCycleDuration = self:getChargeCycleDuration()

	self:playSound(self.sounds and self.sounds:FindFirstChild("Charge"))

	task.spawn(function()
		while self.tool:GetAttribute("Charging") do
			task.wait(1 / 10)

			self.tool:SetAttribute("ChargeStrength", self:getChargeSnapshot().chargeAlpha)
		end
	end)

	task.delay(chargeCycleDuration, function()
		if getmetatable(self) == nil or self.chargeTimerId ~= chargeTimerId or not self.isCharging then
			return
		end

		self:deactivate({
			chargeDepleted = true,
		})
	end)

	self.mainRemote:FireClient(self.player, "activate", { isServerReplication = true })
end

function meleeController:deactivate(deactivationDetails: { chargeDepleted: boolean? }?)
	local isChargeDepleted = deactivationDetails ~= nil and deactivationDetails.chargeDepleted == true

	if not self.isActivated or self.player:GetAttribute("MeleeCooldown") or not self.isCharging then
		return
	end

	self.player:SetAttribute("MeleeCooldown", true)
	self.isActivated = false
	local chargeSnapshot = self:getChargeSnapshot()
	self.chargeAlpha = chargeSnapshot.chargeAlpha
	self:cleanupCharging()

	local chargeAlpha = chargeSnapshot.chargeAlpha
	local canHeavySwing = chargeAlpha > (self.meleeConfig.heavySwingThreshold or 0.75)

	if not isChargeDepleted then
		self:registerSwing(canHeavySwing)
	end

	self.mainRemote:FireClient(self.player, "deactivate", {
		isServerReplication = true,
		isHeavy = canHeavySwing,
		chargeDepleted = isChargeDepleted,
		chargeAlpha = chargeAlpha,
	})

	task.delay(self.meleeConfig.cooldownTime, function()
		self.player:SetAttribute("MeleeCooldown", false)
	end)
end

function meleeController:prepareEquip()
	local shouldSpecialEquip = math.random(1, 10) == 1
	self.currentEquipInfo = { isSpecialEquip = shouldSpecialEquip }
	self.tool:SetAttribute(toolAttributes.specialEquip, shouldSpecialEquip)
end

function meleeController:equip()
	if self.tool.Parent ~= self.character then
		return
	end

	if self.currentEquipInfo == nil then
		self:prepareEquip()
	end
	local shouldSpecialEquip = self.currentEquipInfo.isSpecialEquip

	self.tool:SetAttribute(toolAttributes.equipped, true)
	self:cleanupRigArtifacts()

	if self.meleeConfig.rigging then
		autoRigUtility.rig({
			tool = self.tool,
			config = self.meleeConfig.rigging,
			character = self.character,
		})
	end

	local equipSound = shouldSpecialEquip and self.sounds:FindFirstChild("SpecialEquip")
		or self.sounds:FindFirstChild("Equip")
	self:playSound(equipSound)
end

function meleeController:unequip()
	self.tool:SetAttribute(toolAttributes.equipped, false)
	self.tool:SetAttribute(toolAttributes.specialEquip, nil)
	self.isActivated = false

	self:cleanupCharging()
	self:cancelSwing()
	self:playSound(self.sounds and self.sounds:FindFirstChild("Unequip"))
end

function meleeController:destroy()
	self:cleanupCharging()
	self:cancelSwing()
	self:stopActiveSound()
	self.tool:SetAttribute(toolAttributes.equipped, false)
	self.tool:SetAttribute(toolAttributes.specialEquip, nil)
	self.player:SetAttribute("MeleeCooldown", false)
	self.tool:SetAttribute("Charging", false)
	self.tool:SetAttribute("ChargeStrength", 0)

	if self.character ~= nil then
		self:cleanupRigArtifacts()
	end

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	if self.mainRemote then
		self.mainRemote:Destroy()
		self.mainRemote = nil
	end

	setmetatable(self, nil)
end

return meleeController
