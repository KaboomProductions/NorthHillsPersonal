--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(replicatedStorage.ExternalLibraries.vide)

local Theme = require(script.Parent.Theme)

local create = vide.create

export type MaterialMap = { [string]: number }

export type Props = {
	materials: () -> MaterialMap,
	getDisplayName: ((materialType: string) -> string)?,
	visible: (() -> boolean)?,
}

type MaterialEntry = {
	materialType: string,
	displayName: string,
	amount: number,
}

local function createMaterialBadge(entrySource: () -> MaterialEntry, layoutOrder: number): Frame
	return create("Frame")({
		Name = "MaterialBadge",
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = Theme.Geometry.MaterialBadgeSize,
		create("ImageLabel")({
			Name = "BG",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.MaterialBadge,
			Position = UDim2.fromScale(0.492643, 0.5),
			Size = UDim2.fromScale(0.985285, 1),
		}),
		create("TextLabel")({
			Name = "MaterialName",
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.JuraBold,
			Position = UDim2.fromScale(0.00632505, 0.0234416),
			Rotation = -27.3,
			Size = UDim2.fromScale(0.57175, 0.298472),
			Text = function()
				return entrySource().displayName
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
				return tostring(math.max(0, math.floor(entrySource().amount)))
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

local function defaultDisplayName(materialType: string): string
	local spaced = string.gsub(materialType, "([a-z])([A-Z])", "%1 %2")
	return string.upper(spaced)
end

return function(props: Props)
	local entries = vide.indexes(function()
		local materials = props.materials()
		local materialTypes: { string } = {}
		for materialType, amount in materials do
			if typeof(materialType) == "string" and typeof(amount) == "number" then
				table.insert(materialTypes, materialType)
			end
		end
		table.sort(materialTypes)

		local result: { [number]: MaterialEntry } = {}
		for index, materialType in ipairs(materialTypes) do
			local amount = materials[materialType]
			result[index] = {
				materialType = materialType,
				displayName = if props.getDisplayName
					then props.getDisplayName(materialType)
					else defaultDisplayName(materialType),
				amount = amount,
			}
		end
		return result
	end, function(entrySource: () -> MaterialEntry, index: number)
		return createMaterialBadge(entrySource, index)
	end)

	return create("Frame")({
		Name = "MaterialList",
		BackgroundTransparency = 1,
		Position = Theme.Geometry.MaterialListPosition,
		Size = Theme.Geometry.MaterialListSize,
		Visible = function()
			if props.visible then
				return props.visible()
			end
			for _, amount in props.materials() do
				if typeof(amount) == "number" then
					return true
				end
			end
			return false
		end,
		create("ImageLabel")({
			Name = "Outline",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.MaterialOutline,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}),
		create("ImageLabel")({
			Name = "BG",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Images.MaterialBackground,
			ImageTransparency = 0.5,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		}),
		create("Frame")({
			Name = "MaterialHolder",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.9625, 0.901577),
			create("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			entries,
		}),
	})
end
