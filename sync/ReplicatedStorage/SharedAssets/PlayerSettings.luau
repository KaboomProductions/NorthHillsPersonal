return {
	Video = {
		["Volumetric Lighting"] = {
			settingType = "ImageToggle",
			description = "Toggles realistic light rays",
			default = false,

			imageData = {
				On = "rbxassetid://99845464508705",
				Off = "rbxassetid://99845464508705",
			},
		},

		["Cast Shadows"] = {
			settingType = "ImageToggle",
			description = "Toggles dynamic shadows for depth",
			default = false,

			imageData = {
				On = "rbxassetid://99845464508705",
				Off = "rbxassetid://99845464508705",
			},
		},

		["Reduced Effects"] = {
			settingType = "Toggle",
			description = "Toggles effects that are impactful on performance",
			default = true,
		},

		["Screen Distortion Intensity"] = {
			settingType = "Slider",
			minimum = 0,
			maximum = 100,
			default = 100,
		},
	},

	Gameplay = {
		["Sprint Input Mode"] = {
			settingType = "Toggle",
			description = "Determines if sprinting is toggled or held down",
			default = "Hold",
			options = {
				{ name = "Toggle", value = "Toggle" },
				{ name = "Hold", value = "Hold" },
			},
		},

		["Crouch Input Mode"] = {
			settingType = "Toggle",
			description = "Determines if crouching is toggled or held down",
			default = "Hold",
			options = {
				{ name = "Toggle", value = "Toggle" },
				{ name = "Hold", value = "Hold" },
			},
		},

		["Photosensitivity Mode"] = {
			settingType = "Toggle",
			description = "Toggles certain effects that may be harmful to those with epilepsy.",
			default = false,
		},
	},

	Audio = {
		["Day Themes"] = {
			settingType = "Toggle",
			description = "Toggles the volume between all day themes",
			default = true,
		},

		["Music Volume"] = {
			settingType = "Slider",
			minimum = 0,
			maximum = 100,
			default = 100,
		},

		["SFX Volume"] = {
			settingType = "Slider",
			minimum = 0,
			maximum = 100,
			default = 100,
		},
	},
}
