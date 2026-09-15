local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local sharedAssets = replicatedStorage.SharedAssets
local sharedUtilities = replicatedStorage.SharedUtilities

local audioUtilities = require(sharedUtilities.AudioUtils)

local effects = sharedAssets.Effects
local sounds = effects.Sounds

local projectileSounds = sounds.Projectiles
local spitSounds = projectileSounds.Spit
local fireDamageSound = spitSounds["Fire Damage"]

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

return {
	id = "Burning",
	defaultDuration = 6,
	stackMode = "refresh",
	tickInterval = 0.5,

	onApply = function(effect)
		effect.data.player = players:GetPlayerFromCharacter(effect.entity)
		effect.data.humanoid = effect.entity:FindFirstChildOfClass("Humanoid")
	end,

	onTick = function(effect, _deltaTime)
		local humanoid = effect.data.humanoid :: Humanoid?
		local damage = effect.config.damage or 2

		if not humanoid then
			return
		end

		if humanoid.Health <= damage or humanoid:GetState() == Enum.HumanoidStateType.Dead then
			return
		end

		humanoid.Health = math.clamp(humanoid.Health - damage, damage, humanoid.MaxHealth)

		audioUtilities.playSound({
			sound = fireDamageSound,
			parent = humanoid.RootPart,
			playbackSpeed = math.random(900, 1100) / 1000,
		})

		if effect.data.player then
			networking.events.generic:FireClient(effect.data.player, "damage")
		end
	end,
}
