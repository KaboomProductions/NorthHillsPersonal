local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage:WaitForChild("SharedAssets")
local dictionaries = sharedAssets:WaitForChild("Dictionaries")
local animations = dictionaries:WaitForChild("Animations")
local playerAnimations = animations:WaitForChild("Player")

local walkingAnimations = playerAnimations:WaitForChild("Walking")
local sprintingAnimations = playerAnimations:WaitForChild("Sprinting")
local crouchingAnimations = playerAnimations:WaitForChild("Crouching")
local injuredAnimations = playerAnimations:WaitForChild("Injured")

local function createDirectionalSet(source: Instance)
	return {
		forward = source:WaitForChild("Forward"),
		backward = source:WaitForChild("Backward"),
		left = source:WaitForChild("Left"),
		right = source:WaitForChild("Right"),
	}
end

local config = {
	fadeTime = 0.2,
	moveThreshold = 0.1,

	movementRestartSyncWindow = 0.12,
	movementBlendEpsilon = 0.01,

	movementLayerLingerTime = 0.6,

	locomotionBlendSpeed = {
		enter = 5,
		exit = 17,
	},

	directionBlendSpeed = 12,

	movementBlendTimes = {
		default = 0.2,

		walkingToSprinting = 1,
		crouchingToSprinting = 1.6,
		sprintingToWalking = 0.12,
	},

	footstepCooldown = 0.18,

	defaultIdle = playerAnimations:WaitForChild("Idle"),

	states = {
		healthy = {
			priority = 0,
			defaultVariant = "walking",
			idle = playerAnimations:WaitForChild("Idle"),
			variants = {
				walking = {
					speedKey = "walking",
					movement = createDirectionalSet(walkingAnimations),
				},

				crouching = {
					speedKey = "crouching",
					idle = crouchingAnimations:WaitForChild("Idle"),
					movement = createDirectionalSet(crouchingAnimations:WaitForChild("Moveset")),
					transitions = {
						enter = crouchingAnimations:WaitForChild("StandToCrouch"),
						exit = crouchingAnimations:WaitForChild("CrouchToStand"),
					},
				},

				sprinting = {
					speedKey = "sprinting",
					movement = createDirectionalSet(sprintingAnimations),
				},
			},
		},

		injured = {
			priority = 100,
			defaultVariant = "walking",
			idle = injuredAnimations:WaitForChild("Idle"),
			variants = {
				walking = {
					speedKey = "injuredWalking",
					movement = createDirectionalSet(injuredAnimations:WaitForChild("Walking")),
				},

				sprinting = {
					speedKey = "injuredSprinting",
					movement = createDirectionalSet(injuredAnimations:WaitForChild("Sprinting")),
				},
			},
		},
	},
}

return config
