--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local materialUtils = require(replicatedStorage.SharedUtilities.MaterialUtils)
local types = require(script.Parent.Parent.Contracts)

export type ItemConfig = types.BaseConfig
export type TemplateService = types.Templates

local templates = {}
templates.__index = templates

function templates.new(): TemplateService
	local folder = serverStorage:FindFirstChild("ItemTemplates")
	assert(folder and folder:IsA("Folder"), "ServerStorage.ItemTemplates is missing")
	return (
		setmetatable({
			folder = folder,
			getConfig = templates.getConfig,
			getTemplate = templates.getTemplate,
			validate = templates.validate,
			validateMaterial = templates.validateMaterial,
			isComplete = templates.isComplete,
		}, templates) :: unknown
	) :: TemplateService
end

function templates:getConfig(itemType: string): ItemConfig?
	return itemUtils.getBaseConfig(itemType)
end

function templates:getTemplate(itemType: string): Model?
	local template = self.folder:FindFirstChild(itemType)
	return if template and template:IsA("Model") then template else nil
end

function templates:validate(itemType: string): (boolean, string?)
	if self:getConfig(itemType) == nil then
		return false, string.format("ItemConfig %s is missing", itemType)
	end
	local template = self:getTemplate(itemType)
	if template == nil then
		return false, string.format("Item template %s is missing", itemType)
	end
	if template:FindFirstChildWhichIsA("BasePart", true) == nil then
		return false, string.format("Item template %s has no BasePart", itemType)
	end
	return true, nil
end

function templates:validateMaterial(materialType: string): (boolean, string?)
	if not materialUtils.isMaterialType(materialType) then
		return false, string.format("MaterialConfig %s is missing", materialType)
	end
	local template = self:getTemplate(materialType)
	if template == nil then
		return false, string.format("Material template %s is missing", materialType)
	end
	if template:FindFirstChildWhichIsA("BasePart", true) == nil then
		return false, string.format("Material template %s has no BasePart", materialType)
	end
	return true, nil
end

local function hasExpectedParts(item: Model, template: Model): boolean
	for _, expectedPart in ipairs(template:GetDescendants()) do
		if not expectedPart:IsA("BasePart") then
			continue
		end
		local path = {}
		local ancestor: Instance? = expectedPart
		while ancestor ~= nil and ancestor ~= template do
			table.insert(path, 1, ancestor.Name)
			ancestor = ancestor.Parent
		end
		if ancestor == nil then
			return false
		end
		local actual: Instance? = item
		for _, name in ipairs(path) do
			actual = actual and actual:FindFirstChild(name)
		end
		if actual == nil or not actual:IsA("BasePart") then
			return false
		end
	end
	return template:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

function templates:isComplete(item: Model): boolean
	local template = self:getTemplate(itemUtils.resolveItemType(item))
	return template ~= nil and hasExpectedParts(item, template)
end

return templates
