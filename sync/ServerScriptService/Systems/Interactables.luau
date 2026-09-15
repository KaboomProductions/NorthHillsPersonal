local collectionService = game:GetService("CollectionService")
local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local templateProximityPrompt = serverAssets.Prefabs.ProximityPrompt

local interactablesController = {}
interactablesController.__index = interactablesController
interactablesController.__vars = {
	isInitialized = false,
}

function interactablesController:findPromptHolder(root: Instance): Instance?
	for _, descendant in ipairs(root:GetDescendants()) do
		if
			collectionService:HasTag(descendant, "PromptHolder")
			and (descendant:IsA("Attachment") or descendant:IsA("BasePart"))
		then
			return descendant
		end
	end

	if root:IsA("Attachment") or root:IsA("BasePart") then
		return root
	end
	if root:IsA("Model") and root.PrimaryPart then
		return root.PrimaryPart
	end
	return root:FindFirstChildWhichIsA("BasePart", true)
end

function interactablesController:createPrompt(root: Instance): ProximityPrompt
	local prompt = templateProximityPrompt:Clone()
	local target = self:findPromptHolder(root)

	local parentInstance = target or root
	local promptType = parentInstance:GetAttribute("PromptType") or "Interact"

	prompt:SetAttribute("PromptType", promptType)
	prompt.Parent = parentInstance

	return prompt
end

function interactablesController:getClassModule(className: string): ModuleScript?
	local classModule = script:FindFirstChild(className)
	return classModule and classModule:IsA("ModuleScript") and classModule or nil
end

function interactablesController:getTargetsForSource(sourceInstance: Instance): { Instance }
	if sourceInstance:IsA("Configuration") or sourceInstance:IsA("Folder") then
		return sourceInstance:GetChildren()
	end

	return { sourceInstance }
end

function interactablesController:loadSource(sourceInstance: Instance)
	local className = sourceInstance:GetAttribute("Class")
	if type(className) ~= "string" then
		return
	end

	local classModule = self:getClassModule(className)
	if classModule == nil then
		warn(("Missing interactable class module %s for %s"):format(className, sourceInstance:GetFullName()))
		return
	end

	local classController = require(classModule)
	if type(classController) ~= "table" or type(classController.new) ~= "function" then
		warn(("Invalid interactable class module %s"):format(classModule:GetFullName()))
		return
	end

	local targets = self:getTargetsForSource(sourceInstance)
	local loadedTargets = {}

	for _, target in ipairs(targets) do
		if self.controllersByTarget[target] ~= nil then
			continue
		end

		local prompt = self:createPrompt(target)
		local controller = classController.new({
			instance = target,
			prompt = prompt,
			promptHolder = prompt.Parent,
		})

		self.controllersByTarget[target] = controller
		self.promptsByTarget[target] = prompt
		table.insert(loadedTargets, target)
	end

	if #loadedTargets > 0 then
		self.targetsBySource[sourceInstance] = loadedTargets
	end
end

function interactablesController:destroyTarget(target: Instance)
	local controller = self.controllersByTarget[target]
	if type(controller) == "table" and type(controller.destroy) == "function" then
		controller:destroy()
	end

	local prompt = self.promptsByTarget[target]
	if prompt ~= nil and prompt.Parent ~= nil then
		prompt:Destroy()
	end

	self.controllersByTarget[target] = nil
	self.promptsByTarget[target] = nil
end

function interactablesController:unloadSource(sourceInstance: Instance)
	local loadedTargets = self.targetsBySource[sourceInstance]
	if loadedTargets == nil then
		return
	end

	for _, target in ipairs(loadedTargets) do
		self:destroyTarget(target)
	end

	self.targetsBySource[sourceInstance] = nil
end

function interactablesController:init()
	local stateValues = self.__vars
	local connections = self.connections

	if stateValues.isInitialized then
		return
	end

	for _, taggedInstance in ipairs(collectionService:GetTagged("Interactable")) do
		self:loadSource(taggedInstance)
	end

	connections.tagAdded = collectionService:GetInstanceAddedSignal("Interactable"):Connect(function(taggedInstance)
		self:loadSource(taggedInstance)
	end)

	connections.tagRemoved = collectionService:GetInstanceRemovedSignal("Interactable"):Connect(function(taggedInstance)
		self:unloadSource(taggedInstance)
	end)

	stateValues.isInitialized = true
end

function interactablesController.new()
	local self = setmetatable({}, interactablesController)

	self.__vars = table.clone(interactablesController.__vars)
	self.connections = {}
	self.targetsBySource = {}
	self.controllersByTarget = {}
	self.promptsByTarget = {}

	self:init()

	return self
end

function interactablesController:destroy()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	for sourceInstance in pairs(self.targetsBySource) do
		self:unloadSource(sourceInstance)
	end

	table.clear(self.connections)
	table.clear(self.targetsBySource)
	table.clear(self.controllersByTarget)
	table.clear(self.promptsByTarget)
end

return interactablesController
