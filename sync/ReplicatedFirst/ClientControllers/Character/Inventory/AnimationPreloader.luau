local contentProvider = game:GetService("ContentProvider")
local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)

local animationPreloader = {}
animationPreloader.__index = animationPreloader

function animationPreloader.new()
	return setmetatable({ requestedAnimationIds = {}, destroyed = false }, animationPreloader)
end

function animationPreloader:_collectItemType(itemType: string, animations: { Animation })
	local config = itemUtils.getBaseConfig(itemType)
	local animationConfig = config and config.animations
	if typeof(animationConfig) ~= "table" then
		return
	end
	for _, animationId in pairs(animationConfig) do
		if typeof(animationId) ~= "number" or self.requestedAnimationIds[animationId] then
			continue
		end
		self.requestedAnimationIds[animationId] = true
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(animationId)
		table.insert(animations, animation)
	end
end

function animationPreloader:_preload(animations: { Animation })
	if #animations == 0 then
		return
	end

	task.spawn(function()
		local succeeded, errorMessage = pcall(contentProvider.PreloadAsync, contentProvider, animations)
		for _, animation in ipairs(animations) do
			animation:Destroy()
		end
		if not succeeded and not self.destroyed then
			warn("[Inventory] Failed to preload tool animations: " .. tostring(errorMessage))
		end
	end)
end

function animationPreloader:preloadItemTypes(itemTypes: { string })
	if self.destroyed then
		return
	end
	local animations: { Animation } = {}
	for _, itemType in ipairs(itemTypes) do
		self:_collectItemType(itemType, animations)
	end
	self:_preload(animations)
end

function animationPreloader:preloadState(state)
	if self.destroyed then
		return
	end
	local animations: { Animation } = {}
	for _, items in ipairs({ state.hotbar, state.storage }) do
		for _, descriptor in pairs(items) do
			self:_collectItemType(descriptor.itemType, animations)
		end
	end
	self:_preload(animations)
end

function animationPreloader:destroy()
	self.destroyed = true
	table.clear(self.requestedAnimationIds)
end

return animationPreloader
