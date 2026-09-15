--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create

export type Props = {
	index: number?,
	text: string | (() -> string)?,
	disabled: (() -> boolean)?,
	visible: (() -> boolean)?,
}

local function resolveText(value: string | (() -> string)?): string?
	if type(value) == "function" then
		return value()
	end
	return value
end

local function getText(props: Props): string
	local customText = resolveText(props.text)
	if customText ~= nil and customText ~= "" then
		return customText
	end

	if props.index == nil then
		return ""
	end

	return if props.index == 10 then "0" else tostring(props.index)
end

return function(props: Props)
	local disabled = props.disabled or function()
		return false
	end

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
		Visible = function()
			return props.visible == nil or props.visible()
		end,
		ZIndex = 4,
		create("TextLabel")({
			Name = "Number",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.49, 0.5),
			Size = UDim2.fromScale(0.728393, 0.728393),
			Text = function()
				return getText(props)
			end,
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
