local players = game:GetService("Players")
local replicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")

local clientData = require(replicatedFirst.ClientData)
local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)

local player = players.LocalPlayer
local effects = {}

local function getOrCreateVignetteTemplate(): ImageLabel?
	local interface = player.PlayerGui:WaitForChild("Interface")
	local vignettes = interface:WaitForChild("Vignettes")
	local templateName = clientData.vignetteTemplateName
	local templateVignette = vignettes:FindFirstChild(templateName)
	if templateVignette == nil or not templateVignette:IsA("ImageLabel") then
		return nil
	end

	return templateVignette
end

local function getOrCreateRuntimeVignette(vignetteName: string): ImageLabel?
	local existingVignette = clientData.vignettes[vignetteName]
	if existingVignette and existingVignette.Parent ~= nil then
		return existingVignette
	end

	local vignetteTemplate = getOrCreateVignetteTemplate()
	if vignetteTemplate == nil then
		return nil
	end

	local vignettes = vignetteTemplate.Parent
	if vignettes == nil then
		return nil
	end

	local foundVignette = vignettes:FindFirstChild(vignetteName)
	if foundVignette and foundVignette:IsA("ImageLabel") then
		clientData.vignettes[vignetteName] = foundVignette
		return foundVignette
	end

	local vignette = vignetteTemplate:Clone()
	vignette.Name = vignetteName
	vignette.ImageColor3 = Color3.new(0, 0, 0)
	vignette.ImageTransparency = 1
	vignette.Visible = true
	vignette.ZIndex = vignetteTemplate.ZIndex
	vignette.Parent = vignettes

	clientData.vignettes[vignetteName] = vignette
	return vignette
end

function effects.preload(controller)
	controller.vignette = getOrCreateRuntimeVignette("Crouching")
end

function effects.update(controller, deltaTime: number)
	local vignette = controller.vignette
	if vignette == nil then
		return
	end

	local alpha = mathUtilities.exponentialAlpha(controller.__vars.vignetteFadeSpeed, deltaTime)
	controller.currentVignetteTransparency = mathUtilities.lerp(
		controller.currentVignetteTransparency,
		controller.targetVignetteTransparency,
		alpha
	)
	vignette.ImageTransparency = controller.currentVignetteTransparency
end

function effects.destroy(controller)
	clientData.speedModifiers.crouching = nil
	clientData.fieldOfViewModifiers.crouching = nil

	if controller.vignette then
		controller.vignette.ImageTransparency = controller.__vars.vignetteHiddenTransparency
	end
end

return effects
