--!strict

local fonts = table.freeze({
	JuraBold = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	JuraMedium = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
})

local colors = table.freeze({
	White = Color3.new(1, 1, 1),
	Description = Color3.fromRGB(217, 217, 217),
	DropZone = Color3.fromRGB(165, 45, 47),
	DurabilityBackground = Color3.fromRGB(76, 76, 76),
	Slot = Color3.fromRGB(38, 40, 44),
	SlotDisabled = Color3.fromRGB(23, 24, 26),
	DisabledText = Color3.fromRGB(154, 157, 163),
})

local images = table.freeze({
	HotbarShadow = "rbxassetid://71429582758268",
	Slot = "rbxassetid://71791662429195",
	KeybindBadge = "rbxassetid://94484581760680",
	SelectedOutline = "rbxassetid://131954602021146",
	SelectedGlow = "rbxassetid://111973307358005",
	SelectionUnderline = "rbxassetid://98607052456644",
	DurabilityBar = "rbxassetid://139526888707026",
	PanelBackground = "rbxassetid://90927994062362",
	PanelOutline = "rbxassetid://78401415777771",
	PanelScratches = "rbxassetid://124468354781667",
	PanelBanner = "rbxassetid://86599043964834",
	DropZoneBanner = "rbxassetid://131117007443940",
	CategoryHeader = "rbxassetid://93629330231498",
	ScrollBarTop = "rbxassetid://116732402566318",
	ScrollBarMiddle = "rbxassetid://120554595248598",
	ScrollBarBottom = "rbxassetid://136225700260776",
	MaterialOutline = "rbxassetid://92080105054344",
	MaterialBackground = "rbxassetid://84215461230461",
	MaterialBadge = "rbxassetid://114830753598233",
	MaterialSelected = "rbxassetid://89954958717738",
})

local textSizeCaps = table.freeze({
	HotbarKeybind = 20,
	PanelTitle = 41,
	PanelDescription = 36,
	DropZone = 28,
	Category = 24,
	MaterialName = 10,
	MaterialAmount = 13,
	SlotFallback = 16,
	SlotCount = 18,
})

local geometry = table.freeze({
	HotbarPosition = UDim2.fromScale(0.5, 1),
	HotbarSize = UDim2.fromScale(0.545076, 0.164193),
	HotbarAspectRatio = 12.3,
	HotbarSlotHeight = 0.81076,
	HotbarSlotWidth = 0.81076 / 12.3,
	PanelPosition = UDim2.fromScale(0.5, 0.554731),
	PanelSize = UDim2.fromScale(0.499218, 0.567718),
	PanelAspectRatio = 1.56536,
	InventorySlotSize = UDim2.fromScale(0.168266, 0.333709),
	DurabilityBarSize = UDim2.fromScale(0.543537, 0.0278737),
	CategorySize = UDim2.fromScale(0.967462, 0.0986755),
	MaterialListPosition = UDim2.fromScale(0.0157567, 0.325163),
	MaterialListSize = UDim2.fromScale(0.0835073, 0.555556),
	MaterialBadgeSize = UDim2.fromScale(0.701299, 0.195736),
})

return table.freeze({
	Fonts = fonts,
	Colors = colors,
	Images = images,
	TextSizeCaps = textSizeCaps,
	Geometry = geometry,
})
