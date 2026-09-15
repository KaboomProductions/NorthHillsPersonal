local hapticConfig = require(script.Parent.Config)

local millisecondsPerSecond = 1000

local waveformUtilities = {}

export type PulseInfo = {
	intensity: number,
	durationSeconds: number,
	interpolationMode: Enum.KeyInterpolationMode,
}

export type MeleeChargeInfo = {
	chargeDurationSeconds: number,
	elapsedSeconds: number?,
}

export type AmbientWaveform = {
	intensity: number,
	durationSeconds: number,
	variationFraction: number,
}

local ambientIntensityMultipliers = { 1, 1.08, 0.94, 1.05, 1 }

local function calculateLerpedNumber(minimumNumber: number, maximumNumber: number, alpha: number): number
	return minimumNumber + (maximumNumber - minimumNumber) * math.clamp(alpha, 0, 1)
end

function waveformUtilities.createPulse(pulseInfo: PulseInfo): { FloatCurveKey }
	local intensity = math.clamp(pulseInfo.intensity, 0, 1)
	local durationMilliseconds = math.max(pulseInfo.durationSeconds, 0) * millisecondsPerSecond

	return {
		FloatCurveKey.new(0, intensity, pulseInfo.interpolationMode),
		FloatCurveKey.new(durationMilliseconds, 0, Enum.KeyInterpolationMode.Linear),
	}
end

function waveformUtilities.createAmbientVariation(ambientWaveform: AmbientWaveform): { FloatCurveKey }
	local intensity = math.clamp(ambientWaveform.intensity, 0, 1)
	local variationFraction = math.clamp(ambientWaveform.variationFraction, 0, 1)
	local durationMilliseconds = math.max(ambientWaveform.durationSeconds, 0) * millisecondsPerSecond
	local lastKeyNumber = #ambientIntensityMultipliers
	local waveform = {}

	for keyNumber, intensityMultiplier in ambientIntensityMultipliers do
		local keyAlpha = (keyNumber - 1) / (lastKeyNumber - 1)
		local variedMultiplier = 1 + (intensityMultiplier - 1) * variationFraction

		table.insert(
			waveform,
			FloatCurveKey.new(
				durationMilliseconds * keyAlpha,
				math.clamp(intensity * variedMultiplier, 0, 1),
				Enum.KeyInterpolationMode.Linear
			)
		)
	end

	return waveform
end

function waveformUtilities.quantizeUrgency(urgency: number): number
	local urgencySteps = hapticConfig.persistentUrgencySteps

	return math.round(math.clamp(urgency, 0, 1) * urgencySteps) / urgencySteps
end

function waveformUtilities.calculateLowHealthUrgency(currentHealth: number): number
	local activationHealth = hapticConfig.health.activationHealth

	return math.clamp((activationHealth - currentHealth) / activationHealth, 0, 1)
end

function waveformUtilities.calculateLowStaminaUrgency(currentStamina: number, maximumStamina: number): number
	if maximumStamina <= 0 then
		return 0
	end

	local currentFraction = math.clamp(currentStamina / maximumStamina, 0, 1)
	local activationFraction = hapticConfig.stamina.activationFraction

	return math.clamp((activationFraction - currentFraction) / activationFraction, 0, 1)
end

function waveformUtilities.calculateChaseUrgency(distanceStuds: number, maximumDistanceStuds: number): number
	local minimumDistanceStuds = hapticConfig.chase.minimumDistanceStuds
	local distanceRangeStuds = math.max(maximumDistanceStuds - minimumDistanceStuds, 1)

	return 1 - math.clamp((distanceStuds - minimumDistanceStuds) / distanceRangeStuds, 0, 1)
end

function waveformUtilities.createUiHover(): { FloatCurveKey }
	local hoverSettings = hapticConfig.ui.hover

	return waveformUtilities.createPulse({
		intensity = hoverSettings.intensity,
		durationSeconds = hoverSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Constant,
	})
end

function waveformUtilities.createUiClick(): { FloatCurveKey }
	local clickSettings = hapticConfig.ui.click

	return waveformUtilities.createPulse({
		intensity = clickSettings.intensity,
		durationSeconds = clickSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Constant,
	})
end

function waveformUtilities.createSliderStep(valueAlpha: number): { FloatCurveKey }
	local sliderSettings = hapticConfig.ui.slider
	local intensityAlpha = math.clamp(valueAlpha, 0, 1) ^ sliderSettings.intensityExponent

	return waveformUtilities.createPulse({
		intensity = calculateLerpedNumber(
			sliderSettings.minimumIntensity,
			sliderSettings.maximumIntensity,
			intensityAlpha
		),
		durationSeconds = sliderSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createSliderBoundary(): { FloatCurveKey }
	local sliderSettings = hapticConfig.ui.slider

	return waveformUtilities.createPulse({
		intensity = sliderSettings.boundaryIntensity,
		durationSeconds = sliderSettings.boundaryDurationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Constant,
	})
end

function waveformUtilities.createHotbarSelection(): { FloatCurveKey }
	local hotbarSettings = hapticConfig.ui.hotbar

	return waveformUtilities.createPulse({
		intensity = hotbarSettings.intensity,
		durationSeconds = hotbarSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createPerspectiveChange(): { FloatCurveKey }
	local perspectiveSettings = hapticConfig.perspective

	return waveformUtilities.createPulse({
		intensity = perspectiveSettings.intensity,
		durationSeconds = perspectiveSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createToolToggle(): { FloatCurveKey }
	local toggleSettings = hapticConfig.toolToggle

	return waveformUtilities.createPulse({
		intensity = toggleSettings.intensity,
		durationSeconds = toggleSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Constant,
	})
end

function waveformUtilities.createMovementTransition(movementName: "sprint" | "crouch"): { FloatCurveKey }
	local movementSettings = hapticConfig.movement[movementName]

	return waveformUtilities.createPulse({
		intensity = movementSettings.intensity,
		durationSeconds = movementSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createLowHealth(urgency: number): { FloatCurveKey }
	local healthSettings = hapticConfig.health

	return waveformUtilities.createAmbientVariation({
		intensity = calculateLerpedNumber(healthSettings.minimumIntensity, healthSettings.maximumIntensity, urgency),
		durationSeconds = healthSettings.waveformDurationSeconds,
		variationFraction = healthSettings.variationFraction,
	})
end

function waveformUtilities.createLowStamina(urgency: number): { FloatCurveKey }
	local staminaSettings = hapticConfig.stamina

	return waveformUtilities.createAmbientVariation({
		intensity = calculateLerpedNumber(staminaSettings.minimumIntensity, staminaSettings.maximumIntensity, urgency),
		durationSeconds = staminaSettings.waveformDurationSeconds,
		variationFraction = staminaSettings.variationFraction,
	})
end

function waveformUtilities.createStaminaDepleted(): { FloatCurveKey }
	local depletedSettings = hapticConfig.stamina.depleted

	return waveformUtilities.createPulse({
		intensity = depletedSettings.intensity,
		durationSeconds = depletedSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createChase(urgency: number, intensityMultiplier: number): { FloatCurveKey }
	local chaseSettings = hapticConfig.chase

	return waveformUtilities.createAmbientVariation({
		intensity = calculateLerpedNumber(chaseSettings.minimumIntensity, chaseSettings.maximumIntensity, urgency)
			* intensityMultiplier,
		durationSeconds = chaseSettings.waveformDurationSeconds,
		variationFraction = chaseSettings.variationFraction,
	})
end

function waveformUtilities.createChaseStarted(): { FloatCurveKey }
	local startedSettings = hapticConfig.chase.started

	return waveformUtilities.createPulse({
		intensity = startedSettings.intensity,
		durationSeconds = startedSettings.durationSeconds,
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createDamage(damageAmount: number, maximumHealth: number): { FloatCurveKey }
	local damageSettings = hapticConfig.damage
	local fullIntensityDamage = math.max(maximumHealth * damageSettings.fullIntensityDamageFraction, 1)
	local damageAlpha = math.clamp(damageAmount / fullIntensityDamage, 0, 1)

	return waveformUtilities.createPulse({
		intensity = calculateLerpedNumber(
			damageSettings.minimumIntensity,
			damageSettings.maximumIntensity,
			damageAlpha
		),
		durationSeconds = calculateLerpedNumber(
			damageSettings.minimumDurationSeconds,
			damageSettings.maximumDurationSeconds,
			damageAlpha
		),
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createMeleeCharge(chargeInfo: MeleeChargeInfo): { FloatCurveKey }?
	local chargeDurationSeconds = math.max(chargeInfo.chargeDurationSeconds, 0)
	local elapsedSeconds = math.clamp(chargeInfo.elapsedSeconds or 0, 0, chargeDurationSeconds)
	if chargeDurationSeconds <= 0 or elapsedSeconds >= chargeDurationSeconds then
		return nil
	end

	local startingChargeAlpha = elapsedSeconds / chargeDurationSeconds
	local remainingDurationMilliseconds = (chargeDurationSeconds - elapsedSeconds) * millisecondsPerSecond
	local chargeSettings = hapticConfig.melee.charge
	local startingIntensity = calculateLerpedNumber(
		chargeSettings.minimumIntensity,
		chargeSettings.maximumIntensity,
		startingChargeAlpha
	)

	return {
		FloatCurveKey.new(0, startingIntensity, Enum.KeyInterpolationMode.Linear),
		FloatCurveKey.new(remainingDurationMilliseconds, chargeSettings.maximumIntensity, Enum.KeyInterpolationMode.Linear),
	}
end

function waveformUtilities.createMeleeRelease(chargeAlpha: number): { FloatCurveKey }
	local releaseSettings = hapticConfig.melee.release

	return waveformUtilities.createPulse({
		intensity = calculateLerpedNumber(
			releaseSettings.minimumIntensity,
			releaseSettings.maximumIntensity,
			chargeAlpha
		),
		durationSeconds = calculateLerpedNumber(
			releaseSettings.minimumDurationSeconds,
			releaseSettings.maximumDurationSeconds,
			chargeAlpha
		),
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

function waveformUtilities.createMeleeImpact(chargeAlpha: number): { FloatCurveKey }
	local impactSettings = hapticConfig.melee.impact

	return waveformUtilities.createPulse({
		intensity = calculateLerpedNumber(
			impactSettings.minimumIntensity,
			impactSettings.maximumIntensity,
			chargeAlpha
		),
		durationSeconds = calculateLerpedNumber(
			impactSettings.minimumDurationSeconds,
			impactSettings.maximumDurationSeconds,
			chargeAlpha
		),
		interpolationMode = Enum.KeyInterpolationMode.Linear,
	})
end

return waveformUtilities
