local characterUpdateConfig = {
	renderStepName = "RemoteCharacterUpdateController",
	smoothingSpeed = 20,

	--// Distance LOD: players beyond farDistanceStuds get snapped instead of
	--// lerped, and players beyond cullDistanceStuds are skipped entirely.
	nearDistanceStuds = 80,
	farDistanceStuds = 160,
	cullDistanceStuds = 300,
	farSmoothingSpeed = 8,
}

return characterUpdateConfig
