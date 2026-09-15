local contentProvider = game:GetService("ContentProvider")

local preloadedAssets: { [Instance]: boolean } = {}

local assetPreloader = {}

function assetPreloader.preload(instances: { Instance }?)
	if not instances then
		return
	end

	local newInstances = {}

	for _, instance in ipairs(instances) do
		if preloadedAssets[instance] then
			continue
		end

		preloadedAssets[instance] = true
		table.insert(newInstances, instance)
	end

	if #newInstances > 0 then
		contentProvider:PreloadAsync(newInstances)
	end
end

return assetPreloader
