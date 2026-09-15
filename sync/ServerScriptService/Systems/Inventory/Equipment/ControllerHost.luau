--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local itemPlacement = require(script.Parent.Parent.Items.ItemPlacement)
local itemRigging = require(script.Parent.ItemRigging)
local types = require(script.Parent.Parent.Contracts)

export type Host = types.ControllerHost
type ToolController = types.ToolController
type ControllerMethod = types.ControllerMethod

local controllerHost = {}
controllerHost.__index = controllerHost

function controllerHost.new(): Host
	return (
		setmetatable({
			controllers = {},
			create = controllerHost.create,
			get = controllerHost.get,
			reset = controllerHost.reset,
			destroy = controllerHost.destroy,
			destroyForPlayer = controllerHost.destroyForPlayer,
		}, controllerHost) :: unknown
	) :: Host
end

function controllerHost:create(player: Player, character: Model, item: Model): ToolController?
	self:destroy(item)
	local config = itemUtils.getBaseConfig(item)
	local className = itemUtils.getControllerClass(item)
	if typeof(className) ~= "string" then
		return nil
	end
	local module = serverScriptService.Controllers.Tools:FindFirstChild(className)
	if module == nil or not module:IsA("ModuleScript") then
		warn(string.format("[Inventory] Missing server tool controller %s", className))
		return nil
	end
	local controller = require(module).new(player, character, item, config) :: ToolController
	self.controllers[item] = controller
	return controller
end

function controllerHost:get(item: Instance?): ToolController?
	return item and self.controllers[item] or nil
end

function controllerHost:reset(item: Model, storedTools: Folder?): ()
	local controller = self.controllers[item]
	if controller then
		for _, methodName in ipairs({
			"cleanupCharging",
			"cancelSwing",
			"stopActiveSound",
			"registerToggle",
			"cleanupRigArtifacts",
		}) do
			local method = controller[methodName]
			if typeof(method) == "function" then
				pcall(method :: ControllerMethod, controller)
			end
		end
	end
	item:RemoveTag("EquippedItem")
	item:SetAttribute("Equipped", false)
	item:SetAttribute("SpecialEquip", nil)
	item:SetAttribute("Toggled", false)
	item:SetAttribute("Charging", false)
	item:SetAttribute("ChargeStrength", 0)
	item:SetAttribute("Cooldown", false)
	if storedTools then
		itemRigging.setAnchored(item, true)
		itemPlacement.moveToOwner(item, storedTools)
	end
end

function controllerHost:destroy(item: Instance?): ()
	if item == nil then
		return
	end
	local controller = self.controllers[item]
	if controller and typeof(controller.destroy) == "function" then
		pcall(controller.destroy, controller)
	end
	local mainRemote = item:FindFirstChild("MainRemote")
	if mainRemote then
		mainRemote:Destroy()
	end
	local mainFunction = item:FindFirstChild("MainFunction")
	if mainFunction then
		mainFunction:Destroy()
	end
	self.controllers[item] = nil
end

function controllerHost.destroyForPlayer(self: Host, player: Player): ()
	for item, controller in self.controllers do
		local controllerPlayer = (controller.player :: unknown) :: Player
		if controllerPlayer == player then
			self:destroy(item)
		end
	end
end

return controllerHost
