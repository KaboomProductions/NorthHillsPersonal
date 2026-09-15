--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local projectileCosmetics = {}
projectileCosmetics.__index = projectileCosmetics
local types = require(script.Parent.Parent.Contracts)
local templateService = require(script.Parent.Templates)

export type Cosmetics = types.ProjectileCosmetics
type TemplateService = templateService.TemplateService

function projectileCosmetics.new(templateServiceInstance: TemplateService): Cosmetics
	return (
		setmetatable({
			templates = templateServiceInstance,
			folder = replicatedStorage.SharedAssets.Effects.Particles.Projectiles,
			ensure = projectileCosmetics.ensure,
		}, projectileCosmetics) :: unknown
	) :: Cosmetics
end

function projectileCosmetics:ensure(itemType: string): Model?
	local existing = self.folder:FindFirstChild(itemType)
	if existing and existing:IsA("Model") then
		return existing
	end

	local template = self.templates:getTemplate(itemType)
	if template == nil then
		return nil
	end
	local clone = template:Clone()
	if not clone:IsA("Model") then
		clone:Destroy()
		return nil
	end
	local cosmetic = clone
	cosmetic.Name = itemType
	for _, descendant in ipairs(cosmetic:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
	cosmetic.Parent = self.folder
	return (cosmetic :: unknown) :: Model
end

return projectileCosmetics
