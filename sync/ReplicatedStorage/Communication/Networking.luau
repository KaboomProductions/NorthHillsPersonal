local replicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvents = replicatedStorage.Communication.RemoteEvents
local remoteFunctions = replicatedStorage.Communication.RemoteFunctions

local networking = {
	events = {
		--// Other
		replicateStreaming = remoteEvents.ReplicateStreaming,
		replicateMenu = remoteEvents.ReplicateMenu,

		--// Character
		characterUpdate = remoteEvents.Character:WaitForChild("CharacterUpdate"),
		reportFootstep = remoteEvents.Character:WaitForChild("ReportFootstep"),
		ragdollUpdate = remoteEvents.Character:WaitForChild("RagdollUpdate"),

		--// Visual
		generic = remoteEvents.Visual:WaitForChild("Generic"),

		--// RoundCycle
		sendNotification = remoteEvents.RoundCycle:WaitForChild("SendNotification"),
		sendResults = remoteEvents.RoundCycle:WaitForChild("SendResults"),
		markRoundCycleEventsReady = remoteEvents.RoundCycle:WaitForChild("MarkRoundCycleEventsReady"),
		roundCycleTransition = remoteEvents.RoundCycle:WaitForChild("RoundCycleTransition"),
		cycleStateUpdate = remoteEvents.RoundCycle:WaitForChild("CycleStateUpdate"),
		thunder = remoteEvents.RoundCycle:WaitForChild("Thunder"),

		--// Dialogue
		requestDialogue = remoteEvents.Dialogue:WaitForChild("RequestDialogue"),
		selectChoice = remoteEvents.Dialogue:WaitForChild("SelectChoice"),
		closeDialogue = remoteEvents.Dialogue:WaitForChild("CloseDialogue"),
		showDialogueResponse = remoteEvents.Dialogue:WaitForChild("ShowDialogueResponse"),
		forceCloseDialogue = remoteEvents.Dialogue:WaitForChild("ForceCloseDialogue"),

		--// Projectiles
		replicateProjectile = remoteEvents.Projectiles:WaitForChild("ReplicateProjectile"),

		--// AI
		ai = remoteEvents.AI:WaitForChild("AI"),

		--// Door QTE
		startDoorQte = remoteEvents.DoorQte:WaitForChild("StartDoorQte"),
		doorQteKick = remoteEvents.DoorQte:WaitForChild("DoorQteKick"),
		doorQtePressure = remoteEvents.DoorQte:WaitForChild("DoorQtePressure"),
		endDoorQte = remoteEvents.DoorQte:WaitForChild("EndDoorQte"),
		doorQteFailed = remoteEvents.DoorQte:WaitForChild("DoorQteFailed"),
	},

	requests = {
		shopRequest = remoteFunctions.Shop:WaitForChild("ShopRequest"),
	},
}

return networking
