local interactableMotion = {}

interactableMotion.animateOnClient = true

interactableMotion.attributes = {
	mode = "MotionMode",
	sequence = "MotionSequence",
	targetYaw = "MotionTargetYaw",
	targetYaw1 = "MotionTargetYaw1",
	targetYaw2 = "MotionTargetYaw2",
	targetDistance = "MotionTargetDistance",
	speedOverride = "MotionSpeedOverride",
}

interactableMotion.modes = {
	singlePivot = "SinglePivot",
	doublePivot = "DoublePivot",
	slide = "Slide",
}

interactableMotion.thresholds = {
	pivotSettledAngle = math.rad(0.15),
	pivotSettledVelocity = 0.01,
	slideSettledDistance = 0.001,
	slideSettledVelocity = 0.01,
}

interactableMotion.door = {
	stateValues = {
		defaultOpenAngle = 95,
		smashOpenVelocity = 18,
		smashOpenDirectionThreshold = 0.55,
		smashOpenMoveThreshold = 0.25,
		smashCooldownSeconds = 0.35,
		smashImpulseScale = 0.035,
		smashImpulseMin = 10,
		smashImpulseMax = 20,
		metalSpringMass = 17,
	},

	springSettingsOpen = {
		mass = 15,
		force = 100,
		damping = 4,
		speed = 2,
	},

	springSettingsClose = {
		mass = 15,
		force = 100,
		damping = 4,
		speed = 2,
	},
}

interactableMotion.locker = {
	springSettingsOpen = {
		mass = 15,
		force = 100,
		damping = 4,
		speed = 2,
	},

	springSettingsClose = {
		mass = 15,
		force = 100,
		damping = 4,
		speed = 2,
	},
}

interactableMotion.drawer = {
	springSettingsOpen = {
		mass = 8,
		force = 80,
		damping = 5,
		speed = 3,
	},

	springSettingsClose = {
		mass = 8,
		force = 80,
		damping = 6,
		speed = 3,
	},
}

local function cloneSettings(settings: { [string]: number }): { [string]: number }
	return table.clone(settings)
end

local function getNumericAttribute(instance: Instance, attributeName: string, defaultValue: number): number
	local attributeValue = instance:GetAttribute(attributeName)
	if type(attributeValue) == "number" then
		return attributeValue
	end

	return defaultValue
end

function interactableMotion.getRelativeYaw(basePivot: CFrame, targetPivot: CFrame): number
	local relativePivot = basePivot:ToObjectSpace(targetPivot)
	local _, yaw, _ = relativePivot:ToOrientation()
	return yaw
end

function interactableMotion.getDoorSpringSettings(isOpen: boolean, doorType: string?): { [string]: number }
	local springSettings =
		cloneSettings(isOpen and interactableMotion.door.springSettingsOpen or interactableMotion.door.springSettingsClose)

	if doorType == "Metal" then
		springSettings.mass = interactableMotion.door.stateValues.metalSpringMass
	end

	return springSettings
end

function interactableMotion.getLockerSpringSettings(isOpen: boolean): { [string]: number }
	return cloneSettings(isOpen and interactableMotion.locker.springSettingsOpen or interactableMotion.locker.springSettingsClose)
end

function interactableMotion.getDrawerSpringSettings(isOpen: boolean): { [string]: number }
	return cloneSettings(isOpen and interactableMotion.drawer.springSettingsOpen or interactableMotion.drawer.springSettingsClose)
end

function interactableMotion.applySpeedOverride(
	springSettings: { [string]: number },
	speedOverride: number?
): { [string]: number }
	if type(speedOverride) == "number" then
		springSettings.speed = speedOverride
	end

	return springSettings
end

function interactableMotion.publishState(instance: Instance, payload: { [string]: any })
	local attributes = interactableMotion.attributes
	local sequence = getNumericAttribute(instance, attributes.sequence, 0)

	instance:SetAttribute(attributes.mode, payload.mode)
	instance:SetAttribute(attributes.targetYaw, payload.targetYaw)
	instance:SetAttribute(attributes.targetYaw1, payload.targetYaw1)
	instance:SetAttribute(attributes.targetYaw2, payload.targetYaw2)
	instance:SetAttribute(attributes.targetDistance, payload.targetDistance)
	instance:SetAttribute(attributes.speedOverride, payload.speedOverride)
	instance:SetAttribute(attributes.sequence, sequence + 1)
end

return interactableMotion
