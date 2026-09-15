--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create

export type Props = {
	occupied: () -> number,
	capacity: () -> number,
	title: string?,
}

return function(props: Props)
	return create("ImageLabel")({
		Name = "CategoryHeader",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Theme.Images.CategoryHeader,
		LayoutOrder = -1,
		Position = UDim2.fromScale(0.508136, 0.0487646),
		Size = Theme.Geometry.CategorySize,
		ZIndex = 0,
		create("TextLabel")({
			Name = "MainText",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.01493, 0.517579),
			Size = UDim2.fromScale(0.969915, 0.405629),
			Text = props.title or "INVENTORY SLOTS",
			TextColor3 = Theme.Colors.White,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 1,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.Category,
			}),
		}),
		create("TextLabel")({
			Name = "SlotNumber",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.01493, 0.517579),
			Size = UDim2.fromScale(0.969915, 0.405629),
			Text = function()
				return string.format("%d/%d", props.occupied(), props.capacity())
			end,
			TextColor3 = Theme.Colors.White,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 1,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.Category,
			}),
		}),
	})
end
