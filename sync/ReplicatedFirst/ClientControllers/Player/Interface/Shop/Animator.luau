local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local animatorHelpers = require(script.AnimatorHelpers)
local guiAnimator = require(replicatedStorage.SharedClasses.Interface.GuiAnimator)

local player = players.LocalPlayer
local shopAnimator = {}
local runtime = nil

local function buildAnimation(moduleScript: ModuleScript, context, trackName: string)
	local result = { require(moduleScript).new(context, trackName) }

	return {
		play = result[1],
		preload = result[2],
	}
end

local function createRuntime()
	local interface = player.PlayerGui:WaitForChild("Interface")
	local shopFrame = interface.Shop
	local options = shopFrame.Options
	local buyPage = options.BuyPage
	local buyPageTabs = buyPage.Tabs
	local mainPage = options.MainPage
	local dialogueFrame = options.Dialogue
	local informationFrame = buyPage.Information
	local borders = shopFrame.Borders

	local shopAnimatorModule = guiAnimator.new(shopFrame)
	local dialogueAnimatorModule = guiAnimator.new(dialogueFrame)

	local shopContext = {
		animatorHelpers = animatorHelpers,
		animatorModule = shopAnimatorModule,
		uiCache = shopAnimatorModule.uiCache,
		ui = {
			shopFrame = shopFrame,
			borders = borders,
			mainPage = mainPage,
			buyPage = buyPage,
			buyPageTabs = buyPageTabs,
			informationFrame = informationFrame,
		},
	}
	local dialogueContext = {
		animatorHelpers = animatorHelpers,
		animatorModule = dialogueAnimatorModule,
		uiCache = dialogueAnimatorModule.uiCache,
		ui = {
			dialogueFrame = dialogueFrame,
		},
	}

	local mainShopTrack = shopAnimatorModule:createTrack("mainShopPage").name
	local infoPanelTrack = shopAnimatorModule:createTrack("infoPanel").name
	local dialogueTrack = dialogueAnimatorModule:createTrack("dialogue").name

	shopAnimatorModule:addSpring("mainPage", Vector2.zero, 15, 100, 4, 2.3)
	shopAnimatorModule:addSpring("itemTabs", Vector2.zero, 15, 100, 4, 2.3)
	shopAnimatorModule:addSpring("infoPanel", Vector2.zero, 15, 100, 4, 2.3)
	shopAnimatorModule:addOffsetTrack("mainPagePosition", mainPage, "Position", "mainPage")
	shopAnimatorModule:addOffsetTrack("itemTabsPosition", buyPageTabs, "Position", "itemTabs")
	shopAnimatorModule:addOffsetTrack("infoPanelPosition", informationFrame, "Position", "infoPanel")

	dialogueAnimatorModule:addSpring("dialogue", Vector2.zero, 15, 100, 4, 2.3)
	dialogueAnimatorModule:addOffsetTrack("dialoguePosition", dialogueFrame, "Position", "dialogue")

	local animations = {
		openShop = buildAnimation(script.Animations.MainPage.OpenShop, shopContext, mainShopTrack),
		closeShop = buildAnimation(script.Animations.MainPage.CloseShop, shopContext, mainShopTrack),
		openBuy = buildAnimation(script.Animations.BuyMenu.OpenBuy, shopContext, mainShopTrack),
		closeBuy = buildAnimation(script.Animations.BuyMenu.CloseBuy, shopContext, mainShopTrack),
		showInfo = buildAnimation(script.Animations.BuyMenu.ItemInformation.ShowInfo, shopContext, infoPanelTrack),
		hideInfo = buildAnimation(script.Animations.BuyMenu.ItemInformation.HideInfo, shopContext, infoPanelTrack),
		openDialogue = buildAnimation(script.Animations.Dialogue.OpenDialogue, dialogueContext, dialogueTrack),
		closeDialogue = buildAnimation(script.Animations.Dialogue.CloseDialogue, dialogueContext, dialogueTrack),
	}

	return {
		shopAnimatorModule = shopAnimatorModule,
		dialogueAnimatorModule = dialogueAnimatorModule,
		animations = animations,
	}
end

local function ensureRuntime()
	if runtime == nil then
		runtime = createRuntime()
	end

	return runtime
end

function shopAnimator.preload()
	local currentRuntime = ensureRuntime()

	for _, animationData in pairs(currentRuntime.animations) do
		if typeof(animationData.preload) == "function" then
			animationData.preload()
		end
	end
end

function shopAnimator.update(deltaTime: number)
	local currentRuntime = runtime
	if currentRuntime == nil then
		return
	end

	currentRuntime.shopAnimatorModule:applyTracks(deltaTime)
	currentRuntime.dialogueAnimatorModule:applyTracks(deltaTime)
end

function shopAnimator.destroy()
	local currentRuntime = runtime
	if currentRuntime == nil then
		return
	end

	currentRuntime.shopAnimatorModule:destroy()
	currentRuntime.dialogueAnimatorModule:destroy()
	runtime = nil
end

setmetatable(shopAnimator, {
	__index = function(_, animationName: string)
		local currentRuntime = ensureRuntime()
		local animationData = currentRuntime.animations[animationName]
		return animationData and animationData.play or nil
	end,
})

return shopAnimator
