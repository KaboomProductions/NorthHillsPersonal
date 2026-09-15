--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create

export type Props = {
	value: () -> number,
	size: UDim2?,
	visible: (() -> boolean)?,
}

local transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.001, 1),
	NumberSequenceKeypoint.new(1, 1),
})

return function(props: Props)
	return create("ImageLabel")({
		Name = "DurabilityBar",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Image = Theme.Images.DurabilityBar,
		ImageColor3 = Theme.Colors.DurabilityBackground,
		Position = UDim2.fromScale(0.5, 0.816),
		Size = props.size or Theme.Geometry.DurabilityBarSize,
		Visible = function()
			return props.visible == nil or props.visible()
		end,
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
					return Vector2.new(math.clamp(props.value(), 0, 1), 0)
				end,
				Transparency = transparency,
			}),
		}),
	})
end
