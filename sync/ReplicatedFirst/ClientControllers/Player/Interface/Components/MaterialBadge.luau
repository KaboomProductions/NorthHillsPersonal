--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create

type TextValue = string | (() -> string)

export type Props = {
	name: TextValue,
	amount: () -> number,
	selected: (() -> boolean)?,
	size: UDim2?,
	layoutOrder: number?,
}

local function text(value: TextValue): string
	return if type(value) == "function" then value() else value
end

return function(props: Props)
	local selected = props.selected or function()
		return false
	end

	return create("Frame")({
		Name = "MaterialBadge",
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder or 0,
		Size = props.size or Theme.Geometry.MaterialBadgeSize,
		create("ImageLabel")({
			Name = "BG",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.MaterialBadge,
			Position = UDim2.fromScale(0.492643, 0.5),
			Size = UDim2.fromScale(0.985285, 1),
		}),
		create("ImageLabel")({
			Name = "Selected",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.MaterialSelected,
			Position = UDim2.fromScale(0.492643, 0.5),
			Size = UDim2.fromScale(0.985285, 1),
			Visible = selected,
		}),
		create("TextLabel")({
			Name = "MaterialName",
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.00632505, 0.0234416),
			Rotation = -27.3,
			Size = UDim2.fromScale(0.57175, 0.298472),
			Text = function()
				return text(props.name)
			end,
			TextColor3 = Theme.Colors.White,
			TextScaled = true,
			ZIndex = 2,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.MaterialName,
			}),
		}),
		create("TextLabel")({
			Name = "MaterialAmount",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.981017, 0.942138),
			Rotation = -32.9,
			Size = UDim2.fromScale(0.57175, 0.235564),
			Text = function()
				return tostring(math.max(0, math.floor(props.amount())))
			end,
			TextColor3 = Theme.Colors.White,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.MaterialAmount,
			}),
		}),
	})
end
