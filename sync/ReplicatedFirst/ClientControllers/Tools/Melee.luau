local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local userInputService = game:GetService("UserInputService")

local player = players.LocalPlayer

local sharedUtilities = replicatedStorage.SharedUtilities
local clientUtilities = replicatedFirst.ClientUtilities

local animationUtilities = require(sharedUtilities.Animation)
local guiUtilities = require(clientUtilities.GuiUtils)
local mathUtilities = require(sharedUtilities.MathUtils)
local mouseController = require(replicatedFirst.ClientControllers.Player.Interface.Mouse)
local haptics = require(replicatedFirst.ClientControllers.Player.Haptics)

local clientData = require(replicatedFirst.ClientData)
local clientConfig = clientData.clientConfig
local movementSpeedPresets = clientConfig.movement.speedPresets

local trackTransitionDurationSeconds = 0.05
local meleeMovementMultiplierKey = "meleeWeapon"
local chargeBarGradientTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local meleeController = {}
meleeController.__index = meleeController
meleeController.__vars = {
	lastSwingChargeAlpha = 0,
}

type MeleeConfig = {
	animations: { [string]: number },
	chargeBarLerpSpeed: number?,
	chargeBarTransparencyThreshold: number,
	chargeDepleteDuration: number?,
	chargeDepleteWaitTime: number?,
	chargeHoldDuration: number?,
	chargeMovementMultiplierMax: number?,
	chargeMovementMultiplierStart: number?,
	chargeMovementPenaltyMax: number?,
	chargeMovementPenaltyStart: number?,
	maxCharge: number,
	swingMovementMultiplier: number?,
	swingMovementPenalty: number?,
	swingMovementRecoveryTime: number?,
}

type ClientEventDetails = {
	isAuthoritativeSync: boolean?,
	isHeavy: boolean?,
	isServerReplication: boolean?,
	isSpecialEquip: boolean?,
	skipAnimation: boolean?,
	chargeAlpha: number?,
	chargeDepleted: boolean?,
}

function meleeController:bindCharacter()
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character and self.character:FindFirstChildOfClass("Humanoid")
	self.animator = self.humanoid and self.humanoid:WaitForChild("Animator", 5)
end

function meleeController:preload()
	self:bindCharacter()

	self.mainRemote = self.tool:WaitForChild("MainRemote", 3)
	self.interface = player.PlayerGui:WaitForChild("Interface", 3)
	self.mobileFrame = self.interface.Mobile
	self.activationButton = self.mobileFrame.ActivateMelee
	self.activationButton.Visible = false
	self.meleeChargeBar = self.interface:WaitForChild("MeleeChargeBar")

	if not self.meleeChargeBar.Visible then
		guiUtilities.changeGuiState({ frame = self.meleeChargeBar, state = false })
		self.meleeChargeBar.Visible = true
	end

	self.mainBarFrame = self.meleeChargeBar:WaitForChild("Bar")
	self.fillFrame = self.mainBarFrame:WaitForChild("Fill")
	self.originalFillSize = self.fillFrame.Size

	self.barLerpSpeed = self.meleeConfig.chargeBarLerpSpeed or 7
	self.barGradient = self.fillFrame:WaitForChild("UIGradient")
	self.originalBarOffset = self.barGradient:GetAttribute("OriginalMeleeChargeOffset") or self.barGradient.Offset
	self.barGradient:SetAttribute("OriginalMeleeChargeOffset", self.originalBarOffset)

	for animationName, animationId in pairs(self.meleeConfig.animations) do
		self.tracks[animationName] = animationUtilities.loadAnimationById(self.animator, animationId, false)
	end
end

function meleeController:stopTrack(track: AnimationTrack?, fadeTime: number?)
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.05)
	end
end

function meleeController:cancelAllTracks()
	for _, track in pairs(self.tracks) do
		track:Stop(0.1)
	end
end

function meleeController:stopTracksExcept(preservedTrack: AnimationTrack, fadeTime: number)
	for _, track in pairs(self.tracks) do
		if track ~= preservedTrack then
			self:stopTrack(track, fadeTime)
		end
	end
end

function meleeController:cancelEquipTracks()
	self:stopTrack(self.tracks.equip)
	self:stopTrack(self.tracks.specialEquip)
end

function meleeController:cancelSwingTracks()
	self:stopTrack(self.tracks.swing)
	self:stopTrack(self.tracks.heavySwing)
end

function meleeController:cancelStarterTracks()
	self:stopTrack(self.tracks.idle)
	self:cancelEquipTracks()
end

function meleeController:stopEquipTracks()
	self:stopTrack(self.tracks.equip)
	self:stopTrack(self.tracks.specialEquip)
	self:stopTrack(self.tracks.swing)
	self:stopTrack(self.tracks.heavySwing)
end

function meleeController:stopTracksForUnequip()
	self:stopTrack(self.tracks.idle)
	self:stopTrack(self.tracks.equip)
	self:stopTrack(self.tracks.specialEquip)
	self:stopTrack(self.tracks.swing)
	self:stopTrack(self.tracks.heavySwing)
end

function meleeController:getUnequipDuration(): number
	local unequipTrack = self.tracks.unequip
	if unequipTrack == nil then
		return 0
	end

	local unequipDuration = animationUtilities.getTrackDuration(unequipTrack)
	if not unequipTrack.IsPlaying then
		return unequipDuration
	end

	return math.max(unequipDuration - unequipTrack.TimePosition, 0)
end

function meleeController:cancelMovementRecovery()
	self.speedRecoveryId += 1
end

function meleeController:getConfiguredMovementMultiplier(
	multiplierKey: string,
	penaltyKey: string,
	fallbackMultiplier: number
): number
	local configuredMultiplier = self.meleeConfig[multiplierKey]
	if type(configuredMultiplier) == "number" then
		return math.clamp(configuredMultiplier, 0, 1)
	end

	local configuredPenalty = self.meleeConfig[penaltyKey]
	if type(configuredPenalty) == "number" then
		local walkingSpeed = math.max(movementSpeedPresets.walking, 0.001)
		return math.clamp(1 - (configuredPenalty / walkingSpeed), 0, 1)
	end

	return fallbackMultiplier
end

function meleeController:setMovementMultiplier(multiplier: number?)
	if multiplier == nil or multiplier >= 1 then
		clientData.speedMultipliers[meleeMovementMultiplierKey] = nil
		return
	end

	clientData.speedMultipliers[meleeMovementMultiplierKey] = math.max(multiplier, 0)
end

function meleeController:clearMovementPenalty()
	self:cancelMovementRecovery()
	self:setMovementMultiplier(nil)
end

function meleeController:applyChargeMovementPenalty(chargeAverage: number)
	local chargeStartMultiplier =
		self:getConfiguredMovementMultiplier("chargeMovementMultiplierStart", "chargeMovementPenaltyStart", 0.875)
	local chargeMaxMultiplier =
		self:getConfiguredMovementMultiplier("chargeMovementMultiplierMax", "chargeMovementPenaltyMax", 0.525)

	self:setMovementMultiplier(
		mathUtilities.lerp(chargeStartMultiplier, chargeMaxMultiplier, math.clamp(chargeAverage, 0, 1))
	)
end

function meleeController:applySwingMovementPenalty()
	self:cancelMovementRecovery()

	local recoveryId = self.speedRecoveryId
	local swingMultiplier = self:getConfiguredMovementMultiplier("swingMovementMultiplier", "swingMovementPenalty", 0.2)
	local recoveryTime = self.meleeConfig.swingMovementRecoveryTime or 0.4

	self:setMovementMultiplier(swingMultiplier)

	task.delay(recoveryTime, function()
		if getmetatable(self) == nil or self.speedRecoveryId ~= recoveryId then
			return
		end

		self:setMovementMultiplier(nil)
	end)
end

function meleeController:resetChargeState(keepVisual: boolean?)
	if self.connections.updateActivation then
		self.connections.updateActivation:Disconnect()
		self.connections.updateActivation = nil
	end
	if self.connections.chargeStartStopped then
		self.connections.chargeStartStopped:Disconnect()
		self.connections.chargeStartStopped = nil
	end
	self:stopChargeHaptics()

	self.chargeStartTime = nil
	self.currentCharge = 0
	self.chargeAverage = 0
	self.subscriptedAverage = 0
	self.gradientCacheAverage = nil

	self:stopTrack(self.tracks.chargeStart, 0.15)
	self:stopTrack(self.tracks.chargeLoop, 0.15)

	clientData.fieldOfViewModifiers.meleeCharge = 0
	mouseController.setCrosshairShake(0)
	mouseController.setCrosshairSpread(1)

	if not keepVisual then
		if self.originalFillSize ~= nil then
			self.fillFrame.Size = self.originalFillSize
		end
		self.barGradient.Offset = Vector2.new(self.originalBarOffset.X - 0.5, self.originalBarOffset.Y)
		self.barGradient.Transparency = chargeBarGradientTransparency
	end

	guiUtilities.changeGuiState({ frame = self.meleeChargeBar, state = false, tweenInfo = TweenInfo.new(0.25) })
end

function meleeController:cleanupCharge()
	self:resetChargeState()
	self:clearMovementPenalty()
end

function meleeController:stopChargeHaptics()
	if self.connections.hapticInputChanged then
		self.connections.hapticInputChanged:Disconnect()
		self.connections.hapticInputChanged = nil
	end

	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics then
		activeHaptics:stopMeleeCharge()
	end
end

function meleeController:getChargeCycleDuration(): number
	return math.max(self.meleeConfig.chargeHoldDuration or 0, 0)
		+ math.max(self.meleeConfig.chargeDepleteWaitTime or 0, 0)
		+ math.max(self.meleeConfig.chargeDepleteDuration or 0, 0)
end

function meleeController:getChargeSnapshot(
	currentTimeSeconds: number?
): { chargeAlpha: number, targetCharge: number, hasDepleted: boolean }
	if self.chargeStartTime == nil then
		return {
			chargeAlpha = 0,
			targetCharge = 0,
			hasDepleted = false,
		}
	end

	local chargeHoldDurationSeconds = math.max(self.meleeConfig.chargeHoldDuration or 0, 0)
	local chargeWaitDurationSeconds = math.max(self.meleeConfig.chargeDepleteWaitTime or 0, 0)
	local chargeDepleteDurationSeconds = math.max(self.meleeConfig.chargeDepleteDuration or 0, 0)
	local elapsedSeconds = math.max((currentTimeSeconds or os.clock()) - self.chargeStartTime, 0)

	local chargeAlpha = 0
	local hasDepleted = false

	if chargeHoldDurationSeconds <= 0 then
		chargeAlpha = 1
	else
		chargeAlpha = math.clamp(elapsedSeconds / chargeHoldDurationSeconds, 0, 1)
	end

	if elapsedSeconds > chargeHoldDurationSeconds then
		if elapsedSeconds <= chargeHoldDurationSeconds + chargeWaitDurationSeconds then
			chargeAlpha = 1
		elseif chargeDepleteDurationSeconds <= 0 then
			chargeAlpha = 0
			hasDepleted = true
		else
			local depleteElapsedSeconds = elapsedSeconds - chargeHoldDurationSeconds - chargeWaitDurationSeconds
			local depleteAlpha = math.clamp(depleteElapsedSeconds / chargeDepleteDurationSeconds, 0, 1)
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

function meleeController:updateChargeHaptics()
	local activeHaptics = haptics.getActiveHaptics()
	if activeHaptics == nil then
		return
	end

	if self.chargeStartTime == nil then
		activeHaptics:stopMeleeCharge()
		return
	end

	activeHaptics:startMeleeCharge({
		chargeDurationSeconds = self.meleeConfig.chargeHoldDuration or 0,
		elapsedSeconds = os.clock() - self.chargeStartTime,
	})
end

function meleeController:connectChargeHaptics()
	if self.connections.hapticInputChanged then
		self.connections.hapticInputChanged:Disconnect()
	end

	self.connections.hapticInputChanged = userInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		self:updateChargeHaptics()
	end)
	self:updateChargeHaptics()
end

function meleeController:onMeleeEvent(eventName: string, eventPayload: ClientEventDetails | string?)
	if eventName == "activate" or eventName == "deactivate" then
		local eventDetails = if type(eventPayload) == "table" then eventPayload else {}

		if eventName == "activate" then
			self:activate(eventDetails)
		else
			self:deactivate(eventDetails)
		end
	end

	if eventName == "hitOnEntity" then
		self:registerHit()
	end

	if eventName == "createHitmarker" then
		local activeHaptics = haptics.getActiveHaptics()
		if activeHaptics then
			activeHaptics:playMeleeImpact(1)
		end

		local damageResult = if type(eventPayload) == "string" then eventPayload else nil
		mouseController.createHitmarker(damageResult)
	end
end

function meleeController:updateChargeBar(deltaTime: number)
	local mainAverage = self.currentCharge / self.meleeConfig.maxCharge
	local uiAlpha = mathUtilities.exponentialAlpha(self.barLerpSpeed, deltaTime)

	self.lerpedChargeAverage = mathUtilities.lerp(self.lerpedChargeAverage or mainAverage, mainAverage, uiAlpha)
	local cachedAverage = self.gradientCacheAverage
	local clampedAverage = math.clamp(self.lerpedChargeAverage, 0, 1)

	if
		cachedAverage
		and math.abs(cachedAverage - clampedAverage) <= self.meleeConfig.chargeBarTransparencyThreshold
	then
		return
	end

	self.gradientCacheAverage = clampedAverage
	self.barGradient.Offset = Vector2.new(self.originalBarOffset.X + clampedAverage - 0.5, self.originalBarOffset.Y)
end

function meleeController:init()
	self:preload()

	self.connections.onMainEvent = self.mainRemote.OnClientEvent:Connect(
		function(eventName: string, eventPayload: ClientEventDetails | string?)
			self:onMeleeEvent(eventName, eventPayload)
		end
	)

	self.mainRemote:FireServer("ready")
end

function meleeController.new(tool: Tool, meleeConfig: MeleeConfig)
	local self = setmetatable({}, meleeController)

	self.tool = tool
	self.meleeConfig = meleeConfig

	self.animationTransitionVersion = 0
	self.lerpedChargeAverage = 0
	self.isEquipped = false
	self.speedRecoveryId = 0
	self.connections = {}
	self.tracks = {}
	self.__vars = table.clone(meleeController.__vars)

	self:init()

	return self
end

function meleeController:registerHit()
	self.character:SetAttribute("Combat", true)
	self.character:SetAttribute("LastCombatTime", os.clock())
end

function meleeController:activate(activationDetails: { isServerReplication: boolean? })
	if activationDetails.isServerReplication then
		self:cancelMovementRecovery()
		self:cancelEquipTracks()
		self:cancelSwingTracks()

		local chargeStartTrack = self.tracks.chargeStart
		self.connections.chargeStartStopped = chargeStartTrack.Stopped:Once(function()
			self.connections.chargeStartStopped = nil

			if self.chargeStartTime ~= nil then
				self.tracks.chargeLoop:Play()
			end
		end)

		chargeStartTrack:Play(0.25, 1, 1 / self.meleeConfig.chargeHoldDuration)

		self.chargeStartTime = os.clock()
		self.lerpedChargeAverage = 0
		self.gradientCacheAverage = nil
		self.currentCharge = 0
		self.chargeAverage = 0
		self.subscriptedAverage = 0
		self:applyChargeMovementPenalty(0)

		self.fillFrame.Size = self.originalFillSize
		self.barGradient.Transparency = chargeBarGradientTransparency
		self.barGradient.Offset = Vector2.new(self.originalBarOffset.X - 0.5, self.originalBarOffset.Y)
		guiUtilities.changeGuiState({ frame = self.meleeChargeBar, state = true, tweenInfo = TweenInfo.new(0.25) })

		if self.connections.updateActivation then
			self.connections.updateActivation:Disconnect()
			self.connections.updateActivation = nil
		end
		self:connectChargeHaptics()

		self.connections.updateActivation = runService.RenderStepped:Connect(function(deltaTime: number)
			local chargeSnapshot = self:getChargeSnapshot()
			self.currentCharge = chargeSnapshot.targetCharge
			self.chargeAverage = chargeSnapshot.chargeAlpha
			self.subscriptedAverage = math.clamp((self.chargeAverage - 0.5) / 0.5, 0, 1) ^ 1.1

			self:applyChargeMovementPenalty(self.chargeAverage)
			clientData.fieldOfViewModifiers.meleeCharge = 6 * self.chargeAverage
			animationUtilities.setTrackWeight(self.tracks.chargeLoop, 0.5 + (0.5 * self.chargeAverage))

			mouseController.setCrosshairShake(self.subscriptedAverage)
			mouseController.setCrosshairSpread(15 * self.chargeAverage)

			self:updateChargeBar(deltaTime)
		end)
	else
		self.mainRemote:FireServer("activate")
	end
end

function meleeController:deactivate(deactivationDetails: {
	isServerReplication: boolean?,
	isHeavy: boolean?,
	chargeDepleted: boolean?,
	chargeAlpha: number?,
})
	if deactivationDetails.isServerReplication then
		local chargeAlpha = math.clamp(deactivationDetails.chargeAlpha or self.chargeAverage or 0, 0, 1)

		if deactivationDetails.chargeDepleted then
			self:cleanupCharge()
		else
			self:resetChargeState(true)
		end

		if not deactivationDetails.chargeDepleted then
			self.__vars.lastSwingChargeAlpha = chargeAlpha

			local activeHaptics = haptics.getActiveHaptics()
			if activeHaptics then
				activeHaptics:playMeleeRelease(chargeAlpha)
			end

			local trackToPlay = deactivationDetails.isHeavy and self.tracks.heavySwing or self.tracks.swing
			trackToPlay:Play(0.1)
			self:applySwingMovementPenalty()
		end
	else
		self.mainRemote:FireServer("deactivate")
	end
end

function meleeController:playIdleAfterEquip(equipTrack: AnimationTrack, transitionVersion: number)
	equipTrack.Stopped:Once(function()
		if self.animationTransitionVersion ~= transitionVersion or not self.isEquipped then
			return
		end

		local idleTrack = self.tracks.idle
		if idleTrack and not idleTrack.IsPlaying then
			idleTrack:Play(trackTransitionDurationSeconds)
		end
	end)
end

function meleeController:beginUnequipAnimation()
	local unequipTrack = self.tracks.unequip
	if unequipTrack == nil then
		self:stopTracksForUnequip()
		return
	end

	if unequipTrack.IsPlaying then
		return
	end

	self.animationTransitionVersion += 1
	unequipTrack:Play(trackTransitionDurationSeconds)
	self:stopTracksExcept(unequipTrack, trackTransitionDurationSeconds)
end

function meleeController:equip(equipDetails: { isSpecialEquip: boolean? }?)
	if self.isEquipped then
		return
	end

	local details = equipDetails or {}
	self.isEquipped = true
	self.animationTransitionVersion += 1
	local transitionVersion = self.animationTransitionVersion

	mouseController.showCrosshairWeaponLines()

	local equipToPlay = details.isSpecialEquip and self.tracks.specialEquip or self.tracks.equip
	if equipToPlay then
		self:playIdleAfterEquip(equipToPlay, transitionVersion)
		equipToPlay:Play(trackTransitionDurationSeconds)
		self:stopTracksExcept(equipToPlay, trackTransitionDurationSeconds)
	elseif self.tracks.idle then
		self.tracks.idle:Play(trackTransitionDurationSeconds)
	end
end

function meleeController:interruptEquip()
	self:unequip()
end

function meleeController:unequip(unequipDetails: { isAuthoritativeSync: boolean?, skipAnimation: boolean? }?)
	local details = unequipDetails or {}

	self.isEquipped = false

	mouseController.hideCrosshairWeaponLines()

	self:cleanupCharge()
	if details.skipAnimation then
		self.animationTransitionVersion += 1
		self:cancelAllTracks()
		return
	end

	self:beginUnequipAnimation()
end

function meleeController:destroy()
	self.isEquipped = false
	self.animationTransitionVersion += 1

	mouseController.hideCrosshairWeaponLines()

	self:cleanupCharge()
	self:cancelAllTracks()

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	guiUtilities.changeGuiState({ frame = self.meleeChargeBar, state = false })
	self.meleeChargeBar.Visible = false

	setmetatable(self, nil)
end

return meleeController
