local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")

local clientData = require(replicatedFirst.ClientData)
local guiUtilities = require(replicatedFirst.ClientUtilities.GuiUtils)
local audioUtilities = require(replicatedStorage.SharedUtilities.AudioUtils)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local interfaceEffects = replicatedStorage.SharedAssets.Effects.Interface
local hitmarkerSounds = replicatedStorage.SharedAssets.Effects.Sounds.Hitmarker
local failedHitmarkerSounds = hitmarkerSounds.Fail:GetChildren()
local hitmarkerPreset = interfaceEffects.Hitmarker

local blockedDamageResult = "blocked"
local criticalDamageResult = "critical"
local minimumVisibleShake = 0.01
local weaponLineTransition = TweenInfo.new(0.25)
local crosshairPositionsByName = {
	Top = UDim2.fromScale(0.5, 0.5),
	Right = UDim2.fromScale(0.5, 0.5),
	Left = UDim2.fromScale(0.5, 0.5),
	Bottom = UDim2.fromScale(0.5, 0.5),
}
local crosshairDirectionsByName = {
	Top = UDim2.fromOffset(0, -1),
	Right = UDim2.fromOffset(1, 0),
	Left = UDim2.fromOffset(-1, 0),
	Bottom = UDim2.fromOffset(0, 1),
}

local crosshairController = {}
crosshairController.__index = crosshairController
crosshairController.__vars = {
	spreadCurrent = 0,
	spreadTarget = 0,
	spreadLerpSpeed = 13,
	shakeCurrent = 0,
	shakeTarget = 0,
	shakeLerpSpeed = 18,
	shakeMaximumRotation = 6,
	shakeRotation = 0,
	defaultMargin = 2,
	blockShakeIntensity = 0,
	blockShakeTriggerIntensity = 0.25,
	blockShakeDecaySpeed = 6,
	blockZoomIntensity = 0,
	blockZoomTriggerIntensity = -30,
	blockZoomDecaySpeed = 30,
}

export type CrosshairControllerInfo = {
	mouseFrame: GuiObject,
	crosshairFrame: GuiObject,
}

local function multiplyUDim2(dimensions: UDim2, multiplier: number): UDim2
	return UDim2.new(
		dimensions.X.Scale * multiplier,
		dimensions.X.Offset * multiplier,
		dimensions.Y.Scale * multiplier,
		dimensions.Y.Offset * multiplier
	)
end

local function getHitmarkerColor(damageResult: string?): Color3
	if damageResult == criticalDamageResult then
		return Color3.new(1, 0, 0)
	end

	if damageResult == blockedDamageResult then
		return Color3.new(0.5, 0.8, 1)
	end

	return Color3.new(1, 1, 1)
end

function crosshairController:showReticle()
	self.crosshairFrame.Visible = true
end

function crosshairController:hideReticle()
	self.crosshairFrame.Visible = false
end

function crosshairController:showWeaponLines()
	for _, weaponLine in pairs(self.weaponLines) do
		guiUtilities.changeGuiState({
			frame = weaponLine,
			state = true,
			tweenInfo = weaponLineTransition,
		})
	end
end

function crosshairController:hideWeaponLines()
	for _, weaponLine in pairs(self.weaponLines) do
		guiUtilities.changeGuiState({
			frame = weaponLine,
			state = false,
			tweenInfo = weaponLineTransition,
		})
	end
end

function crosshairController:initializeWeaponLines()
	for _, weaponLine in pairs(self.weaponLines) do
		guiUtilities.changeGuiState({
			frame = weaponLine,
			state = false,
		})
	end
end

function crosshairController:setSpread(targetSpread: number)
	self.__vars.spreadTarget = targetSpread
end

function crosshairController:setShake(targetShake: number)
	self.__vars.shakeTarget = math.clamp(targetShake, 0, 1)
end

function crosshairController:renderSpread()
	local stateValues = self.__vars
	local spreadOffset = stateValues.defaultMargin * (stateValues.defaultMargin + stateValues.spreadCurrent)

	for crosshairName, basePosition in pairs(crosshairPositionsByName) do
		local crosshairArm = self.crosshairFrame:FindFirstChild(crosshairName)
		if not crosshairArm or not crosshairArm:IsA("GuiObject") then
			continue
		end

		local direction = crosshairDirectionsByName[crosshairName]
		crosshairArm.Position = basePosition + multiplyUDim2(direction, spreadOffset)
	end
end

function crosshairController:updateInterpolation(deltaTime: number)
	local stateValues = self.__vars
	local spreadAlpha = mathUtilities.exponentialAlpha(stateValues.spreadLerpSpeed, deltaTime)
	local shakeAlpha = mathUtilities.exponentialAlpha(stateValues.shakeLerpSpeed, deltaTime)

	stateValues.spreadCurrent = mathUtilities.lerp(stateValues.spreadCurrent, stateValues.spreadTarget, spreadAlpha)
	stateValues.shakeCurrent = mathUtilities.lerp(stateValues.shakeCurrent, stateValues.shakeTarget, shakeAlpha)
end

function crosshairController:updateShakeRotation()
	local stateValues = self.__vars
	if stateValues.shakeCurrent < minimumVisibleShake then
		stateValues.shakeRotation = 0
		return
	end

	local horizontalShake = math.noise(os.clock() * 60, 0, 0)
	stateValues.shakeRotation = horizontalShake * stateValues.shakeCurrent * stateValues.shakeMaximumRotation
end

function crosshairController:updateBlockShake(deltaTime: number)
	local stateValues = self.__vars
	if stateValues.blockShakeIntensity <= minimumVisibleShake then
		stateValues.blockShakeIntensity = 0
		return
	end

	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		currentCamera.CFrame *= mathUtilities.getCameraShake(stateValues.blockShakeIntensity, deltaTime)
	end

	local decayAlpha = mathUtilities.exponentialAlpha(stateValues.blockShakeDecaySpeed, deltaTime)
	stateValues.blockShakeIntensity = mathUtilities.lerp(stateValues.blockShakeIntensity, 0, decayAlpha)
end

function crosshairController:updateBlockZoom(deltaTime: number)
	local stateValues = self.__vars
	if math.abs(stateValues.blockZoomIntensity) <= minimumVisibleShake then
		stateValues.blockZoomIntensity = 0
		clientData.fieldOfViewModifiers.block = nil
		return
	end

	local decayAlpha = mathUtilities.exponentialAlpha(stateValues.blockZoomDecaySpeed, deltaTime)
	stateValues.blockZoomIntensity = mathUtilities.lerp(stateValues.blockZoomIntensity, 0, decayAlpha)
	clientData.fieldOfViewModifiers.block = stateValues.blockZoomIntensity
end

function crosshairController:renderFrame()
	local mouseFrame = self.mouseFrame

	mouseFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mouseFrame.Position = UDim2.fromScale(0.5, 0.5)
	mouseFrame.Rotation = self.__vars.shakeRotation
end

function crosshairController:playHitmarkerSounds(damageResult: string?)
	audioUtilities.playSound({
		sound = hitmarkerSounds.Regular,
		useAcousticSimulation = false,
		playbackSpeed = math.random(900, 1100) / 1000,
		parent = self.mouseFrame,
	})

	if damageResult ~= blockedDamageResult or #failedHitmarkerSounds == 0 then
		return
	end

	audioUtilities.playSound({
		sound = failedHitmarkerSounds[math.random(1, #failedHitmarkerSounds)],
		useAcousticSimulation = false,
		parent = self.mouseFrame,
	})
end

function crosshairController:applyBlockedHitFeedback(damageResult: string?)
	if damageResult ~= blockedDamageResult then
		return
	end

	local stateValues = self.__vars
	stateValues.blockShakeIntensity = stateValues.blockShakeTriggerIntensity
	stateValues.blockZoomIntensity = stateValues.blockZoomTriggerIntensity
end

function crosshairController:createHitmarker(damageResult: string?)
	local hitmarker = hitmarkerPreset:Clone()
	hitmarker.Rotation = math.random(-5, 5)
	hitmarker.ImageColor3 = getHitmarkerColor(damageResult)
	hitmarker.Parent = self.mouseFrame

	local hitmarkerTween = tweenService:Create(hitmarker, TweenInfo.new(0.2), {
		ImageTransparency = 1,
		Rotation = 0,
		ImageColor3 = Color3.new(1, 1, 1),
	})
	local hitmarkerTweens = self.hitmarkerTweens
	hitmarkerTweens[hitmarker] = hitmarkerTween
	hitmarkerTween.Completed:Once(function()
		hitmarkerTweens[hitmarker] = nil
		hitmarker:Destroy()
	end)

	self:playHitmarkerSounds(damageResult)
	self:applyBlockedHitFeedback(damageResult)
	hitmarkerTween:Play()
end

function crosshairController:update(deltaTime: number)
	self:updateInterpolation(deltaTime)
	self:updateShakeRotation()
	self:updateBlockShake(deltaTime)
	self:updateBlockZoom(deltaTime)
	self:renderSpread()
	self:renderFrame()
end

function crosshairController:init()
	self:initializeWeaponLines()
	self.crosshairFrame.Visible = true
	self.mouseFrame.Visible = true
end

function crosshairController.new(controllerInfo: CrosshairControllerInfo)
	local self = setmetatable({}, crosshairController)

	self.mouseFrame = controllerInfo.mouseFrame
	self.crosshairFrame = controllerInfo.crosshairFrame
	self.hitmarkerTweens = {}
	self.weaponLines = {}
	self.__vars = table.clone(crosshairController.__vars)

	for weaponLineName in pairs(crosshairPositionsByName) do
		local weaponLine = self.crosshairFrame:FindFirstChild(weaponLineName)
		if weaponLine and weaponLine:IsA("GuiObject") then
			self.weaponLines[weaponLineName] = weaponLine
		end
	end

	self:init()

	return self
end

function crosshairController:destroy()
	local hitmarkerTweens = self.hitmarkerTweens
	local ownedHitmarkerTweens = table.clone(hitmarkerTweens)
	table.clear(hitmarkerTweens)

	for hitmarker, hitmarkerTween in pairs(ownedHitmarkerTweens) do
		hitmarkerTween:Cancel()
		hitmarker:Destroy()
	end

	self.mouseFrame.Visible = false
	clientData.fieldOfViewModifiers.block = nil
	table.clear(ownedHitmarkerTweens)
	table.clear(self.weaponLines)
	table.clear(self)
	setmetatable(self, nil)
end

return crosshairController
