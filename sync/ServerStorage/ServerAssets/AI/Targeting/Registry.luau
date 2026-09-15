local httpService = game:GetService("HttpService")
local players = game:GetService("Players")
local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local targetPrefab = aiAssets.TargetPrefab

local components = workspace.Components
local entities = components.Entities

local registryController = {}
registryController.refreshInterval = 0.15
registryController.lastRefresh = 0
registryController.cacheLookup = {}

type CacheAction = "add" | "subtract" | "check"

function registryController.getPlayerFromTarget(target): Player?
	return players:GetPlayerFromCharacter(target.agent)
end

function registryController.recordMiss(self, target)
	local cacheEntry = registryController.updateTargetCache(self, target, "check")

	if cacheEntry then
		registryController.pruneStaleCache(cacheEntry)
	end
end

function registryController.getTargetId(target): string
	local agent = target.agent
	local player = target.player
	local targetId = player and tostring(player.UserId) or agent:GetAttribute("TargetId")

	if not targetId then
		targetId = httpService:GenerateGUID()
		agent:SetAttribute("TargetId", targetId)
	end

	return tostring(targetId)
end

function registryController.clearTargetCache(self)
	for _, cache in self.targetsFolder:GetChildren() do
		cache:Destroy()
	end

	table.clear(registryController.cacheLookup)
end

function registryController.updateTargetCache(self, target, action: CacheAction): ObjectValue?
	local effectiveAction = action or "add"
	local targetId = registryController.getTargetId(target)
	local existingEntry = self.targetsFolder:FindFirstChild(targetId)

	if effectiveAction == "add" then
		if existingEntry then
			existingEntry:SetAttribute("LastSeen", os.clock())
			registryController.cacheLookup[targetId] = existingEntry

			return existingEntry
		end

		local newEntry = targetPrefab:Clone()
		newEntry.Name = targetId
		newEntry.Value = target.agent
		newEntry:SetAttribute("LastSeen", os.clock())
		newEntry.Parent = self.targetsFolder

		local playerValue = newEntry:FindFirstChild("Player")

		if playerValue then
			playerValue.Value = target.player

			if not target.player then
				playerValue:Destroy()
			end
		end

		registryController.cacheLookup[targetId] = newEntry

		return newEntry
	elseif effectiveAction == "subtract" then
		if existingEntry then
			existingEntry:Destroy()
		end

		registryController.cacheLookup[targetId] = nil

		return nil
	end

	return existingEntry
end

function registryController.pruneStaleCache(cacheEntry: ObjectValue, staleThresholdSeconds: number?)
	local threshold = staleThresholdSeconds or 1.5
	local lastSeen = cacheEntry:GetAttribute("LastSeen") or 0

	if os.clock() - lastSeen > threshold then
		cacheEntry:Destroy()

		registryController.cacheLookup[cacheEntry.Name] = nil
	end
end

function registryController.refreshAvailableTargets(self)
	local now = os.clock()

	if now - registryController.lastRefresh < registryController.refreshInterval then
		return self.cachedTargets
	end

	registryController.lastRefresh = now

	local availableTargets = {}
	local componentChildren = components:GetChildren()

	for _, folder in componentChildren do
		if folder == entities then
			continue
		end

		for _, character in folder:GetChildren() do
			if not character:IsA("Model") then
				continue
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = humanoid and (humanoid.RootPart or character:FindFirstChild("HumanoidRootPart"))

			if not humanoid or not rootPart then
				continue
			end

			local targetData = {
				agent = character,
				root = rootPart,
				humanoid = humanoid,
				isRagdolled = character:GetAttribute("Ragdolled") == true,
			}

			targetData.player = registryController.getPlayerFromTarget(targetData)

			if self:isTargetDead(targetData) then
				continue
			end

			table.insert(availableTargets, targetData)
		end
	end

	self.cachedTargets = availableTargets

	return availableTargets
end

return registryController
