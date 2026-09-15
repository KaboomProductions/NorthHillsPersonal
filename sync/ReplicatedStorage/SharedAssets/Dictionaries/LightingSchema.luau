local lightingSchema = {}

lightingSchema.propertyNames = {
	"Ambient",
	"Brightness",
	"ClockTime",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
	"FogStart",
	"GeographicLatitude",
	"OutdoorAmbient",
	"ShadowSoftness",
}

lightingSchema.effectPropertyNamesByClassName = {
	Atmosphere = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" },
	BloomEffect = { "Intensity", "Size", "Threshold" },
	BlurEffect = { "Size" },
	ColorCorrectionEffect = { "Brightness", "Contrast", "Saturation", "TintColor" },
	DepthOfFieldEffect = { "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity" },
	SunRaysEffect = { "Intensity", "Spread" },
}

return table.freeze(lightingSchema)
