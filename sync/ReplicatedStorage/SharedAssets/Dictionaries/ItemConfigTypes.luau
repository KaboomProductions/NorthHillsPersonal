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

export type CameraRelativeLookConfig = {
	maximumAngleRadians: number,
	offsetStuds: number,
}

export type AimConfig = {
	fieldOfViewOffset: number,
	blendDurationSeconds: number,
}

export type SpringConfig = {
	mass: number,
	force: number,
	damping: number,
	speed: number,
}

export type CameraRecoilConfig = {
	rotationVelocityRadians: Vector3,
	rotationVelocityVariationRadians: Vector3,
	settledPitchIncrementRadians: number,
	settledPitchVariationRadians: number,
	aimingMultiplier: number,
	spring: SpringConfig,
}

export type RecoilConfig = {
	positionVelocity: Vector3,
	positionVelocityVariation: Vector3,
	rotationVelocityRadians: Vector3,
	rotationVelocityVariationRadians: Vector3,
	aimingMultiplier: number,
	spring: SpringConfig,
	camera: CameraRecoilConfig,
}

export type ViewModelConfig = {
	armFollow: boolean?,
	handFollow: boolean?,
	leftArmSupportEnabled: boolean?,
	coupledArms: boolean?,
	cameraRelative: boolean?,
	cameraRelativeAim: boolean?,
	cameraRelativeLookDown: CameraRelativeLookConfig?,
	cameraRelativeLookUp: CameraRelativeLookConfig?,
	aim: AimConfig?,
	recoil: RecoilConfig?,
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
	projectileObjectId: string?,
	projectileClassId: string?,
	projectileVelocity: number?,
	muzzleFlashId: string?,
	maxAmmo: number?,
	startingReserveAmmo: number?,
	reloadDuration: number?,
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

export type GunConfig = BaseConfig & {
	controllerClass: "Gun",
	damage: DamageRange,
	projectileObjectId: string,
	projectileClassId: string,
	maxAmmo: number,
	startingReserveAmmo: number?,
	holsterDurationSeconds: number?,
}

export type ItemConfig = MeleeConfig | FlashlightConfig | LanternConfig | GunConfig | CapacityConfig | PassiveConfig

export type EquippableConfig = MeleeConfig | FlashlightConfig | LanternConfig | GunConfig

return table.freeze({})
