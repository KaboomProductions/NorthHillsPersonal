--!strict

local vide = require(game:GetService("ReplicatedStorage").ExternalLibraries.vide)

local InventoryStore = require(script.Parent.Parent.Parent.InventoryStore)
local constants = require(script.Parent.Parent.Parent.Constants)
local create = vide.create

export type Props = {
	state: InventoryStore.StateSource,
}

return function(props: Props)
	return create("Frame")({
		Name = "DisabledOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 9, 10),
		BackgroundTransparency = 0.32,
		BorderSizePixel = 0,
		Visible = function()
			return not props.state().enabled
		end,
		ZIndex = 20,
		create("TextLabel")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -80, 0, 70),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = function()
				local reason = props.state().disabledReason
				return if reason and reason ~= "" then "INVENTORY LOCKED\n" .. reason else "INVENTORY LOCKED"
			end,
			TextColor3 = constants.textColor,
			TextSize = 18,
			TextWrapped = true,
			ZIndex = 21,
		}),
	})
end
