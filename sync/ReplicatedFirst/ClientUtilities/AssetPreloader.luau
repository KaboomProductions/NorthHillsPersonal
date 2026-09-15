local contentProvider = game:GetService("ContentProvider")

local preloadedAssets: {[Instance]: boolean} = {}

local assetPreloader = {}

function assetPreloader.preload(instances: {Instance}?)
	if not instances then
		return
	end

	local instancesToPreload = {}

	for _, instance in ipairs(instances) do
		if preloadedAssets[instance] then
			continue
		end

		preloadedAssets[instance] = true
		table.insert(instancesToPreload, instance)
	end

	if #instancesToPreload > 0 then
		contentProvider:PreloadAsync(instancesToPreload)
	end
end

return assetPreloader
