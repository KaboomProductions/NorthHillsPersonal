local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)

local config = require(script.Config)
local layout = require(script.Layout)
local state = require(script.State)
local utils = require(script.Utils)

local player = players.LocalPlayer
local barManager = {}
barManager.__index = barManager
barManager.__vars = config.stateValues

state.extend(barManager, utils)
layout.extend(barManager, config, utils)

function barManager:onRenderStepped(deltaTime: number)
	for _, barData in pairs(self.barDataByBar) do
		self:updateBarAnimation(barData, deltaTime)
		self:finishHideIfSettled(barData)
	end
end

function barManager:onShopVisibilityChanged()
	self.__vars.isShopOpen = self.shopFrame.Visible

	if self.__vars.isShopOpen then
		for _, barData in pairs(self.barDataByBar) do
			self:cancelHideDelay(barData)
			if barData.state ~= "hidden" then
				self:beginHide(barData)
			end
		end
	end

	self:updateLayout()
end

function barManager:preload()
	local interface = player.PlayerGui:WaitForChild("Interface")
	local progressBars = interface:WaitForChild("ProgressBars")

	self.interface = interface
	self.progressBars = progressBars
	self.shopFrame = interface:WaitForChild("Shop")
end

function barManager:init()
	self:preload()
	self.__vars.isShopOpen = self.shopFrame.Visible

	runService:BindToRenderStep("BarManager", Enum.RenderPriority.Last.Value, function(deltaTime: number)
		self:onRenderStepped(deltaTime)
	end)
	self.connections.shopVisibleChanged = self.shopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		self:onShopVisibilityChanged()
	end)
	self.connections.containerChildAdded = self:getBarsContainer().ChildAdded:Connect(function(child: Instance)
		if utils.isGuiObject(child) then
			self:trackBar(child)
			self:updateLayout()
		end
	end)
	self.connections.containerChildRemoved = self:getBarsContainer().ChildRemoved:Connect(function(child: Instance)
		if utils.isGuiObject(child) then
			connectionUtilities.disconnectConnection(self.attributeConnections[child])
			self.attributeConnections[child] = nil
			self:removeBar(child)
		end
	end)

	self:updateLayout()

	task.delay(self.__vars.startupIgnoreSeconds, function()
		if self.isDestroyed then
			return
		end

		self.ignoreChangesUntil = nil
		self:updateLayout()
	end)
end

function barManager.new()
	local self = setmetatable({}, barManager)

	self.connections = {}
	self.attributeConnections = {}
	self.barDataByBar = {}
	self.__vars = table.clone(barManager.__vars)
	self.interface = nil
	self.progressBars = nil
	self.shopFrame = nil
	self.ignoreChangesUntil = time() + self.__vars.startupIgnoreSeconds
	self.isDestroyed = false

	task.defer(self.init, self)

	return self
end

function barManager:destroy()
	self.isDestroyed = true
	runService:UnbindFromRenderStep("BarManager")

	for _, barData in pairs(self.barDataByBar) do
		self:cancelHideDelay(barData)
	end

	connectionUtilities.disconnectConnections(self.attributeConnections)
	connectionUtilities.disconnectConnections(self.connections)

	table.clear(self.attributeConnections)
	table.clear(self.connections)
	table.clear(self.barDataByBar)

	setmetatable(self, nil)
end

return barManager
