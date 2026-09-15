--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create
type Cleanup = () -> ()
type TextValue = string | (() -> string)

export type Props = {
	text: TextValue?,
	registerDropZone: ((gui: GuiObject) -> Cleanup?)?,
	visible: (() -> boolean)?,
}

return function(props: Props)
	local text = if type(props.text) == "function"
		then props.text
		else function()
			return props.text or "Drag here to drop."
		end

	local banner = create("ImageLabel")({
		Name = "DropZoneBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Image = Theme.Images.DropZoneBanner,
		Position = UDim2.fromScale(0.5, 0.91),
		Size = UDim2.fromScale(0.865991, 0.104746),
		Visible = function()
			return props.visible == nil or props.visible()
		end,
		ZIndex = 2,
		create("TextLabel")({
			Name = "MainText",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.783767, 0.446901),
			Text = text,
			TextColor3 = Theme.Colors.DropZone,
			TextScaled = true,
			ZIndex = 3,
			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = Theme.TextSizeCaps.DropZone,
			}),
		}),
	})

	if props.registerDropZone then
		local cleanup = props.registerDropZone(banner)
		if cleanup then
			vide.cleanup(cleanup)
		end
	end

	return banner
end
