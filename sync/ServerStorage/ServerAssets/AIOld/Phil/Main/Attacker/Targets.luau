local targetAttackerController = {}
targetAttackerController.__index = targetAttackerController

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local sharedUtilities = replicatedStorage.SharedUtilities
local communication = replicatedStorage.Communication

local networking = require(communication.Networking)
local audioUtilities = require(sharedUtilities.AudioUtils)
local statusEffectsController = require(serverScriptService.Controllers.StatusEffects)

function targetAttackerController:applyKnockback(targetToHit)
	local targetAgent = targetToHit.agent
	local targetRoot = targetToHit.root
	local targetTorso = targetAgent and targetAgent:FindFirstChild("Torso")

	if not targetTorso then
		return
	end

	local facingDirection = self.rootPart.CFrame.LookVector
	facingDirection = Vector3.new(facingDirection.X, 0, facingDirection.Z).Unit

	local knockbackVelocity = (facingDirection * self.combatConfig.pushKnockbackForce)
		+ Vector3.new(0, self.combatConfig.pushKnockbackLift, 0)

	local attachment = targetRoot:FindFirstChild("RootAttachment")
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "KnockbackVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = knockbackVelocity
	linearVelocity.Parent = targetRoot

	task.delay(self.combatConfig.pushKnockbackDuration, function()
		if linearVelocity.Parent then
			linearVelocity:Destroy()
		end
	end)
end

function targetAttackerController.new(ancestorInfo)
	local self = setmetatable({}, targetAttackerController)

	self.ancestor = ancestorInfo
	self.connections = self.ancestor.connections
	self.sharedConfig = self.ancestor.sharedConfig
	self.combatConfig = self.ancestor.combatConfig

	self.lightAttackTracks = self.ancestor.lightAttackTracks
	self.heavyAttackTracks = self.ancestor.heavyAttackTracks
	self.pushTracks = self.ancestor.pushTracks

	self.swingSounds = self.ancestor.swingSounds
	self.lightHitSounds = self.ancestor.lightHitSounds
	self.heavyHitSounds = self.ancestor.heavyHitSounds

	self.primaryPushSounds = self.ancestor.primaryPushSounds
	self.secondaryPushSounds = self.ancestor.secondaryPushSounds

	self.controller = self.ancestor.controller
	self.agent = self.ancestor.agent
	self.rootPart = self.ancestor.rootPart

	return self
end

function targetAttackerController:cancelAttack(isMain: boolean?)
	if self.currentTrack and not isMain then
		self.currentTrack:Stop(0.1)
	end

	if self.connections.onSwing then
		self.connections.onSwing:Disconnect()
		self.connections.onSwing = nil
	end

	self.agent:SetAttribute("Attacking", false)
	self.controller:recordActionTime("attack")
end

function targetAttackerController:handleOnSwing(isHeavyAttack: boolean, isCrowdControl: boolean)
	local controller = self.controller
	local targetingController = controller.targeting

	local combatConfig = self.combatConfig
	local minimumDamage = isHeavyAttack and combatConfig.heavyDamageMinimum or combatConfig.lightDamageMinimum
	local maximumDamage = isHeavyAttack and combatConfig.heavyDamageMaximum or combatConfig.lightDamageMaximum

	local targetToHit = targetingController:getNearestTarget({
		range = self.sharedConfig.ranges.attack,
		canRaycast = true,
		overrideCurrentTarget = false,
	})

	if targetToHit ~= nil and not targetToHit.isRagdolled then
		local currentRagdollTimer = targetToHit.agent:GetAttribute("RagdollTimer") or 0
		local hitSounds = isHeavyAttack and self.heavyHitSounds or self.lightHitSounds
		local attackDamage = not isCrowdControl
				and (self.agent:GetAttribute("Sneaking") and targetToHit.humanoid.MaxHealth * 2 or math.random(
					minimumDamage,
					maximumDamage
				))
			or combatConfig.pushDamage

		if not isCrowdControl or (isCrowdControl and targetToHit.humanoid.Health > attackDamage) then
			targetToHit.humanoid:TakeDamage(attackDamage)
		end

		if isCrowdControl then
			targetToHit.agent:SetAttribute("RagdollTimer", currentRagdollTimer + combatConfig.pushRagdollTime)

			self:applyKnockback(targetToHit)

			audioUtilities.playSound({
				sound = self.primaryPushSounds[math.random(1, #self.primaryPushSounds)],
				parent = targetToHit.root,
			})

			audioUtilities.playSound({
				sound = self.secondaryPushSounds[math.random(1, #self.secondaryPushSounds)],
				parent = targetToHit.root,
			})
		else
			audioUtilities.playSound({
				sound = hitSounds[math.random(1, #hitSounds)],
				parent = targetToHit.root,
			})
		end

		networking.events.generic:FireClient(targetToHit.player, "damage")

		controller:setFlag("rushInterruptedByHit", true)

		if isHeavyAttack and targetToHit.humanoid.Health > 0 then
			statusEffectsController.apply(targetToHit.agent, "Bleeding")
		end
	else
		if self.agent:GetAttribute("Sneaking") then
			controller.stateMachine:change(controller.states.Running, {
				runAndScream = true,
			})
		end
	end

	self:cancelAttack(true)
end

function targetAttackerController:performAttack()
	local controller = self.controller
	local targetingController = controller.targeting

	local isCrowdControl = self.agent:GetAttribute("CrowdControl")
	local canHeavyAttack = not isCrowdControl and math.random(1, 10) <= 2
	local attackTracks = canHeavyAttack and self.heavyAttackTracks or self.lightAttackTracks

	local targetToAttack = targetingController:getNearestTarget({
		range = self.sharedConfig.ranges.attack * (isCrowdControl and 2 or 1),
		canRaycast = true,
		overrideCurrentTarget = false,
	})

	if targetToAttack ~= nil and (targetToAttack.agent and not targetToAttack.agent:GetAttribute("Ragdolled")) then
		self.agent:SetAttribute("Attacking", true)

		self.currentTrack = not isCrowdControl and attackTracks[math.random(1, #attackTracks)] or self.pushTracks[1]
		self.currentTrack:Play(0.1, 5)
		self.currentTrack:AdjustSpeed(math.random(900, 1100) / 1000)

		audioUtilities.playSound({
			sound = self.swingSounds[math.random(1, #self.swingSounds)],
			parent = self.rootPart,
		})

		self.connections.onSwing = self.currentTrack:GetMarkerReachedSignal("Swing"):Once(function()
			self:handleOnSwing(canHeavyAttack, isCrowdControl)
		end)
	end
end

function targetAttackerController:update(_deltaTime: number)
	if self.controller:canAttack() then
		self:performAttack()
	end
end

function targetAttackerController:destroy()
	setmetatable(self, nil)
end

return targetAttackerController
