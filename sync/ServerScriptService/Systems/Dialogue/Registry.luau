local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local dictionaries = sharedAssets.Dictionaries
local npcDialogueFolder = dictionaries.NPCDialogue
local shopCategoriesFolder = dictionaries.ShopCategories

local dialogueRegistry = {}
dialogueRegistry.__index = dialogueRegistry
dialogueRegistry.__vars = {
	isLoaded = false,
}

function dialogueRegistry:loadNpcData()
	local npcDataById = self.npcDataById

	for _, moduleScript in ipairs(npcDialogueFolder:GetChildren()) do
		if not moduleScript:IsA("ModuleScript") then
			continue
		end

		local npcData = require(moduleScript)
		local npcId = npcData.npcId or string.lower(moduleScript.Name)
		npcDataById[npcId] = npcData
	end
end

function dialogueRegistry:loadItemData()
	local itemConfigsById = self.itemConfigsById

	for _, moduleScript in ipairs(shopCategoriesFolder:GetChildren()) do
		if not moduleScript:IsA("ModuleScript") then
			continue
		end

		local categoryData = require(moduleScript)
		for itemId, itemConfig in pairs(categoryData) do
			itemConfigsById[itemId] = itemConfig
		end
	end
end

function dialogueRegistry:load()
	local stateValues = self.__vars

	if stateValues.isLoaded then
		return
	end

	self:loadNpcData()
	self:loadItemData()

	stateValues.isLoaded = true
end

function dialogueRegistry:getNpcData(npcId: string): { [string]: any }?
	return self.npcDataById[npcId]
end

function dialogueRegistry:getItemConfig(itemId: string): { [string]: any }?
	return self.itemConfigsById[itemId]
end

function dialogueRegistry.new()
	local self = setmetatable({}, dialogueRegistry)

	self.__vars = table.clone(dialogueRegistry.__vars)
	self.npcDataById = {}
	self.itemConfigsById = {}

	return self
end

return dialogueRegistry
