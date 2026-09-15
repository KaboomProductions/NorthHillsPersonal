--!strict

export type Primitive = boolean | number | string
export type PersistentAttributes = { [string]: Primitive }

export type DisplayConfig = {
	displayName: string,
	description: string,
	imageId: number?,
}

export type StackConfig = {
	maxCount: number,
}

export type ThrowableConfig = {
	projectileId: string,
	velocity: number,
	releaseTimeoutSeconds: number?,
	animationId: (number | string)?,
	releaseMarker: string?,
}

export type UpgradeCost = {
	materialType: string,
	count: number,
}

export type Upgrade = {
	id: string,
	resultItemType: string,
	materials: { UpgradeCost }?,
}

export type RigJoint = {
	part0: string,
	part1: string,
	c0: CFrame?,
	c1: CFrame?,
	isWeld: boolean?,
}

export type DamageRange = {
	min: number,
	max: number,
}

export type HitboxConfig = {
	delayTimeSeconds: number,
	lastingTimeSeconds: number,
}

export type AnimationConfig = {
	[string]: number,
}

export type FirstPersonViewModelConfig = {
	maximumLookUpRadians: number?,
	maximumLookDownRadians: number?,
	lookUpPitchScale: number?,
	lookDownPitchScale: number?,
	lookUpOffset: Vector3?,
	lookDownOffset: Vector3?,
}

export type FirstPersonTurnResponseConfig = {
	turnDepthAlpha: number?,
	turnLateralAlpha: number?,
	turnDepthStuds: number?,
	turnLateralStuds: number?,
	overshootSlideFactor: number?,
	verticalOvershootHeightScale: number?,
	maximumVerticalOvershootRadians: number?,
}

export type RightArmConfig = {
	baseOffset: Vector3?,
	firstPersonViewmodel: FirstPersonViewModelConfig?,
	firstPersonTurnResponse: FirstPersonTurnResponseConfig?,
}

export type LeftArmSupportConfig = {
	offset: Vector3?,
	rotationRadians: Vector3?,
	followsRightArm: boolean?,
}

export type ViewModelConfig = {
	armFollow: boolean?,
	handFollow: boolean?,
	leftArmSupportEnabled: boolean?,
	coupledArms: boolean?,
	rightArm: RightArmConfig?,
	leftArmSupport: LeftArmSupportConfig?,
}

export type BaseConfig = {
	displayName: string,
	description: string,
	imageId: number,
	persistentAttributes: PersistentAttributes?,
	controllerClass: string?,
	stack: StackConfig?,
	throwable: ThrowableConfig?,
	upgrades: { Upgrade }?,
	rigging: { RigJoint }?,
	animations: AnimationConfig?,
	viewModel: ViewModelConfig?,
	holsterDurationSeconds: number?,
	damage: DamageRange?,
	staminaCost: DamageRange?,
	hitboxSize: Vector3?,
	hitboxDelayTime: number?,
	swingLastingTime: number?,
	cooldownTime: number?,
	cooldownTimeSeconds: number?,
	staminaUsage: number?,
	weaponType: string?,
	hitbox: HitboxConfig?,
	chargeDepleteDuration: number?,
	chargeDepleteWaitTime: number?,
	chargeHoldDuration: number?,
	maxCharge: number?,
	chargeBarLerpSpeed: number?,
	chargeBarTransparencyThreshold: number?,
	heavySwingThreshold: number?,
	storageCapacityIncrease: number?,
	leftArmSupportEnabled: boolean?,
	coupledArms: boolean?,
	rightArm: RightArmConfig?,
	leftArmSupport: LeftArmSupportConfig?,
}

export type MeleeConfig = BaseConfig & {
	controllerClass: "Melee",
	holsterDurationSeconds: number,
	damage: DamageRange,
	hitboxSize: Vector3,
	hitboxDelayTime: number,
	swingLastingTime: number,
	cooldownTime: number,
}

export type FlashlightConfig = BaseConfig & {
	controllerClass: "Flashlight",
	holsterDurationSeconds: number,
}

export type LanternConfig = BaseConfig & {
	controllerClass: "Lantern",
	holsterDurationSeconds: number,
}

export type PassiveConfig = BaseConfig & {
	controllerClass: nil,
}

export type CapacityConfig = PassiveConfig & {
	storageCapacityIncrease: number,
}

export type ItemConfig = MeleeConfig | FlashlightConfig | LanternConfig | CapacityConfig | PassiveConfig

export type EquippableConfig = MeleeConfig | FlashlightConfig | LanternConfig

return table.freeze({})
