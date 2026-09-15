local runService = game:GetService("RunService")
local players = game:GetService("Players")

local characterReplication = require(game:GetService("ReplicatedStorage").SharedUtilities.CharacterReplication)
local characterReplicationController = require(script.Parent.CharacterReplication)

local headController = {}
headController.__index = headController

local defaultValues = {
	lerpSpeed = 10,
	defaultTorsoY = 180,
}

function headController:init()
	self.yOffset = self.neck.C0.Y
	self.targetNeckC0 = self.neck.C0

	runService:UnbindFromRenderStep("HeadController")

	runService:BindToRenderStep("HeadController", Enum.RenderPriority.Character.Value, function(deltaTime)
		if self.character and self.character:GetAttribute("Ragdolled") then
			return
		end

		local cameraDirection = self.rootPart.CFrame:ToObjectSpace(self.camera.CFrame).LookVector

		local torsoYawDegrees = math.deg(select(2, self.rootJoint.C0:ToOrientation()))
		local torsoYawOffset = torsoYawDegrees - defaultValues.defaultTorsoY

		local cancelBodyTilt = CFrame.Angles(0, math.rad(-torsoYawOffset), 0)

		local targetNeckC0 = CFrame.new(0, self.yOffset, 0)
			* cancelBodyTilt
			* CFrame.Angles(3 * math.pi / 2, 0, math.pi)
			* CFrame.Angles(0, 0, -math.asin(cameraDirection.X))
			* CFrame.Angles(-math.asin(cameraDirection.Y), 0, 0)

		if self.character:GetAttribute("FirstPerson") then
			self.neck.C0 = self.defaultNeckC0
		else
			self.neck.C0 = self.neck.C0:Lerp(targetNeckC0, defaultValues.lerpSpeed * deltaTime)
		end

		self.replication:step(characterReplication.packetKinds.body, deltaTime, {
			neckC0 = targetNeckC0,
			rootC0 = self.rootJoint.C0,
			leftHipC0 = self.leftHip.C0,
			rightHipC0 = self.rightHip.C0,
		})
	end)
end

function headController.new()
	local self = setmetatable({}, headController)
	self.connections = {}

	self.player = players.LocalPlayer
	self.character = self.player.Character or self.player.CharacterAdded:Wait()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid")
	self.rootPart = self.humanoid.RootPart
	self.torso = self.character:WaitForChild("Torso")

	self.neck = self.torso:WaitForChild("Neck")

	self.defaultNeckC0 = self.neck.C0

	self.leftHip = self.torso:WaitForChild("Left Hip")
	self.rightHip = self.torso:WaitForChild("Right Hip")
	self.rootJoint = self.rootPart:WaitForChild("RootJoint")

	self.camera = workspace.CurrentCamera
	self.replication = characterReplicationController.getShared()

	task.defer(self.init, self)

	return self
end

function headController:destroy()
	runService:UnbindFromRenderStep("HeadController")

	for connectionName, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	setmetatable(self, nil)
end

return headController
