local serverStorage = game:GetService("ServerStorage")

local assets = serverStorage.ServerAssets
local classes = assets.Classes

local aiController = require(classes.AI)
local bot = script.Parent

aiController.new({
	agent = bot;
	type = "Phil"
})