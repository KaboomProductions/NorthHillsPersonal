--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create

type TextValue = string | (() -> string)

export type Props = {
	title: TextValue?,
	description: TextValue?,
	visible: (() -> boolean)?,
}

local function text(value: TextValue?, fallback: string): string
	if value == nil then
		return fallback
	end
	return if type(value) == "function" then value() else value
end

return function(props: Props)
	return create("ImageLabel")({
		Name = "PanelBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Theme.Images.PanelBanner,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = function()
			return props.visible == nil or props.visible()
		end,
		ZIndex = 2,
		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraMedium,
			Position = UDim2.fromScale(0.0525025, 0.141954),
			Size = UDim2.fromScale(0.41752, 0.0637442),
			Text = function()
				return text(props.description, "Your own personal belongings are stored here alongside your materials.")
			end,
			TextColor3 = Theme.Colors.Description,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.PanelDescription,
			}),
		}),
		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.0465457, 0.0741855),
			Size = UDim2.fromScale(0.685328, 0.0681159),
			Text = function()
				return text(props.title, "INVENTORY")
			end,
			TextColor3 = Theme.Colors.White,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.PanelTitle,
			}),
		}),
	})
end
