local starterPlayer = game:GetService("StarterPlayer")

local clientConfig = {
	camera = {
		defaultFieldOfView = 70,
	},

	mouseIcon = "rbxassetid://94233477129898",

	input = {

		mobileButtons = {
			sprinting = "rbxassetid://78730588393448",
			crouching = "rbxassetid://71141407019260",
			flashlightToggle = "rbxassetid://108891002524183",
			lanternToggle = "rbxassetid://106534778176462",
			togglePerspective = "rbxassetid://130195519124217",
			swingMelee = "rbxassetid://16181366859",
		},
	},

	movement = {
		speedPresets = {
			walking = starterPlayer.CharacterWalkSpeed,

			sprinting = 23,
			crouching = 6,

			injuredSprinting = 12,
			injuredWalking = 6,
		},
	},
}

return clientConfig
