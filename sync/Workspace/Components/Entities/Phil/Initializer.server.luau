local serverStorage = game:GetService("ServerStorage")

local assets = serverStorage.ServerAssets
local aiAssets = assets.AI
local initializer = require(aiAssets.Initializer)

initializer.new({
	agent = script.Parent,
	behaviorType = "Phil",
} :: initializer.AI)
