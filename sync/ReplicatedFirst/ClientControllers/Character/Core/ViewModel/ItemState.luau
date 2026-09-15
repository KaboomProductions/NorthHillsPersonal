local gripMotion = require(script.Parent.GripMotion)
local replication = require(script.Parent.Replication)

local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")
local attributes = require(replicatedStorage.SharedAssets.Attributes)
local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local clientData = require(replicatedFirst.ClientData)

local itemState = {}
local equippedItemTag = "EquippedItem"
local equippedToolAttribute = attributes.tool.equipped
local aimingToolAttribute = attributes.tool.aiming
local recoilSequenceToolAttribute = attributes.tool.recoilSequence
local armFollowDelaySeconds = 0.25

local function resetSpring(activeSpring)
	activeSpring.target = Vector3.zero
	activeSpring.position = Vector3.zero
	activeSpring.velocity = Vector3.zero
end

local function resetRecoilState(controller)
	controller.__vars.pendingRecoilCount = 0
	resetSpring(controller.recoilPositionSpring)
	resetSpring(controller.recoilRotationSpring)
end

local function setAimingState(controller, isAiming: boolean)
	controller.__vars.isAiming = isAiming
	clientData.isAiming = isAiming
end

local function getItemConfig(item: Instance?): { [string]: any }?
	if item == nil then
		return nil
	end

	return itemUtils.getItemConfig(item)
end

local function getViewModelFlags(itemConfig: { [string]: any }?): (boolean, boolean, boolean)
	if itemConfig == nil then
		return false, false, false
	end

	local viewModelConfig = itemConfig.viewModel

	if viewModelConfig == nil then
		return false, false, false
	end

	local hasRightArmViewModel = viewModelConfig.rightArm ~= nil
	local hasLeftArmSupport = viewModelConfig.leftArmSupport ~= nil
	local isArmFollowEnabled = hasRightArmViewModel and viewModelConfig.armFollow ~= false
	local isHandFollowEnabled = hasRightArmViewModel and viewModelConfig.handFollow ~= false
	local isLeftArmSupportEnabled = hasLeftArmSupport and viewModelConfig.leftArmSupportEnabled ~= false

	return isArmFollowEnabled, isLeftArmSupportEnabled, isHandFollowEnabled
end

local function applyItemViewModelConfig(controller, item: Instance?, itemConfig: { [string]: any }?)
	local stateValues = controller.__vars

	stateValues.leftArmSupportOffset = nil
	stateValues.leftArmSupportRotationRadians = nil
	stateValues.leftArmSupportFollowsRightArm = nil
	stateValues.itemRightArmConfig = nil
	stateValues.isCoupledArms = false
	stateValues.isCameraRelative = false
	stateValues.cameraRelativeAim = false
	stateValues.cameraRelativeLookDown = nil
	stateValues.cameraRelativeLookUp = nil
	stateValues.aimConfig = nil
	stateValues.recoilConfig = nil

	if item == nil then
		return
	end

	local viewModelConfig = itemConfig and itemConfig.viewModel

	if viewModelConfig == nil then
		return
	end

	stateValues.isCoupledArms = viewModelConfig.coupledArms == true
	stateValues.isCameraRelative = viewModelConfig.cameraRelative == true
	stateValues.cameraRelativeAim = viewModelConfig.cameraRelativeAim == true
	stateValues.cameraRelativeLookDown = viewModelConfig.cameraRelativeLookDown
	stateValues.cameraRelativeLookUp = viewModelConfig.cameraRelativeLookUp
	stateValues.aimConfig = viewModelConfig.aim
	stateValues.recoilConfig = viewModelConfig.recoil

	local leftArmSupportConfig = viewModelConfig.leftArmSupport
	if leftArmSupportConfig then
		stateValues.leftArmSupportOffset = leftArmSupportConfig.offset
		stateValues.leftArmSupportRotationRadians = leftArmSupportConfig.rotationRadians
		stateValues.leftArmSupportFollowsRightArm = leftArmSupportConfig.followsRightArm
	end

	if viewModelConfig.rightArm then
		stateValues.itemRightArmConfig = viewModelConfig.rightArm
	end
end

local function disconnectItemChildConnection(controller)
	local connections = controller.connections
	local itemChildConnection = connections.itemChild

	if itemChildConnection == nil then
		return
	end

	itemChildConnection:Disconnect()
	connections.itemChild = nil
end

local function disconnectItemEquippedConnection(controller)
	local connections = controller.connections
	local itemEquippedConnection = connections.itemEquipped

	if itemEquippedConnection == nil then
		return
	end

	itemEquippedConnection:Disconnect()
	connections.itemEquipped = nil
end

local function disconnectItemAimingConnection(controller)
	local connections = controller.connections
	local itemAimingConnection = connections.itemAiming

	if itemAimingConnection == nil then
		return
	end

	itemAimingConnection:Disconnect()
	connections.itemAiming = nil
end

local function disconnectItemRecoilConnection(controller)
	local connections = controller.connections
	local itemRecoilConnection = connections.itemRecoil

	if itemRecoilConnection == nil then
		return
	end

	itemRecoilConnection:Disconnect()
	connections.itemRecoil = nil
end

local function cancelPendingArmFollowDelay(controller)
	controller.armFollowDelayToken = (controller.armFollowDelayToken or 0) + 1
	controller.armFollowDelayItem = nil
	controller.armFollowReadyItem = nil
	controller.__vars.armFollowEnableTime = 0
	controller.__vars.armFollowBlend = 0
end

local function scheduleArmFollowDelay(controller, item: Instance?, shouldEnableArmFollow: boolean)
	if item == nil or not shouldEnableArmFollow then
		cancelPendingArmFollowDelay(controller)
		return
	end

	if controller.armFollowReadyItem == item or controller.armFollowDelayItem == item then
		return
	end

	controller.armFollowDelayToken = (controller.armFollowDelayToken or 0) + 1
	local expectedDelayToken = controller.armFollowDelayToken
	controller.armFollowDelayItem = item
	controller.armFollowReadyItem = nil

	task.delay(armFollowDelaySeconds, function()
		if controller.armFollowDelayToken ~= expectedDelayToken or controller.heldItem ~= item then
			return
		end

		if getmetatable(controller) == nil or item:GetAttribute(equippedToolAttribute) == false then
			return
		end

		controller.armFollowDelayItem = nil
		controller.armFollowReadyItem = item
		controller.__vars.armFollowEnableTime = time()
		controller.__vars.armFollowBlend = 0
		itemState.applyHeldItemConfig(controller, item)
	end)
end

local function updateItemHandle(controller, item: Instance?)
	if item == nil then
		controller.itemHandle = nil
		return
	end

	local handle = item:FindFirstChild("Handle")
	controller.itemHandle = handle and handle:IsA("BasePart") and handle or nil
end

function itemState.resetItemState(controller)
	local stateValues = controller.__vars
	cancelPendingArmFollowDelay(controller)

	stateValues.isArmFollowEnabled = false
	stateValues.isLeftArmSupportEnabled = false
	stateValues.isHandFollowEnabled = false
	stateValues.shouldReturnArms = true
	stateValues.shouldReturnGrip = true
	stateValues.armFollowEnableTime = 0
	stateValues.armFollowBlend = 0
	stateValues.handFollowEnableTime = 0
	stateValues.handFollowBlend = 0
	stateValues.leftArmSupportOffset = nil
	stateValues.leftArmSupportRotationRadians = nil
	stateValues.leftArmSupportFollowsRightArm = nil
	stateValues.itemRightArmConfig = nil
	stateValues.isCoupledArms = false
	stateValues.isCameraRelative = false
	stateValues.cameraRelativeAim = false
	stateValues.cameraRelativeLookDown = nil
	stateValues.cameraRelativeLookUp = nil
	stateValues.aimConfig = nil
	setAimingState(controller, false)
	stateValues.aimAlpha = 0
	stateValues.recoilConfig = nil
	resetRecoilState(controller)
	clientData.fieldOfViewModifiers.aiming = nil

	controller.itemHandle = nil
	gripMotion.resetGripState(controller)
end

function itemState.suspendHeldItemViewModel(controller)
	local stateValues = controller.__vars
	cancelPendingArmFollowDelay(controller)

	stateValues.isArmFollowEnabled = false
	stateValues.isLeftArmSupportEnabled = false
	stateValues.isHandFollowEnabled = false
	stateValues.shouldReturnArms = true
	stateValues.shouldReturnGrip = true
	stateValues.armFollowEnableTime = 0
	stateValues.armFollowBlend = 0
	setAimingState(controller, false)
	stateValues.aimAlpha = 0
	resetRecoilState(controller)
	clientData.fieldOfViewModifiers.aiming = nil

	gripMotion.resetGripState(controller)
	replication.sendDefaultShoulders(controller)
end

function itemState.applyHeldItemConfig(controller, item: Instance?)
	local stateValues = controller.__vars

	if item == nil then
		itemState.resetItemState(controller)
		return
	end

	local itemConfig = getItemConfig(item)
	local wasArmFollowEnabled = stateValues.isArmFollowEnabled
	local wasLeftArmSupportEnabled = stateValues.isLeftArmSupportEnabled
	local wasHandFollowEnabled = stateValues.isHandFollowEnabled
	local nextArmFollowEnabled, nextLeftArmSupportEnabled, nextHandFollowEnabled = getViewModelFlags(itemConfig)
	local viewModelConfig = itemConfig and itemConfig.viewModel
	local isCameraRelative = viewModelConfig and viewModelConfig.cameraRelative == true
	local isEquipped = item:GetAttribute(equippedToolAttribute) == true
	local shouldEnableArmFollow = isEquipped and (isCameraRelative or controller.armFollowReadyItem == item)

	if isEquipped and not isCameraRelative then
		scheduleArmFollowDelay(controller, item, nextArmFollowEnabled)
	else
		cancelPendingArmFollowDelay(controller)
	end

	stateValues.isArmFollowEnabled = nextArmFollowEnabled and shouldEnableArmFollow
	stateValues.isLeftArmSupportEnabled = nextLeftArmSupportEnabled and shouldEnableArmFollow
	stateValues.isHandFollowEnabled = nextHandFollowEnabled

	updateItemHandle(controller, item)
	applyItemViewModelConfig(controller, item, itemConfig)

	if not stateValues.isHandFollowEnabled then
		gripMotion.resetGripState(controller)
		stateValues.shouldReturnGrip = false
	elseif not wasHandFollowEnabled then
		gripMotion.beginHandFollow(controller)
	end

	if wasArmFollowEnabled and not stateValues.isArmFollowEnabled then
		replication.sendDefaultShoulders(controller)
		stateValues.shouldReturnArms = true
	end

	if wasLeftArmSupportEnabled and not stateValues.isLeftArmSupportEnabled then
		replication.sendShoulderUpdate(controller, {
			leftShoulderC0 = controller.shoulders.defaultLeftC0,
		}, true)
		stateValues.shouldReturnArms = true
	end
end

function itemState.setHeldItem(controller, item: Instance?)
	if controller.heldItem == item then
		return
	end

	disconnectItemChildConnection(controller)
	disconnectItemEquippedConnection(controller)
	disconnectItemAimingConnection(controller)
	disconnectItemRecoilConnection(controller)
	cancelPendingArmFollowDelay(controller)
	resetRecoilState(controller)

	controller.heldItem = item
	setAimingState(controller, false)

	if item == nil then
		itemState.applyHeldItemConfig(controller, nil)
		controller.__vars.shouldReturnGrip = true
		controller.__vars.shouldReturnArms = true
		replication.sendDefaultShoulders(controller)
		return
	end

	controller.connections.itemChild = item.ChildAdded:Connect(function(child)
		if controller.heldItem == item and child.Name == "Handle" then
			itemState.applyHeldItemConfig(controller, item)
		end
	end)

	controller.connections.itemEquipped = item:GetAttributeChangedSignal(equippedToolAttribute):Connect(function()
		if controller.heldItem ~= item then
			return
		end

		if item:GetAttribute(equippedToolAttribute) == false then
			itemState.suspendHeldItemViewModel(controller)
			return
		end

		itemState.applyHeldItemConfig(controller, item)
	end)

	controller.connections.itemAiming = item:GetAttributeChangedSignal(aimingToolAttribute):Connect(function()
		if controller.heldItem ~= item then
			return
		end

		setAimingState(controller, item:GetAttribute(aimingToolAttribute) == true)
	end)
	setAimingState(controller, item:GetAttribute(aimingToolAttribute) == true)

	controller.connections.itemRecoil = item:GetAttributeChangedSignal(recoilSequenceToolAttribute):Connect(function()
		local recoilConfig = controller.__vars.recoilConfig
		if controller.heldItem ~= item or recoilConfig == nil or item:GetAttribute(equippedToolAttribute) ~= true then
			return
		end

		controller.__vars.pendingRecoilCount += 1

		local cameraRecoilConfig = recoilConfig.camera
		if cameraRecoilConfig ~= nil then
			clientData.queueCameraRecoil(cameraRecoilConfig, controller.__vars.isAiming)
		end
	end)

	if item:GetAttribute(equippedToolAttribute) == false then
		itemState.suspendHeldItemViewModel(controller)
		return
	end

	itemState.applyHeldItemConfig(controller, item)
end

function itemState.findAvailableItem(controller)
	for _, item in pairs(controller.character:GetChildren()) do
		if not item:HasTag(equippedItemTag) then
			continue
		end

		return item
	end

	return nil
end

function itemState.bindItemSignals(controller)
	local character = controller.character
	local connections = controller.connections

	connections.childAdded = character.ChildAdded:Connect(function(child)
		if child:HasTag(equippedItemTag) then
			itemState.setHeldItem(controller, child)
		end
	end)

	connections.childRemoved = character.ChildRemoved:Connect(function(child)
		if child:HasTag(equippedItemTag) and child == controller.heldItem then
			itemState.setHeldItem(controller, nil)
		end
	end)

	itemState.setHeldItem(controller, itemState.findAvailableItem(controller))
end

return itemState
