local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")

local crosshairController = require(script.Crosshair)

local player = players.LocalPlayer
local inputBindings = require(replicatedFirst.ClientUtilities.InputBindings)
local keybinds = require(replicatedStorage.SharedAssets.Keybinds)
local defaultMouseBehavior = Enum.MouseBehavior.LockCenter
local defaultCursorIcon = ""
local unlockedCursorIcon = "rbxassetid://12389204093"

local mouseController = {}
mouseController.__index = mouseController
mouseController.__vars = {
	cameraBehavior = defaultMouseBehavior,
	cursorIcon = defaultCursorIcon,
	isLocked = true,
	isMenuActive = false,
	isSystemCursorVisible = false,
	isUserLockEnabled = true,
}

export type MouseRequestToken = {}

local activeController = nil

local function hasRequests(requestsByToken: { [MouseRequestToken]: string }): boolean
	return next(requestsByToken) ~= nil
end

local function createUnlockOverlay(interface: ScreenGui): TextButton
	local previousOverlay = interface:FindFirstChild("MouseUnlockOverlay")
	if previousOverlay then
		previousOverlay:Destroy()
	end

	local overlay = Instance.new("TextButton")
	overlay.Name = "MouseUnlockOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Text = ""
	overlay.TextTransparency = 1
	overlay.AutoButtonColor = false
	overlay.Modal = true
	overlay.Active = true
	overlay.Selectable = false
	overlay.Visible = false
	overlay.ZIndex = 0
	overlay.Parent = interface

	return overlay
end

local function getActiveController()
	if activeController then
		return activeController
	end

	return mouseController.new()
end

function mouseController:getResolvedMouseBehavior(): Enum.MouseBehavior
	local stateValues = self.__vars
	if stateValues.isMenuActive or hasRequests(self.unlockReasonsByToken) then
		return Enum.MouseBehavior.Default
	end

	if hasRequests(self.lockReasonsByToken) then
		return Enum.MouseBehavior.LockCenter
	end

	if not stateValues.isUserLockEnabled then
		return Enum.MouseBehavior.Default
	end

	local cameraBehavior = stateValues.cameraBehavior
	if cameraBehavior == Enum.MouseBehavior.Default then
		cameraBehavior = defaultMouseBehavior
	end

	return cameraBehavior
end

function mouseController:applyInputState()
	local stateValues = self.__vars
	local mouseBehavior = self:getResolvedMouseBehavior()
	local isLocked = mouseBehavior ~= Enum.MouseBehavior.Default
	local isSystemCursorVisible = not isLocked
	local cursorIcon = if isLocked then defaultCursorIcon else unlockedCursorIcon

	stateValues.cursorIcon = cursorIcon
	stateValues.isLocked = isLocked
	stateValues.isSystemCursorVisible = isSystemCursorVisible

	--// Roblox camera code may rewrite these properties, so their owner verifies them every frame.
	if userInputService.MouseBehavior ~= mouseBehavior then
		userInputService.MouseBehavior = mouseBehavior
	end

	if userInputService.MouseIconEnabled ~= isSystemCursorVisible then
		userInputService.MouseIconEnabled = isSystemCursorVisible
	end

	if self.systemMouse.Icon ~= cursorIcon then
		self.systemMouse.Icon = cursorIcon
	end

	local crosshair = self.crosshair
	if crosshair then
		if isLocked then
			crosshair:showReticle()
		else
			crosshair:hideReticle()
		end
	end
end

function mouseController:updateUnlockState()
	local isUnlocked = hasRequests(self.unlockReasonsByToken)
	if self.unlockOverlay then
		self.unlockOverlay.Visible = isUnlocked
	end

	self:applyInputState()
end

function mouseController:createUnlockRequest(reason: string): MouseRequestToken
	assert(reason ~= "", "Mouse unlock requests require a non-empty reason")

	local token = {}
	self.unlockReasonsByToken[token] = reason
	self:updateUnlockState()

	return token
end

function mouseController:releaseUnlockRequest(token: MouseRequestToken?)
	if token == nil or self.unlockReasonsByToken[token] == nil then
		return
	end

	self.unlockReasonsByToken[token] = nil
	self:updateUnlockState()
end

function mouseController:createLockRequest(reason: string): MouseRequestToken
	assert(reason ~= "", "Mouse lock requests require a non-empty reason")

	local token = {}
	self.lockReasonsByToken[token] = reason
	self:applyInputState()

	return token
end

function mouseController:releaseLockRequest(token: MouseRequestToken?)
	if token == nil or self.lockReasonsByToken[token] == nil then
		return
	end

	self.lockReasonsByToken[token] = nil
	self:applyInputState()
end

function mouseController:onMenuStateChanged()
	self.__vars.isMenuActive = not not player:GetAttribute("InMenu")
	self:applyInputState()
end

function mouseController:onToggleLock(pressed: boolean)
	if not pressed or self.__vars.isMenuActive then
		return
	end

	self.__vars.isUserLockEnabled = not self.__vars.isUserLockEnabled
	self:applyInputState()
end

function mouseController:onRenderStepped(deltaTime: number)
	self:applyInputState()

	local crosshair = self.crosshair
	if crosshair then
		crosshair:update(deltaTime)
	end
end

function mouseController:preload(): boolean
	local interface = player.PlayerGui:WaitForChild("Interface") :: ScreenGui
	local mouseFrame = interface:WaitForChild("Mouse") :: GuiObject
	local iconFrame = mouseFrame:WaitForChild("Icon") :: GuiObject
	local crosshairFrame = iconFrame:WaitForChild("Crosshair") :: GuiObject
	if activeController ~= self then
		return false
	end

	self.unlockOverlay = createUnlockOverlay(interface)
	self.crosshair = crosshairController.new({
		mouseFrame = mouseFrame,
		crosshairFrame = crosshairFrame,
	})
	self:updateUnlockState()

	return true
end

function mouseController:init()
	if not self:preload() or activeController ~= self then
		return
	end

	self:onMenuStateChanged()
	self.connections.menuStateChanged = player:GetAttributeChangedSignal("InMenu"):Connect(function()
		self:onMenuStateChanged()
	end)
	self.toggleLockBind = inputBindings.create(keybinds.toggleMouseLock)
	self.connections.toggleLock = inputBindings.connect(
		self.toggleLockBind,
		function(_active: boolean, pressed: boolean)
			self:onToggleLock(pressed)
		end
	)
	self.connections.renderStepped = runService.RenderStepped:Connect(function(deltaTime: number)
		self:onRenderStepped(deltaTime)
	end)
end

function mouseController.new()
	if activeController then
		return activeController
	end

	local self = setmetatable({}, mouseController)

	self.connections = {}
	self.unlockReasonsByToken = {}
	self.lockReasonsByToken = {}
	self.unlockOverlay = nil
	self.crosshair = nil
	self.systemMouse = player:GetMouse()
	self.__vars = table.clone(mouseController.__vars)
	activeController = self

	task.defer(self.init, self)

	return self
end

function mouseController:destroy()
	if activeController ~= self then
		return
	end

	activeController = nil
	if self.toggleLockBind then
		self.toggleLockBind:Destroy()
	end
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	if self.crosshair then
		self.crosshair:destroy()
	end

	if self.unlockOverlay then
		self.unlockOverlay:Destroy()
	end

	userInputService.MouseBehavior = Enum.MouseBehavior.Default
	userInputService.MouseIconEnabled = true
	self.systemMouse.Icon = defaultCursorIcon
	table.clear(self.connections)
	table.clear(self.unlockReasonsByToken)
	table.clear(self.lockReasonsByToken)
	table.clear(self)
	setmetatable(self, nil)
end

function mouseController.acquireUnlock(reason: string): MouseRequestToken
	return getActiveController():createUnlockRequest(reason)
end

function mouseController.releaseUnlock(token: MouseRequestToken?)
	local controller = activeController
	if controller then
		controller:releaseUnlockRequest(token)
	end
end

function mouseController.hasUnlockRequests(): boolean
	local controller = activeController
	return controller ~= nil and hasRequests(controller.unlockReasonsByToken)
end

function mouseController.acquireLock(reason: string): MouseRequestToken
	return getActiveController():createLockRequest(reason)
end

function mouseController.releaseLock(token: MouseRequestToken?)
	local controller = activeController
	if controller then
		controller:releaseLockRequest(token)
	end
end

function mouseController.enterMenu()
	local controller = getActiveController()
	controller.__vars.isMenuActive = true
	controller:applyInputState()
end

function mouseController.leaveMenu()
	local controller = getActiveController()
	controller.__vars.isMenuActive = false
	controller:applyInputState()
end

function mouseController.setCameraBehavior(mouseBehavior: Enum.MouseBehavior)
	local controller = getActiveController()
	controller.__vars.cameraBehavior = mouseBehavior
	controller:applyInputState()
end

function mouseController.isLocked(): boolean
	local controller = activeController
	return controller == nil or controller.__vars.isLocked
end

function mouseController.isSystemCursorVisible(): boolean
	local controller = activeController
	return controller ~= nil and controller.__vars.isSystemCursorVisible
end

function mouseController.showCrosshairWeaponLines()
	local crosshair = getActiveController().crosshair
	if crosshair then
		crosshair:showWeaponLines()
	end
end

function mouseController.hideCrosshairWeaponLines()
	local controller = activeController
	if controller and controller.crosshair then
		controller.crosshair:hideWeaponLines()
	end
end

function mouseController.setCrosshairSpread(targetSpread: number)
	local crosshair = getActiveController().crosshair
	if crosshair then
		crosshair:setSpread(targetSpread)
	end
end

function mouseController.setCrosshairShake(targetShake: number)
	local crosshair = getActiveController().crosshair
	if crosshair then
		crosshair:setShake(targetShake)
	end
end

function mouseController.createHitmarker(damageResult: string?)
	local crosshair = getActiveController().crosshair
	if crosshair then
		crosshair:createHitmarker(damageResult)
	end
end

return mouseController
