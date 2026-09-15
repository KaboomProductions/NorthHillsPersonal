--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local materialConfigs = replicatedStorage.SharedAssets.Dictionaries.MaterialConfigs

local materialUtilities = {}

export type MaterialConfig = {
	displayName: string,
	description: string,
	imageId: number?,
}

function materialUtilities.getMaterialConfig(materialType: string): MaterialConfig?
	local configModule = materialConfigs:FindFirstChild(materialType)
	if configModule == nil or not configModule:IsA("ModuleScript") then
		return nil
	end

	return require(configModule) :: MaterialConfig
end

function materialUtilities.isMaterialType(materialType: unknown): boolean
	return typeof(materialType) == "string" and materialUtilities.getMaterialConfig(materialType) ~= nil
end

return materialUtilities
