--[[
Author     Ziffixture (74087102)
Date       11/07/2026 (MM/DD/YYYY)
Version    1.0.2
]]



--!strict
local Clock = {}



local function upAsync(callback: (number) -> (), rate: number, imprecise: boolean)
	local elapsed = 0

	while true do
		callback(if imprecise then elapsed - elapsed % rate else elapsed)

		elapsed += task.wait(if imprecise then rate - elapsed % rate else rate)
	end
end

local function downAsync(seconds: number, callback: (number) -> (), rate: number, imprecise: boolean)
	while true do
		local ticked    = if imprecise then elapsed - elapsed % rate else elapsed
		local remaining = math.max(seconds - ticked, 0)

		callback(remaining)

		if remaining <= 0 then
			break
		end

		elapsed += task.wait(if imprecise then rate - elapsed % rate else rate)
	end
end


function Clock.upAsync(callback: (number) -> (), rate: number?)
	local imprecise = rate == nil

	upAsync(callback, rate or 1, imprecise)
end

function Clock.preciseUpAsync(callback: (number) -> ())
	upAsync(callback, 0, false)
end

function Clock.downAsync(seconds: number, callback: (number) -> (), rate: number?)
	local imprecise = rate == nil

	downAsync(seconds, callback, rate or 1, imprecise)
end

function Clock.preciseDownAsync(seconds: number, callback: (number) -> ())
	downAsync(seconds, callback, 0, false)
end



return Clock
