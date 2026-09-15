local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local gamepadService = game:GetService("GamepadService")
local guiService = game:GetService("GuiService")
local starterGui = game:GetService("StarterGui")
local userInputService = game:GetService("UserInputService")

local soundGroups = replicatedStorage.SharedAssets.SoundGroups
local skipMenuIfInStudio = replicatedStorage.Values.SkipMenuIfInStudio

local audio = workspace.Audio
local music = audio.Music
local menuTheme = music.Menu

local player = players.LocalPlayer
local mouse = player:GetMouse()
local currentCamera = workspace.CurrentCamera

local playerGui = player:WaitForChild("PlayerGui")

local function waitForScreenGui(name: string): ScreenGui
	local gui = playerGui:WaitForChild(name, 30)
	if gui == nil then
		error(
			string.format(
				"[Menu] PlayerGui.%s is missing; StarterGui must provide the Menu and Interface ScreenGuis",
				name
			)
		)
	end
	if not gui:IsA("ScreenGui") then
		error(string.format("[Menu] PlayerGui.%s must be a ScreenGui", name))
	end
	return gui
end

local menuGui = waitForScreenGui("Menu")
local interfaceGui = waitForScreenGui("Interface")

local ignore = workspace.Ignore
local otherIgnored = ignore.Other

local mainFrame = menuGui:WaitForChild("Main")
local headingFrame = mainFrame.Heading
local buttonsFolder = headingFrame.Buttons
local tabsFolder = mainFrame.Tabs
local buttonControllerFolder = script:WaitForChild("Buttons")

local startupFrame = menuGui.Startup
local gradientFrame = startupFrame.Gradient
local iconFrame = startupFrame.Icon

local clientControllers = replicatedFirst.ClientControllers
local characterControllers = clientControllers.Character:GetChildren()
local playerControllers = clientControllers.Player:GetChildren()

local sharedAssets = replicatedStorage.SharedAssets
local effects = sharedAssets.Effects
local sounds = effects.Sounds
local launchSound = sounds.Launch

local topbarPlus = require(replicatedStorage.SharedClasses.TopbarPlus)
local networking = require(replicatedStorage.Communication.Networking)
local clientRuntime = require(replicatedFirst.ClientData.ClientRuntime)
local assetPreloader = require(replicatedFirst.ClientUtilities.AssetPreloader)
local mainController = require(replicatedFirst.ClientUtilities.MainController)
local connectionUtilities = require(replicatedStorage.SharedUtilities.ConnectionUtils)
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local mouseController = require(replicatedFirst.ClientControllers.Player.Interface.Mouse)
local menuAnimator = require(script:WaitForChild("Animator"))
local tabAnimatorModule = require(script:WaitForChild("TabAnimator"))

local menuButton = topbarPlus.new()
menuButton:setImage(98187065963241)
menuButton:setEnabled(false)

local menuController = {}
menuController.__index = menuController
menuController.__vars = {
	autoSelectGuiWasEnabled = true,
	guiNavigationWasEnabled = true,
	hasSavedGuiNavigationState = false,
}

type NamedConnections = { [string]: RBXScriptConnection? }
menuController.cameraLastingTime = 10
menuController.playerStudsUnder = 128
menuController.viewportScale = 3

local cameraDurationSeconds = 10
local viewportScale = 3

local function createInvisibleSelectionImage(): GuiObject
	local container = Instance.new("Frame")
	container.Name = "GamepadSelectionImageContainer"
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = menuGui

	local selectionImage = Instance.new("Frame")
	selectionImage.Name = "InvisibleSelectionImage"
	selectionImage.BackgroundTransparency = 1
	selectionImage.BorderSizePixel = 0
	selectionImage.Size = UDim2.fromScale(1, 1)
	selectionImage.Parent = container

	return selectionImage
end

function menuController:preload()
	player:WaitForChild("Settings", 3)
	player:SetAttribute("InMenu", true)
	mouseController.enterMenu()

	starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

	assetPreloader.preload(sounds:GetDescendants())

	repeat
		runService.PreRender:Wait()

		local success = pcall(function()
			starterGui:SetCore("ResetButtonCallback", false)
		end)
	until success

	self.menuCams = otherIgnored.MenuCams:GetChildren()
	self.mouseOffset = self.mouseOffset or CFrame.identity
	self.yieldTimer = 3
	self.invisibleSelectionImage = createInvisibleSelectionImage()

	for _, controllerModule in buttonControllerFolder:GetChildren() do
		if not controllerModule:IsA("ModuleScript") then
			continue
		end

		self.buttonControllerClasses[controllerModule.Name] = require(controllerModule)
	end
end

function menuController:disconnectNamedConnection(connections: NamedConnections, connectionName: string)
	connectionUtilities.disconnectConnection(connections[connectionName])
end

function menuController:clearControllersFromSource(hookName: string, source: { any })
	if self.hooks[hookName] then
		self.hooks[hookName]:destroy()
		self.hooks[hookName] = nil
	end

	table.clear(source)
end

function menuController:hookControllersFromSource(hookName: string, source: Folder | { ModuleScript })
	if self.hooks[hookName] then
		self.hooks[hookName]:destroy()
		self.hooks[hookName] = nil
	end

	self.hooks[hookName] = mainController.new(source)

	return self.hooks[hookName].activeControllers
end

function menuController:hookCharacter(character: Model?)
	character = character or player.Character

	self:disconnectNamedConnection(self.afterConnections, "onDied")
	self:disconnectNamedConnection(self.afterConnections, "onDestroy")

	self:clearControllersFromSource("character", clientRuntime.activeCharacterControllers)

	if not character then
		return
	end

	self.currentHumanoid = character:WaitForChild("Humanoid", 3)

	if not self.currentHumanoid then
		warn("menuController: Humanoid not found on character", character:GetFullName())
		return
	end

	clientRuntime.activeCharacterControllers = self:hookControllersFromSource("character", characterControllers)

	self.afterConnections.onDied = self.currentHumanoid.Died:Once(function()
		self:clearControllersFromSource("character", clientRuntime.activeCharacterControllers)
	end)

	self.afterConnections.onDestroy = player.CharacterRemoving:Connect(function(oldCharacter: Model)
		if oldCharacter == character then
			self:clearControllersFromSource("character", clientRuntime.activeCharacterControllers)
		end
	end)
end

function menuController:hookPlayerControllers()
	if clientRuntime.hasLoadedPlayerControllers then
		return
	end

	clientRuntime.activePlayerControllers = self:hookControllersFromSource("player", playerControllers)
	clientRuntime.hasLoadedPlayerControllers = true
end

function menuController:hookCharacterControllers()
	self:disconnectNamedConnection(self.afterConnections, "characterAdded")
	self:clearCharacterControllers()

	self.afterConnections.characterAdded = player.CharacterAdded:Connect(function(character)
		self:hookCharacter(character)
	end)

	self:hookCharacter()
end

function menuController:clearCharacterControllers()
	self:clearControllersFromSource("character", clientRuntime.activeCharacterControllers)
end

function menuController:destroyButtonControllers()
	for controllerName, buttonController in self.buttonControllers do
		buttonController:destroy()
		self.buttonControllers[controllerName] = nil
	end
end

function menuController:destroyButtonAnimator()
	if self.animator then
		self.animator:destroy()
		self.animator = nil
	end
end

function menuController:destroyTabAnimator()
	if self.tabAnimator then
		self.tabAnimator:destroy()
		self.tabAnimator = nil
	end
end

function menuController:destroyMenuUi()
	if self.cameraThread then
		if coroutine.status(self.cameraThread) == "running" then
			coroutine.close(self.cameraThread)
		end

		self.cameraThread = nil
	end

	if self.transitionFrame then
		self.transitionFrame:Destroy()
		self.transitionFrame = nil
	end

	connectionUtilities.disconnectConnections(self.menuConnections)
	self:destroyButtonControllers()
	self:destroyButtonAnimator()
	self:destroyTabAnimator()
end

function menuController:enableVirtualCursorMode()
	local stateValues = self.__vars

	if not stateValues.hasSavedGuiNavigationState then
		stateValues.guiNavigationWasEnabled = guiService.GuiNavigationEnabled
		stateValues.autoSelectGuiWasEnabled = guiService.AutoSelectGuiEnabled
		self.previousSelectionImage = playerGui.SelectionImageObject
		stateValues.hasSavedGuiNavigationState = true
	end

	guiService.GuiNavigationEnabled = false
	guiService.AutoSelectGuiEnabled = false
	guiService.SelectedObject = nil
	playerGui.SelectionImageObject = self.invisibleSelectionImage
	self:updateVirtualCursor()
end

function menuController:updateVirtualCursor()
	if not self.__vars.hasSavedGuiNavigationState then
		return
	end

	if userInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		gamepadService:EnableGamepadCursor(mainFrame)
	else
		gamepadService:DisableGamepadCursor()
	end
end

function menuController:disableVirtualCursorMode()
	local stateValues = self.__vars

	gamepadService:DisableGamepadCursor()
	guiService.SelectedObject = nil

	if not stateValues.hasSavedGuiNavigationState then
		return
	end

	guiService.GuiNavigationEnabled = stateValues.guiNavigationWasEnabled
	guiService.AutoSelectGuiEnabled = stateValues.autoSelectGuiWasEnabled
	playerGui.SelectionImageObject = self.previousSelectionImage
	self.previousSelectionImage = nil
	stateValues.hasSavedGuiNavigationState = false
end

function menuController:connectVirtualCursorInput()
	self.afterConnections.preferredInputChanged = userInputService
		:GetPropertyChangedSignal("PreferredInput")
		:Connect(function()
			self:updateVirtualCursor()
		end)
end

function menuController:createTransitionFrame()
	local newFrame = Instance.new("Frame")
	newFrame.Size = UDim2.fromScale(1, 1)
	newFrame.BackgroundColor3 = Color3.new()
	newFrame.BackgroundTransparency = 1
	newFrame.ZIndex = 0
	newFrame.Parent = menuGui

	return newFrame
end

function menuController:transitionToNewCamera()
	local chosenCamera = nil
	local availableCameras = {}

	for _, camera in self.menuCams do
		if not camera:IsA("BasePart") then
			continue
		end

		if camera == self.currentMenuCam then
			continue
		end

		table.insert(availableCameras, camera)
	end

	while not chosenCamera do
		chosenCamera = availableCameras[math.random(1, #availableCameras)]
		runService.PreRender:Wait()
	end

	self.currentMenuCam = chosenCamera

	currentCamera.CameraType = Enum.CameraType.Scriptable
	networking.events.replicateStreaming:FireServer(self.currentMenuCam.CFrame)

	self.cameraTransitionId = (self.cameraTransitionId or 0) + 1
	local transitionId = self.cameraTransitionId

	self.cameraThread = task.delay(cameraDurationSeconds, function()
		if transitionId ~= self.cameraTransitionId then
			return
		end

		self.transitionFrame = self:createTransitionFrame()
		self.currentTransition = tweenService:Create(self.transitionFrame, TweenInfo.new(1), {
			BackgroundTransparency = 0,
		})

		self.currentTransition:Play()

		self.menuConnections.transitionEnded = self.currentTransition.Completed:Once(function()
			self:transitionToNewCamera()

			task.wait(1)

			if self.transitionFrame then
				self.currentTransition = tweenService:Create(self.transitionFrame, TweenInfo.new(1), {
					BackgroundTransparency = 1,
				})

				self.currentTransition:Play()

				self.menuConnections.transitionEnded = self.currentTransition.Completed:Once(function()
					self.transitionFrame:Destroy()
					self.transitionFrame = nil
				end)
			end
		end)
	end)
end

function menuController:createButtonController(buttonFrame: Frame)
	local buttonControllerClass = self.buttonControllerClasses[buttonFrame.Name]
	local actualButton = buttonFrame:FindFirstChildOfClass("TextButton")

	if not actualButton or not buttonControllerClass then
		return
	end

	actualButton.SelectionImageObject = self.invisibleSelectionImage
	self.buttonControllers[buttonFrame.Name] = buttonControllerClass.new({
		menuController = self,
		buttonFrame = buttonFrame,
		button = actualButton,
		animator = self.animator,
	})
end

function menuController:toggleTab(tabName: string)
	if self.tabAnimator then
		self.tabAnimator:toggleTab(tabName)
	end
end

function menuController:hookButtonControllers()
	local buttonContents = buttonsFolder:GetChildren()
	self.animator = menuAnimator.new(buttonContents)
	self.tabAnimator = tabAnimatorModule.new(tabsFolder)

	for _, buttonFrame in buttonContents do
		if not buttonFrame:IsA("Frame") then
			continue
		end

		self:createButtonController(buttonFrame)
	end
end

function menuController:presentStudio()
	launchSound:Play()
	iconFrame.Size = UDim2.fromScale(0.171, 0.413)

	tweenService
		:Create(gradientFrame, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			BackgroundTransparency = 0,
		})
		:Play()

	task.wait(1)

	tweenService
		:Create(iconFrame, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			ImageTransparency = 0,
		})
		:Play()

	tweenService
		:Create(iconFrame, TweenInfo.new(3, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(0.256, 0.619),
		})
		:Play()

	task.wait(4)

	tweenService
		:Create(iconFrame, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			ImageTransparency = 1,
		})
		:Play()

	tweenService
		:Create(gradientFrame, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			BackgroundTransparency = 1,
		})
		:Play()

	task.wait(1)

	tweenService
		:Create(startupFrame, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			BackgroundTransparency = 1,
		})
		:Play()
end

function menuController:exitMenu()
	menuGui.Enabled = false
	interfaceGui.Enabled = true

	self.cameraTransitionId = (self.cameraTransitionId or 0) + 1
	self.currentMenuCam = nil

	starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	self:destroyMenuUi()

	networking.events.replicateStreaming:FireServer()
	networking.events.replicateMenu:FireServer(false)

	self:disableVirtualCursorMode()

	currentCamera.CameraType = Enum.CameraType.Custom
	mouseController.leaveMenu()

	if self.themeVolumeTween then
		self.themeVolumeTween:Cancel()
		self.themeVolumeTween = nil
	end

	self.themeVolumeTween = tweenService:Create(menuTheme, TweenInfo.new(2), {
		Volume = 0,
	})

	self.themeVolumeTween:Play()

	audioUtilities.applyEqualizerToSoundGroups({
		equalizerId = "menu",
		tweenInfo = TweenInfo.new(8),

		groups = {
			soundGroups.Music,
			soundGroups.MusicDay,
			soundGroups.MusicEntity,
		},

		properties = {
			HighGain = 0,
			LowGain = 0,
			MidGain = 0,
		},
	})

	menuButton:setEnabled(true)
end

function menuController:loadMenu()
	menuButton:setEnabled(false)
	networking.events.replicateMenu:FireServer(true)
	mouseController.enterMenu()

	starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

	self:destroyMenuUi()

	if self.themeVolumeTween then
		self.themeVolumeTween:Cancel()
		self.themeVolumeTween = nil
	end

	menuTheme.Volume = 0

	self.themeVolumeTween = tweenService:Create(menuTheme, TweenInfo.new(3), {
		Volume = 0.5,
	})

	self.themeVolumeTween:Play()
	menuTheme:Play()

	audioUtilities.applyEqualizerToSoundGroups({
		equalizerId = "menu",
		tweenInfo = TweenInfo.new(2),

		groups = {
			soundGroups.Music,
			soundGroups.MusicDay,
			soundGroups.MusicEntity,
		},

		properties = {
			HighGain = -100,
			LowGain = -100,
			MidGain = -100,
		},
	})

	interfaceGui.Enabled = false
	mainFrame.Visible = true
	menuGui.Enabled = true
	self:enableVirtualCursorMode()

	self:hookButtonControllers()
	self:transitionToNewCamera()

	self.menuConnections.update = runService.RenderStepped:Connect(function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function menuController:update(deltaTime: number)
	if self.animator then
		self.animator:update(deltaTime)
	end

	if self.tabAnimator then
		self.tabAnimator:update(deltaTime)
	end

	if self.currentMenuCam then
		local xOffset = ((mouse.X - mouse.ViewSizeX * 0.5) / mouse.ViewSizeX) * -viewportScale
		local yOffset = ((mouse.Y - mouse.ViewSizeY * 0.5) / mouse.ViewSizeY) * -viewportScale

		local targetOffset = CFrame.Angles(math.rad(yOffset), math.rad(xOffset), 0)
		self.mouseOffset = self.mouseOffset:Lerp(targetOffset, math.min(deltaTime * 8, 1))

		currentCamera.CFrame = self.currentMenuCam.CFrame * self.mouseOffset
	end
end

function menuController:init()
	self:connectVirtualCursorInput()
	local shouldSkipInitialMenu = runService:IsStudio() and skipMenuIfInStudio.Value

	audioUtilities.applyEqualizerToSoundGroups({
		equalizerId = "menu",
		tweenInfo = TweenInfo.new(),

		groups = {
			soundGroups.Music,
			soundGroups.MusicDay,
			soundGroups.MusicEntity,
			soundGroups.Ambience,
		},

		properties = {
			HighGain = -100,
			LowGain = -100,
			MidGain = -100,
		},
	})

	if shouldSkipInitialMenu then
		menuGui.Enabled = false
		interfaceGui.Enabled = true
	else
		interfaceGui.Enabled = false
		mainFrame.Visible = true
		menuGui.Enabled = true
	end

	self:preload()

	if not shouldSkipInitialMenu then
		repeat
			local deltaTime = runService.PreRender:Wait()
			self.yieldTimer = self.yieldTimer - deltaTime
		until game:IsLoaded() or self.yieldTimer <= 0

		self:presentStudio()
	end

	audioUtilities.applyEqualizerToSoundGroups({
		equalizerId = "menu",
		tweenInfo = TweenInfo.new(2),

		groups = {
			soundGroups.Ambience,
		},

		properties = {
			HighGain = 0,
			LowGain = 0,
			MidGain = 0,
		},
	})

	if shouldSkipInitialMenu then
		player:SetAttribute("InMenu", false)
		self:exitMenu()
	end

	task.spawn(function()
		self:hookPlayerControllers()
		self:hookCharacterControllers()
	end)

	if not shouldSkipInitialMenu then
		self:loadMenu()
	end

	menuButton:bindEvent("selected", function()
		menuButton:deselect()
		self:loadMenu()
	end)
end

function menuController.new()
	local self = setmetatable({}, menuController)

	self.hooks = {}
	self.buttonControllerClasses = {}
	self.buttonControllers = {}
	self.menuConnections = {}
	self.afterConnections = {}
	self.__vars = table.clone(menuController.__vars)
	self.animator = nil
	self.tabAnimator = nil
	self.invisibleSelectionImage = nil
	self.previousSelectionImage = nil

	task.defer(self.init, self)

	return self
end

return menuController
