--!strict

local runService = game:GetService("RunService")

local replicatedStorage = game:GetService("ReplicatedStorage")
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local inventoryRemotes = {}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), string.format("%s must be a Folder", existing:GetFullName()))
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemote(parent: Instance, name: string, className: "RemoteEvent" | "RemoteFunction"): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, string.format("%s must be a %s", existing:GetFullName(), className))
		return existing
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function waitForRemote(parent: Instance, name: string, className: string, timeoutSeconds: number): Instance?
	local deadline = os.clock() + timeoutSeconds
	repeat
		local remote = parent:FindFirstChild(name)
		if remote then
			if remote.ClassName ~= className then
				warn(string.format("[InventoryRemotes] %s is not a %s", remote:GetFullName(), className))
				return nil
			end
			return remote
		end
		task.wait()
	until os.clock() >= deadline

	warn(string.format("[InventoryRemotes] Timed out waiting for %s.%s", parent:GetFullName(), name))
	return nil
end

function inventoryRemotes.ensureServer(): RemoteFunction
	assert(runService:IsServer(), "ensureServer may only be called by the server")
	local communication = replicatedStorage:FindFirstChild("Communication")
	assert(communication, "ReplicatedStorage.Communication is missing")
	local functions = ensureFolder(communication, "RemoteFunctions")
	local request = ensureRemote(functions, "InventoryRequest", "RemoteFunction") :: RemoteFunction
	local events = communication:FindFirstChild("RemoteEvents")
	local oldReplication = events and events:FindFirstChild("InventoryReplication")
	if oldReplication then
		oldReplication:Destroy()
	end
	return request
end

function inventoryRemotes.waitForClient(timeoutSeconds: number?): RemoteFunction?
	assert(runService:IsClient(), "waitForClient may only be called by a client")
	local timeout = timeoutSeconds or protocol.Limits.remoteWaitSeconds
	local communication = replicatedStorage:FindFirstChild("Communication")
	if communication == nil then
		warn("[InventoryRemotes] ReplicatedStorage.Communication is missing")
		return nil
	end

	local functions = communication:FindFirstChild("RemoteFunctions")
	if functions == nil then
		warn("[InventoryRemotes] RemoteFunctions folder is missing")
		return nil
	end

	return waitForRemote(functions, "InventoryRequest", "RemoteFunction", timeout) :: RemoteFunction?
end

return inventoryRemotes
