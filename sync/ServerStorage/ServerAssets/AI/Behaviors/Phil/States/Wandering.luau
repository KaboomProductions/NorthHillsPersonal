local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local aiAssets = serverAssets.AI
local inheriter = require(aiAssets.Inheriter)

local wanderingController = inheriter.extend("Wandering")
wanderingController.__vars = {
	minRadius = 32,
	maxRadius = 64,

	radiusDeductionPerSearch = 2,

	recomputeInterval = 5,
}

function wanderingController:cancelSearch()
	if self.currentSearchTrack then
		self.currentSearchTrack:Stop()
		self.currentSearchTrack = nil
	end
end

function wanderingController:enter()
	self.currentRadius = self.__vars.maxRadius

	self.connections.onError = self.pathfinder.Error:Connect(function()
		self:compute()
	end)

	self.connections.onReached = self.pathfinder.Reached:Connect(function()
		self:search()
	end)

	self:compute()
end

function wanderingController:exit()
	self:cancelSearch()
end

function wanderingController.new(ai)
	local self = inheriter.new(ai, wanderingController)
	self.searchTracks = self.tracks.search

	return self
end

function wanderingController:search()
	self.currentRadius = math.clamp(
		self.currentRadius - self.__vars.radiusDeductionPerSearch,
		self.__vars.minRadius,
		self.__vars.maxRadius
	)

	self.searchTracks.casual:Play()

	self.connections.onSearchEnded = self.searchTracks.casual.Ended:Once(function()
		self:compute()
	end)
end

function wanderingController:compute()
	local nearestTarget = self.targeting:getNearestTarget()
	local rootPart = nearestTarget and nearestTarget.root

	if rootPart then
		self:cancelSearch()
		self.ai:traverseTo(rootPart.Position)

		return
	end

	task.delay(self.__vars.recomputeInterval, self.compute, self)
end

function wanderingController:update(_deltaTime: number)
	local nearestTarget = self.targeting:getNearestTarget({
		range = self.rangeConfig.stalk,
		canRaycast = true,
	})

	if nearestTarget then
		self.ai:setState("Chasing")

		return
	end
end

return wanderingController
