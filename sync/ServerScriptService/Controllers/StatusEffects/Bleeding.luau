local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

return {
	id = "Bleeding",
	defaultDuration = 5,
	stackMode = "stack",
	maxStacks = 3,
	tickInterval = 0.7,

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

		if effect.data.player then
			networking.events.generic:FireClient(effect.data.player, "damage")
		end
	end,
}
