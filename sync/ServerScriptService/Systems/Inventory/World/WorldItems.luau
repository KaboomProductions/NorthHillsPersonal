--!strict

local collectionService = game:GetService("CollectionService")
local types = require(script.Parent.Parent.Contracts)
local itemFactory = require(script.Parent.Parent.Items.ItemFactory)

export type WorldItems = types.WorldItems
type Factory = itemFactory.Factory

local worldItems = {}
worldItems.__index = worldItems

function worldItems.new(factory: Factory): WorldItems
	local folder = workspace:FindFirstChild("WorldItems")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "WorldItems"
		folder.Parent = workspace
	end
	assert(folder:IsA("Folder"))
	return (
		setmetatable({
			folder = folder,
			factory = factory,
			claims = {},
			adoptExisting = worldItems.adoptExisting,
			claim = worldItems.claim,
			release = worldItems.release,
		}, worldItems) :: unknown
	) :: WorldItems
end

function worldItems:adoptExisting(): ()
	for _, item in ipairs(self.folder:GetChildren()) do
		if not item:IsA("Model") then
			continue
		end
		local adopted, reason = self.factory:adoptWorldItem(item)
		if adopted then
			collectionService:AddTag(adopted, "Interactable")
		else
			warn(string.format("[Inventory] Invalid world item %s: %s", item:GetFullName(), tostring(reason)))
			collectionService:RemoveTag(item, "Interactable")
			self.factory:destroy(item)
		end
	end
end

function worldItems:claim(item: Model, player: Player): boolean
	if self.claims[item] ~= nil or item.Parent ~= self.folder then
		return false
	end
	self.claims[item] = player
	return true
end

function worldItems:release(item: Model): ()
	self.claims[item] = nil
end

return worldItems
