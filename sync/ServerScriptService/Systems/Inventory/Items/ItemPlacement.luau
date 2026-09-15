--!strict

local collectionService = game:GetService("CollectionService")

local itemUtils = require(game:GetService("ReplicatedStorage").SharedUtilities.ItemUtils)
local types = require(script.Parent.Parent.Contracts)

export type Placement = types.Placement

local itemPlacement = {}

local transientAttributes = {
	"Charging",
	"ChargeStrength",
	"Cooldown",
	"Equipped",
	"PendingTransaction",
	"SpecialEquip",
	"Toggled",
}

local function setPartsAnchored(item: Instance, anchored: boolean): ()
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

function itemPlacement.resetTransients(item: Instance): ()
	for _, attributeName in ipairs(transientAttributes) do
		item:SetAttribute(attributeName, nil)
	end
	collectionService:RemoveTag(item, "EquippedItem")
end

function itemPlacement.moveToOwner(item: Model, storedTools: Folder): ()
	local config = itemUtils.getBaseConfig(itemUtils.resolveItemType(item))
	assert(config, "Cannot own an item with no ItemConfig")
	local controllerClass = itemUtils.getControllerClass(item)
	collectionService:RemoveTag(item, "Interactable")
	item:SetAttribute("Class", controllerClass)
	itemPlacement.resetTransients(item)
	setPartsAnchored(item, true)
	item.Parent = storedTools
end

local function getDropPivot(item: Model, handle: BasePart?, target: CFrame): CFrame
	if handle == nil then
		return target
	end
	return target * handle.CFrame:ToObjectSpace(item:GetPivot())
end

function itemPlacement.moveToWorld(item: Model, worldItems: Folder, pivot: CFrame): ()
	itemPlacement.resetTransients(item)
	item:SetAttribute("Class", "ItemPickup")
	setPartsAnchored(item, true)
	item.Parent = worldItems
	local handle = item:FindFirstChild("Handle", true)
	item:PivotTo(getDropPivot(item, if handle and handle:IsA("BasePart") then handle else nil, pivot))
	local groundY = pivot.Position.Y
	local boundingBox, boundingSize = item:GetBoundingBox()
	local bottomY = boundingBox.Position.Y - boundingSize.Y / 2
	item:PivotTo(item:GetPivot() + Vector3.yAxis * (groundY - bottomY + 0.05))
	collectionService:AddTag(item, "Interactable")
end

return itemPlacement
