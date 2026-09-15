local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local buttonController = require(script.Parent.Parent.ButtonController)
local categoryController = require(script.CategoryController)
local playerSettings = require(replicatedStorage.SharedAssets.PlayerSettings)

local settingsAssets = replicatedStorage.SharedAssets.Effects.Interface.Settings
local pageTemplate = settingsAssets.PageTemplate
local settingTemplates = settingsAssets.SettingTemplates

local player = players.LocalPlayer
local defaultPageName = "Video"

type SettingDefinition = {
	settingType: string,
	description: string?,
	default: boolean | number | string?,
	imageData: { [string]: string }?,
	options: { { name: string, value: boolean | number | string } }?,
}

type SettingsCategory = { [string]: SettingDefinition }

type SettingEntryInfo = {
	page: Frame,
	settingName: string,
	settingDefinition: SettingDefinition,
	categoryId: string,
}

local settingsButtonController = {}
settingsButtonController.__index = settingsButtonController
settingsButtonController.__vars = {
	currentPage = nil,
	selectedCategoryButton = nil,
}
setmetatable(settingsButtonController, { __index = buttonController })

function settingsButtonController:loadSettingControllerClasses()
	local controllerClassesByType = self.controllerClassesByType

	for _, moduleScript in script:GetChildren() do
		if not moduleScript:IsA("ModuleScript") then
			continue
		end

		if settingTemplates:FindFirstChild(moduleScript.Name) == nil then
			continue
		end

		controllerClassesByType[moduleScript.Name] = require(moduleScript)
	end
end

function settingsButtonController:createSettingEntry(entryInfo: SettingEntryInfo)
	local page = entryInfo.page
	local settingName = entryInfo.settingName
	local settingDefinition = entryInfo.settingDefinition
	local settingType = settingDefinition.settingType
	local template = settingTemplates:FindFirstChild(settingType)
	local controllerClass = self.controllerClassesByType[settingType]
	if template == nil or controllerClass == nil then
		return
	end

	local settingEntry = template:Clone()
	settingEntry.Name = settingName
	settingEntry.Header.Text = settingName

	local descriptionLabel = settingEntry:FindFirstChild("Description")
	if descriptionLabel then
		descriptionLabel.Text = settingDefinition.description or ""
	end

	settingEntry.Parent = page:FindFirstChild("ScrollingFrame")

	local controllerInfo = table.clone(settingDefinition)
	controllerInfo.settingName = settingName
	controllerInfo.categoryId = entryInfo.categoryId
	table.insert(self.settingControllers, controllerClass.new(settingEntry, controllerInfo))
end

function settingsButtonController:createCategoryPage(categoryId: string, settingsCategory: SettingsCategory): Frame
	local page = pageTemplate:Clone()
	page.Name = categoryId
	page.Visible = false
	page.Parent = self.pagesFrame

	for settingName, settingDefinition in settingsCategory do
		self:createSettingEntry({
			page = page,
			settingName = settingName,
			settingDefinition = settingDefinition,
			categoryId = categoryId,
		})
	end

	table.insert(self.createdPages, page)
	return page
end

function settingsButtonController:updateCategoryColors(previousButton: TextButton?, currentButton: TextButton)
	local categoryControllersByButton = self.categoryControllersByButton
	local previousController = previousButton and categoryControllersByButton[previousButton]
	local currentController = categoryControllersByButton[currentButton]

	if previousController then
		previousController:updateTargetTextColor()
	end

	if currentController then
		currentController:updateTargetTextColor()
	end
end

function settingsButtonController:selectCategory(categoryButton: TextButton, page: GuiObject)
	local stateValues = self.__vars
	local previousButton = stateValues.selectedCategoryButton
	local currentPage = stateValues.currentPage

	if currentPage then
		currentPage.Visible = false
	end

	stateValues.selectedCategoryButton = categoryButton
	stateValues.currentPage = page
	page.Visible = true

	self:updateCategoryColors(previousButton, categoryButton)
end

function settingsButtonController:createCategoryController(categoryButton: TextButton, page: GuiObject)
	local newCategoryController = categoryController.new({
		button = categoryButton,
		page = page,
		isSelected = function()
			return self.__vars.selectedCategoryButton == categoryButton
		end,
		onSelected = function(selectedButton: TextButton, selectedPage: GuiObject)
			self:selectCategory(selectedButton, selectedPage)
		end,
	})

	self.categoryControllersByButton[categoryButton] = newCategoryController
end

function settingsButtonController:createCategories()
	for _, categoryInstance in self.categoriesFrame:GetChildren() do
		if not categoryInstance:IsA("TextButton") then
			continue
		end

		local categoryId = categoryInstance.Name
		local settingsCategory = playerSettings[categoryId] :: SettingsCategory?
		if settingsCategory == nil then
			continue
		end

		local page = self:createCategoryPage(categoryId, settingsCategory)
		self:createCategoryController(categoryInstance, page)

		if categoryId == defaultPageName then
			self:selectCategory(categoryInstance, page)
		end
	end
end

function settingsButtonController:activate()
	self.menuController:toggleTab("Settings")
end

function settingsButtonController:preload()
	local menuGui = player.PlayerGui:WaitForChild("Menu", 3)
	local settingsFrame = menuGui.Main.Tabs.Settings
	local contentsFrame = settingsFrame.Contents

	self.categoriesFrame = contentsFrame.Selection.Categories
	self.pagesFrame = contentsFrame.Pages

	self:loadSettingControllerClasses()
	self:createCategories()
end

function settingsButtonController:init()
	self:preload()
end

function settingsButtonController.new(controllerInfo: buttonController.ButtonControllerInfo)
	local self = setmetatable(buttonController.new(controllerInfo), settingsButtonController)

	self.categoryControllersByButton = {}
	self.controllerClassesByType = {}
	self.createdPages = {}
	self.settingControllers = {}
	self.__vars = table.clone(settingsButtonController.__vars)

	task.defer(function()
		if getmetatable(self) then
			self:init()
		end
	end)

	return self
end

function settingsButtonController:destroy()
	for categoryButton, activeCategoryController in self.categoryControllersByButton do
		activeCategoryController:destroy()
		self.categoryControllersByButton[categoryButton] = nil
	end

	for controllerIndex = #self.settingControllers, 1, -1 do
		local settingController = self.settingControllers[controllerIndex]
		settingController:destroy()
		self.settingControllers[controllerIndex] = nil
	end

	for pageIndex = #self.createdPages, 1, -1 do
		local page = self.createdPages[pageIndex]
		page:Destroy()
		self.createdPages[pageIndex] = nil
	end

	buttonController.destroy(self)
end

return settingsButtonController
