--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create
local ASSET_PREFIX = "rbxassetid://"
local selectionUnderlineWidthScale = 0.543537
local selectionUnderlineHeightScale = 0.0278737

type Primitive = boolean | number | string
type Cleanup = () -> ()

export type ItemDescriptor = {
	itemId: string,
	itemType: string,
	stackCount: number,
	attributes: { [string]: Primitive },
	imageId: string | number?,
	displayName: string?,
}

export type SelectionAnimation = {
	selectionProgress: () -> number,
	selectedScale: number,
}

export type SlotProps = {
	descriptor: () -> ItemDescriptor?,
	index: number?,
	selected: () -> boolean,
	durability: (() -> number)?,
	disabled: (() -> boolean)?,
	size: UDim2?,
	layoutOrder: number?,
	onActivated: (() -> ())?,
	registerDragHandle: ((gui: GuiObject) -> Cleanup?)?,
	selectionAnimation: SelectionAnimation?,
}

local function assetId(value: string | number?): string
	if value == nil then
		return ""
	end

	local valueString = tostring(value)
	if valueString == "" then
		return ""
	end

	return if string.sub(valueString, 1, #ASSET_PREFIX) == ASSET_PREFIX
		then valueString
		else ASSET_PREFIX .. valueString
end

local durabilityTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.001, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local function createDurabilityBar(value: () -> number): ImageLabel
	return create("ImageLabel")({
		Name = "DurabilityBar",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Image = Theme.Images.DurabilityBar,
		ImageColor3 = Theme.Colors.DurabilityBackground,
		Position = UDim2.fromScale(0.5, 0.816),
		Size = Theme.Geometry.DurabilityBarSize,
		ZIndex = 3,
		create("ImageLabel")({
			Name = "Fill",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.DurabilityBar,
			ImageColor3 = Theme.Colors.White,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			create("UIGradient")({
				Name = "UIGradient",
				Offset = function()
					return Vector2.new(math.clamp(value(), 0, 1), 0)
				end,
				Transparency = durabilityTransparency,
			}),
		}),
	})
end

local function createKeybindBadge(index: number, disabled: () -> boolean): ImageLabel
	return create("ImageLabel")({
		Name = "KeybindBadge",
		Active = false,
		BackgroundTransparency = 1,
		Image = Theme.Images.KeybindBadge,
		ImageTransparency = function()
			return if disabled() then 0.65 else 0
		end,
		Position = UDim2.fromScale(0.0557474, 0.0557474),
		Selectable = false,
		Size = UDim2.fromScale(0.194783, 0.194783),
		ZIndex = 4,
		create("TextLabel")({
			Name = "Number",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.49, 0.5),
			Size = UDim2.fromScale(0.728393, 0.728393),
			Text = if index == 10 then "0" else tostring(index),
			TextColor3 = function()
				return if disabled() then Theme.Colors.DisabledText else Theme.Colors.White
			end,
			TextScaled = true,
			ZIndex = 5,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.HotbarKeybind,
			}),
		}),
	})
end

return function(props: SlotProps)
	local function descriptor(): ItemDescriptor?
		return props.descriptor()
	end

	local function disabled(): boolean
		return props.disabled ~= nil and props.disabled() or false
	end

	local function image(): string
		local current = descriptor()
		return assetId(current and current.imageId)
	end

	local function fallbackText(): string
		local current = descriptor()
		if current == nil or image() ~= "" then
			return ""
		end
		return if current.displayName and current.displayName ~= "" then current.displayName else current.itemType
	end

	local function getSelectionProgress(): number
		local selectionAnimation = props.selectionAnimation
		if selectionAnimation then
			return math.clamp(selectionAnimation.selectionProgress(), 0, 1)
		end

		return if props.selected() and not disabled() then 1 else 0
	end

	local children: { [any]: any } = {
		Name = if props.index then "Slot" .. tostring(props.index) else "Slot",
		LayoutOrder = props.layoutOrder or props.index or 0,
		Size = props.size or UDim2.fromScale(0.137194, 0.81076),
		BackgroundTransparency = 1,
		Image = Theme.Images.Slot,
		ImageTransparency = function()
			return if disabled() then 0.45 else 0
		end,
		ImageColor3 = function()
			return if disabled() then Theme.Colors.SlotDisabled else Theme.Colors.Slot
		end,
		AutoButtonColor = false,
		Active = function()
			return not disabled()
		end,
		Selectable = false,
		MouseButton1Click = function()
			if disabled() or descriptor() == nil then
				return
			end
			if props.onActivated then
				props.onActivated()
			end
		end,
		create("ImageLabel")({
			Name = "ItemIcon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = image,
			ImageTransparency = function()
				return if disabled() then 0.65 else 0
			end,
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.58, 0.58),
			Visible = function()
				return image() ~= ""
			end,
			ZIndex = 2,
		}),
		create("TextLabel")({
			Name = "ItemText",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.68),
			Text = fallbackText,
			TextColor3 = function()
				return if disabled() then Theme.Colors.DisabledText else Theme.Colors.White
			end,
			TextScaled = true,
			TextWrapped = true,
			Visible = function()
				return fallbackText() ~= ""
			end,
			ZIndex = 2,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.SlotFallback,
			}),
		}),
		create("ImageLabel")({
			Name = "SelectedOutline",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.SelectedOutline,
			ImageTransparency = function()
				return 1 - getSelectionProgress()
			end,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return getSelectionProgress() > 0
			end,
			ZIndex = 3,
		}),
		create("ImageLabel")({
			Name = "SelectedGlow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.SelectedGlow,
			ImageTransparency = function()
				return 1 - getSelectionProgress()
			end,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return getSelectionProgress() > 0
			end,
			ZIndex = 3,
		}),
		create("ImageLabel")({
			Name = "SelectionUnderline",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Image = Theme.Images.SelectionUnderline,
			ImageTransparency = function()
				return 1 - getSelectionProgress()
			end,
			Position = UDim2.fromScale(0.5, 1),
			Size = function()
				return UDim2.fromScale(
					math.lerp(0, selectionUnderlineWidthScale, getSelectionProgress()),
					selectionUnderlineHeightScale
				)
			end,
			Visible = function()
				return getSelectionProgress() > 0
			end,
			ZIndex = 5,
		}),
		create("TextLabel")({
			Name = "Count",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.92, 0.92),
			Size = UDim2.fromScale(0.42, 0.25),
			Text = function()
				local current = descriptor()
				return if current and current.stackCount > 1 then tostring(current.stackCount) else ""
			end,
			TextColor3 = Theme.Colors.White,
			TextTransparency = function()
				return if disabled() then 0.65 else 0
			end,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Visible = function()
				local current = descriptor()
				return current ~= nil and current.stackCount > 1
			end,
			ZIndex = 5,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.SlotCount,
			}),
		}),
	}

	if props.index ~= nil then
		table.insert(children, createKeybindBadge(props.index, disabled))
	end
	if props.durability ~= nil then
		table.insert(children, createDurabilityBar(props.durability))
	end
	if props.selectionAnimation ~= nil then
		local selectionAnimation = props.selectionAnimation
		table.insert(children, create("UIScale")({
			Name = "SelectionScale",
			Scale = function()
				return math.lerp(1, selectionAnimation.selectedScale, getSelectionProgress())
			end,
		}))
	end

	local button = create("ImageButton")(children) :: ImageButton
	if props.registerDragHandle then
		local cleanup = props.registerDragHandle(button)
		if cleanup then
			vide.cleanup(cleanup)
		end
	end

	return button
end
