local uiCache = {}
uiCache.__index = uiCache

local defaultProperties = {
	"Position",
	"Size",
	"Rotation",
	"AnchorPoint",
	"BackgroundTransparency",
}

function uiCache.new()
	return setmetatable({ cachedProperties = {} }, uiCache)
end

local function cacheInstance(bucket: {[string]: any}, instance: GuiObject, properties: {string})
	for _, property in ipairs(properties) do
		pcall(function()
			bucket[property] = (instance :: any)[property]
		end)
	end
end

function uiCache:cache(root: Instance, properties: {string}?)
	local resolvedProperties = properties or defaultProperties

	if root:IsA("GuiObject") then
		local bucket = self.cachedProperties[root] or {}
		self.cachedProperties[root] = bucket
		cacheInstance(bucket, root :: GuiObject, resolvedProperties)
	end

	for _, instance in ipairs(root:GetDescendants()) do
		if instance:IsA("GuiObject") then
			local bucket = self.cachedProperties[instance] or {}
			self.cachedProperties[instance] = bucket
			cacheInstance(bucket, instance :: GuiObject, resolvedProperties)
		end
	end
end

function uiCache:get(instance: Instance, property: string): any?
	local bucket = self.cachedProperties[instance]
	return bucket and bucket[property]
end

function uiCache:revert(instance: Instance, property: string?)
	local bucket = self.cachedProperties[instance]
	if not bucket then return end

	if property then
		local value = bucket[property]
		if value ~= nil then
			pcall(function()
				(instance :: any)[property] = value
			end)
		end
	else
		for cachedProperty, value in pairs(bucket) do
			pcall(function()
				(instance :: any)[cachedProperty] = value
			end)
		end
	end
end

function uiCache:revertAll(andClear: boolean?)
	for instance in pairs(self.cachedProperties) do
		self:revert(instance)
	end

	if andClear then
		self:clear()
	end
end

function uiCache:forget(instance: Instance)
	self.cachedProperties[instance] = nil
end

function uiCache:clear()
	table.clear(self.cachedProperties)
end

return uiCache