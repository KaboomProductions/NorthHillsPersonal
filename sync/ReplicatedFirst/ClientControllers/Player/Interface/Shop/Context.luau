local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local networking = require(replicatedStorage.Communication.Networking)

local function collectChildrenOfClass(parent: Instance, className: string): { Instance }
	local children = {}

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA(className) then
			table.insert(children, child)
		end
	end

	table.sort(children, function(left, right)
		local leftLayoutOrder = left:IsA("GuiObject") and left.LayoutOrder or 0
		local rightLayoutOrder = right:IsA("GuiObject") and right.LayoutOrder or 0

		if leftLayoutOrder ~= rightLayoutOrder then
			return leftLayoutOrder < rightLayoutOrder
		end

		return left.Name < right.Name
	end)

	return children
end

local context = {}

function context.new()
	local player = players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local interface = playerGui:WaitForChild("Interface")

	local shopFrame = interface:WaitForChild("Shop")
	local optionsFrame = shopFrame:WaitForChild("Options")
	local mainPage = optionsFrame:WaitForChild("MainPage")
	local buyPage = optionsFrame:WaitForChild("BuyPage")
	local dialogueFrame = optionsFrame:WaitForChild("Dialogue")

	local mainPageHeader = mainPage:WaitForChild("Header")
	local mainPageHolder = mainPage:WaitForChild("Holder")

	local buyTabsFrame = buyPage:WaitForChild("Tabs")
	local buyTabsHeader = buyTabsFrame:WaitForChild("Header")
	local buyTabSelection = buyTabsFrame:WaitForChild("TabSelection")
	local buyTabsHolder = buyTabsFrame:WaitForChild("Holder")
	local buyStockFrame = buyTabsHolder:WaitForChild("Stock")
	local informationFrame = buyPage:WaitForChild("Information")

	local dialogueBox = dialogueFrame:WaitForChild("DialogueBox")

	local sharedAssets = replicatedStorage:WaitForChild("SharedAssets")

	local zaraNode = workspace.Ignore.Other:WaitForChild("ZaraNode")
	local nodeRoot = zaraNode.PrimaryPart
	local promptHolder = nodeRoot:WaitForChild("PromptHolder")
	local proximityPrompt = promptHolder:WaitForChild("ProximityPrompt")

	return {
		player = player,
		interface = interface,
		sharedAssets = sharedAssets,

		shopFrame = shopFrame,
		optionsFrame = optionsFrame,
		borders = shopFrame:WaitForChild("Borders"),

		mainPage = {
			frame = mainPage,
			header = mainPageHeader,
			holder = mainPageHolder,
			closeButton = mainPageHeader:WaitForChild("CloseButton"),
			optionButtons = collectChildrenOfClass(mainPageHolder, "ImageButton"),
		},

		buyPage = {
			frame = buyPage,
			tabsFrame = buyTabsFrame,
			tabsHeader = buyTabsHeader,
			tabsCloseButton = buyTabsHeader:WaitForChild("CloseButton"),
			tabSelection = buyTabSelection,
			categoryButtons = collectChildrenOfClass(buyTabSelection, "TextButton"),
			stockFrame = buyStockFrame,
			informationFrame = informationFrame,
		},

		dialogue = {
			frame = dialogueFrame,
			dialogueBox = dialogueBox,
			npcNameLabel = dialogueBox:WaitForChild("NPCName"),
			textLabel = dialogueBox:WaitForChild("Text"),
			choiceButtons = {
				dialogueFrame:WaitForChild("DialogueChoiceA"),
				dialogueFrame:WaitForChild("DialogueChoiceB"),
			},
		},

		prompt = {
			node = zaraNode,
			holder = promptHolder,
			prompt = proximityPrompt,
		},

		networking = networking,
	}
end

return context
