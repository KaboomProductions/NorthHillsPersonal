local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")

local hapticConfig = require(script.Config)
local waveformUtilities = require(script.WaveformUtils)

local CharacterFeedback = require(script.CharacterFeedback)
local EffectPlayer = require(script.EffectPlayer)

local player = players.LocalPlayer

type HapticChannel =
	"camera"
	| "chaseAmbient"
	| "chaseImpulse"
	| "damage"
	| "health"
	| "interface"
	| "meleeCharge"
	| "meleeImpulse"
	| "movement"
	| "stamina"
	| "staminaImpulse"
	| "tool"

local cameraChannel: HapticChannel = "camera"
local chaseAmbientChannel: HapticChannel = "chaseAmbient"
local chaseImpulseChannel: HapticChannel = "chaseImpulse"
local damageChannel: HapticChannel = "damage"
local healthChannel: HapticChannel = "health"
local interfaceChannel: HapticChannel = "interface"
local meleeChargeChannel: HapticChannel = "meleeCharge"
local meleeImpulseChannel: HapticChannel = "meleeImpulse"
local movementChannel: HapticChannel = "movement"
local staminaChannel: HapticChannel = "stamina"
local staminaImpulseChannel: HapticChannel = "staminaImpulse"
local toolChannel: HapticChannel = "tool"

local haptics = {}
haptics.__index = haptics
haptics.__vars = {
	healthUrgency = 0,
	staminaUrgency = 0,
	chaseUrgency = 0,
	chaseIntensityMultiplier = 1,
	isLowHealthActive = false,
	isLowStaminaActive = false,
	isChaseActive = false,
	isMeleeChargeActive = false,
}

local activeHaptics: typeof(haptics)? = nil

function haptics:isHapticInputActive(): boolean
	local preferredInput = userInputService.PreferredInput

	return preferredInput == Enum.PreferredInput.Gamepad or preferredInput == Enum.PreferredInput.Touch
end

function haptics:isGameplayHapticsActive(): boolean
	return player:GetAttribute("InMenu") ~= true
end

function haptics:refreshLowHealthHaptics()
	local stateValues = self.__vars
	if
		not stateValues.isLowHealthActive
		or stateValues.isMeleeChargeActive
		or not self:isGameplayHapticsActive()
	then
		self.effectPlayer:setLoopedChannelWaveform(healthChannel, nil, nil)
		return
	end

	local urgency = waveformUtilities.quantizeUrgency(stateValues.healthUrgency)
	self.effectPlayer:setLoopedChannelWaveform(healthChannel, waveformUtilities.createLowHealth(urgency), urgency)
end

function haptics:refreshLowStaminaHaptics()
	local stateValues = self.__vars
	if
		not stateValues.isLowStaminaActive
		or stateValues.isMeleeChargeActive
		or not self:isGameplayHapticsActive()
	then
		self.effectPlayer:setLoopedChannelWaveform(staminaChannel, nil, nil)
		return
	end

	local urgency = waveformUtilities.quantizeUrgency(stateValues.staminaUrgency)
	self.effectPlayer:setLoopedChannelWaveform(staminaChannel, waveformUtilities.createLowStamina(urgency), urgency)
end

function haptics:refreshChaseHaptics()
	local stateValues = self.__vars
	if not stateValues.isChaseActive or stateValues.isMeleeChargeActive or not self:isGameplayHapticsActive() then
		self.effectPlayer:setLoopedChannelWaveform(chaseAmbientChannel, nil, nil)
		return
	end

	local urgency = waveformUtilities.quantizeUrgency(stateValues.chaseUrgency)
	local intensityMultiplier = stateValues.chaseIntensityMultiplier
	local waveformSignature = urgency + intensityMultiplier * 10

	self.effectPlayer:setLoopedChannelWaveform(
		chaseAmbientChannel,
		waveformUtilities.createChase(urgency, intensityMultiplier),
		waveformSignature
	)
end

function haptics:refreshPersistentHaptics()
	self:refreshLowHealthHaptics()
	self:refreshLowStaminaHaptics()
	self:refreshChaseHaptics()
end

function haptics:setLowHealthUrgency(urgency: number)
	local stateValues = self.__vars
	stateValues.healthUrgency = urgency
	stateValues.isLowHealthActive = true
	self:refreshLowHealthHaptics()
end

function haptics:clearLowHealth()
	local stateValues = self.__vars
	stateValues.healthUrgency = 0
	stateValues.isLowHealthActive = false
	self:refreshLowHealthHaptics()
end

function haptics:setLowStaminaUrgency(urgency: number)
	local stateValues = self.__vars
	stateValues.staminaUrgency = urgency
	stateValues.isLowStaminaActive = true
	self:refreshLowStaminaHaptics()
end

function haptics:clearLowStamina()
	local stateValues = self.__vars
	stateValues.staminaUrgency = 0
	stateValues.isLowStaminaActive = false
	self:refreshLowStaminaHaptics()
end

function haptics:onPreferredInputChanged()
	if not self:isHapticInputActive() then
		self.effectPlayer:stopAllChannels()
		return
	end

	self.effectPlayer:invalidateLoopSignatures()
	self:refreshPersistentHaptics()
end

function haptics.getActiveHaptics(): typeof(haptics)?
	return activeHaptics
end

function haptics:playUiHover()
	self.effectPlayer:playChannelWaveform(interfaceChannel, waveformUtilities.createUiHover())
end

function haptics:playUiClick()
	self.effectPlayer:playChannelWaveform(interfaceChannel, waveformUtilities.createUiClick())
end

function haptics:playSliderStep(valueAlpha: number)
	self.effectPlayer:playChannelWaveform(interfaceChannel, waveformUtilities.createSliderStep(valueAlpha))
end

function haptics:playSliderBoundary()
	self.effectPlayer:playChannelWaveform(interfaceChannel, waveformUtilities.createSliderBoundary())
end

function haptics:playHotbarSelection()
	self.effectPlayer:playChannelWaveform(interfaceChannel, waveformUtilities.createHotbarSelection())
end

function haptics:playPerspectiveChange()
	self.effectPlayer:playChannelWaveform(cameraChannel, waveformUtilities.createPerspectiveChange())
end

function haptics:playToolToggle()
	self.effectPlayer:playChannelWaveform(toolChannel, waveformUtilities.createToolToggle())
end

function haptics:playMovementTransition(movementName: "sprint" | "crouch")
	if not self:isGameplayHapticsActive() then
		return
	end

	self.effectPlayer:playChannelWaveform(movementChannel, waveformUtilities.createMovementTransition(movementName))
end

function haptics:playStaminaDepleted()
	if not self:isGameplayHapticsActive() then
		return
	end

	self.effectPlayer:playChannelWaveform(staminaImpulseChannel, waveformUtilities.createStaminaDepleted())
end

function haptics:playDamage(damageAmount: number, maximumHealth: number)
	self.effectPlayer:playChannelWaveform(damageChannel, waveformUtilities.createDamage(damageAmount, maximumHealth))
end

function haptics:startMeleeCharge(chargeInfo: waveformUtilities.MeleeChargeInfo)
	local stateValues = self.__vars
	if not stateValues.isMeleeChargeActive then
		stateValues.isMeleeChargeActive = true
		self:refreshPersistentHaptics()
	end

	local waveform = waveformUtilities.createMeleeCharge(chargeInfo)
	if waveform == nil then
		self.effectPlayer:stopChannel(meleeChargeChannel)
		return
	end

	self.effectPlayer:playChannelWaveform(meleeChargeChannel, waveform)
end

function haptics:stopMeleeCharge()
	local stateValues = self.__vars
	local wasMeleeChargeActive = stateValues.isMeleeChargeActive
	stateValues.isMeleeChargeActive = false
	self.effectPlayer:stopChannel(meleeChargeChannel)

	if wasMeleeChargeActive then
		self:refreshPersistentHaptics()
	end
end

function haptics:playMeleeRelease(chargeAlpha: number)
	self:stopMeleeCharge()
	self.effectPlayer:playChannelWaveform(meleeImpulseChannel, waveformUtilities.createMeleeRelease(chargeAlpha))
end

function haptics:playMeleeImpact(chargeAlpha: number)
	self.effectPlayer:playChannelWaveform(meleeImpulseChannel, waveformUtilities.createMeleeImpact(chargeAlpha))
end

function haptics:updateChaseState(distanceStuds: number, maximumDistanceStuds: number, intensityMultiplier: number)
	local stateValues = self.__vars
	if not stateValues.isChaseActive then
		stateValues.isChaseActive = true
		if self:isGameplayHapticsActive() then
			self.effectPlayer:playChannelWaveform(chaseImpulseChannel, waveformUtilities.createChaseStarted())
		end
	end

	stateValues.chaseUrgency = waveformUtilities.calculateChaseUrgency(distanceStuds, maximumDistanceStuds)
	stateValues.chaseIntensityMultiplier = intensityMultiplier
	self:refreshChaseHaptics()
end

function haptics:setChaseDistance(distanceStuds: number, maximumDistanceStuds: number)
	self:updateChaseState(distanceStuds, maximumDistanceStuds, 1)
end

function haptics:setCombatChaseDistance(distanceStuds: number, maximumDistanceStuds: number)
	self:updateChaseState(distanceStuds, maximumDistanceStuds, hapticConfig.chase.combatIntensityMultiplier)
end

function haptics:clearChase()
	local stateValues = self.__vars
	stateValues.chaseUrgency = 0
	stateValues.chaseIntensityMultiplier = 1
	stateValues.isChaseActive = false
	self:refreshChaseHaptics()
end

function haptics:startCharacterFeedback()
	self.characterFeedback = CharacterFeedback.new({
		setLowHealthUrgency = function(urgency: number)
			self:setLowHealthUrgency(urgency)
		end,
		clearLowHealth = function()
			self:clearLowHealth()
		end,
		setLowStaminaUrgency = function(urgency: number)
			self:setLowStaminaUrgency(urgency)
		end,
		clearLowStamina = function()
			self:clearLowStamina()
		end,
		playMovementTransition = function(movementName: "sprint" | "crouch")
			self:playMovementTransition(movementName)
		end,
		playStaminaDepleted = function()
			self:playStaminaDepleted()
		end,
	})
end

function haptics:init()
	activeHaptics = self
	self:startCharacterFeedback()

	local connections = self.connections
	connections.preferredInputChanged = userInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		self:onPreferredInputChanged()
	end)
	connections.menuChanged = player:GetAttributeChangedSignal("InMenu"):Connect(function()
		self:refreshPersistentHaptics()
	end)
end

function haptics.new()
	local self = setmetatable({}, haptics)

	self.connections = {}
	self.__vars = table.clone(haptics.__vars)
	self.characterFeedback = nil
	self.effectPlayer = EffectPlayer.new({
		effectsByChannel = hapticConfig.effectsByChannel,
		isInputActive = function()
			return self:isHapticInputActive()
		end,
	})

	self:init()

	return self
end

function haptics:destroy()
	local connections = self.connections
	local characterFeedback = self.characterFeedback

	if characterFeedback then
		characterFeedback:destroy()
		self.characterFeedback = nil
	end

	for connectionName, connection in pairs(connections) do
		connection:Disconnect()
		connections[connectionName] = nil
	end

	self.effectPlayer:destroy()
	if activeHaptics == self then
		activeHaptics = nil
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return haptics
