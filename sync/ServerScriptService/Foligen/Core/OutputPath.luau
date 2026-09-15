--||------------------------------------------------------------------||
--||                   Foligen Module | OutputPath                    ||
--||------------------------------------------------------------------||
--|| Author:                                                          ||
--||  kaboomproduct (kaboom366)                                       ||
--||------------------------------------------------------------------||
--|| Description:                                                     ||
--||  Resolves, creates, labels, and clears output folders.           ||
--||------------------------------------------------------------------||
--|| Version: 3.1                                                     ||
--||------------------------------------------------------------------||

local outputPath = {}

local function getPathRoot(rootName: string): Instance?
	if rootName == "script" then
		return script
	end

	if rootName == "workspace" then
		return workspace
	end

	if rootName == "game" then
		return game
	end

	if rootName == "ServerStorage" then
		return game:GetService("ServerStorage")
	end

	if rootName == "ReplicatedStorage" then
		return game:GetService("ReplicatedStorage")
	end

	if rootName == "ServerScriptService" then
		return game:GetService("ServerScriptService")
	end

	return nil
end

local function ensurePathChild(parent: Instance, childName: string, mustBeFolder: boolean): Instance?
	local existingChild = parent:FindFirstChild(childName)
	if existingChild then
		if existingChild:IsA("Folder") then
			return existingChild
		end

		if not mustBeFolder then
			warn(("Foligen | Traversing non-Folder path segment %s under %s"):format(childName, parent:GetFullName()))
			return existingChild
		end

		warn(("Foligen | Output path segment %s under %s is not a Folder"):format(childName, parent:GetFullName()))
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = childName
	folder.Parent = parent

	return folder
end

function outputPath.getLabel(pathSegments: { string }): string
	return table.concat(pathSegments, ".")
end

function outputPath.getRootFolder(pathSegments: { string }): Folder?
	local currentParent = getPathRoot(pathSegments[1])
	if currentParent == nil then
		warn(("Foligen | Unsupported output path root %s"):format(tostring(pathSegments[1])))
		return nil
	end

	for pathIndex = 2, #pathSegments do
		local isLastSegment = pathIndex == #pathSegments
		local nextChild = ensurePathChild(currentParent, pathSegments[pathIndex], isLastSegment)
		if nextChild == nil then
			return nil
		end

		currentParent = nextChild
	end

	if currentParent:IsA("Folder") then
		return currentParent
	end

	if currentParent == workspace then
		warn("Foligen | Output path cannot target workspace directly; include a folder name in runtime.output.path")
		return nil
	end

	warn(("Foligen | Output path %s did not resolve to a Folder"):format(outputPath.getLabel(pathSegments)))
	return nil
end

function outputPath.destroyIfExists(pathSegments: { string })
	local currentParent = getPathRoot(pathSegments[1])
	if currentParent == nil then
		return
	end

	for pathIndex = 2, #pathSegments - 1 do
		local child = currentParent:FindFirstChild(pathSegments[pathIndex])
		if child == nil then
			return
		end

		currentParent = child
	end

	local outputFolder = currentParent:FindFirstChild(pathSegments[#pathSegments])
	if outputFolder and outputFolder:IsA("Folder") then
		outputFolder:Destroy()
	end
end

return outputPath
