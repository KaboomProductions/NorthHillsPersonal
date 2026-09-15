local lineResolver = {}

export type playerStats = {
	trust: number,
	respect: number,
	patience: number,
	familiarity: number,
}

export type thresholds = {
	firstTimeFamiliarity: number?,
	veryLow: number?,
	low: number?,
	mid: number?,
	high: number?,
}

type linePool = { [string]: { string } }

local resolutionOrder = {
	"firstTime",
	"highTrustHighRespect",
	"highTrustHighFamiliarity",
	"highTrust",
	"highRespect",
	"highFamiliarity",
	"midTrust",
	"veryLowPatience",
	"veryLowRespect",
	"lowTrust",
	"lowRespect",
	"lowPatience",
	"lowFamiliarity",
	"neutral",
	"default",
}

--// TODO: Replace with real player stats once persistence is implemented.
function lineResolver.getPlayerStats(_player: Player, _npcId: string): playerStats
	return {
		trust = 0,
		respect = 0,
		patience = 100,
		familiarity = 0,
	}
end

function lineResolver.evaluateCondition(
	conditionKey: string,
	stats: playerStats,
	currentThresholds: thresholds
): boolean
	local veryLow = currentThresholds.veryLow or 15
	local low = currentThresholds.low or 30
	local mid = currentThresholds.mid or 50
	local high = currentThresholds.high or 70

	if conditionKey == "firstTime" then
		return stats.familiarity <= (currentThresholds.firstTimeFamiliarity or 0)
	elseif conditionKey == "veryLowPatience" then
		return stats.patience <= veryLow
	elseif conditionKey == "veryLowRespect" then
		return stats.respect <= veryLow
	elseif conditionKey == "lowTrust" then
		return stats.trust < low
	elseif conditionKey == "lowRespect" then
		return stats.respect < low
	elseif conditionKey == "lowPatience" then
		return stats.patience < low
	elseif conditionKey == "lowFamiliarity" then
		return stats.familiarity < low
	elseif conditionKey == "midTrust" then
		return stats.trust >= mid
	elseif conditionKey == "highTrust" then
		return stats.trust >= high
	elseif conditionKey == "highRespect" then
		return stats.respect >= high
	elseif conditionKey == "highFamiliarity" then
		return stats.familiarity >= high
	elseif conditionKey == "highTrustHighRespect" then
		return stats.trust >= high and stats.respect >= high
	elseif conditionKey == "highTrustHighFamiliarity" then
		return stats.trust >= high and stats.familiarity >= high
	elseif conditionKey == "neutral" or conditionKey == "default" then
		return true
	end

	return false
end

function lineResolver.pickRandomLine(lineTable: linePool?, stats: playerStats, currentThresholds: thresholds): string?
	if lineTable == nil then
		return nil
	end

	for _, conditionKey in ipairs(resolutionOrder) do
		local pool = lineTable[conditionKey]
		if pool and lineResolver.evaluateCondition(conditionKey, stats, currentThresholds) then
			return pool[math.random(1, #pool)]
		end
	end

	return nil
end

return lineResolver
