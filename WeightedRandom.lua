--[[
Author     Ziffix
Date       08/10/2026 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
local WeightedRandom = {}



local function sumWeights<T>(weightMap: WeightMap<T>): number 
	local sum = 0

	for _, weight in weightMap do
		sum += weight
	end

	return sum
end

function WeightedRandom.random<T>(weightMap: WeightMap<T>): T
	local weightSum   = sumWeights(weightMap)
	local randomValue = math.random() * weightSum

	for value, weight in weightMap do
		weightSum -= weight

		if weightSum < randomValue then
			return value
		end
	end

	-- Silence NACP error.
	return nil :: any
end

function WeightedRandom.percentage<T>(weightMap: WeightMap<T>, key: T): number
	local sum = sumWeights(weightMap)
	
	return weightMap[key] / sum * 100
end

function WeightedRandom.percentages<T>(weightMap: WeightMap<T>): PercentageMap<T>
	local sum         = sumWeights(weightMap)
	local percentages = {}
	
	for key, weight in weightMap do
		percentages[key] = weight / sum * 100
	end
	
	return percentages
end



export type WeightMap<T> = {
	[T]: number,
}

export type PercentageMap<T> = WeightMap<T>



return WeightedRandom
