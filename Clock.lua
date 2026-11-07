--!strict
local Clock = {}



-- Calls `step` with the (possibly whole-number-snapped) elapsed time.
-- Returning true from `step` ends the loop.
local function run(rate: number, imprecise: boolean, step: (number) -> boolean)
	local elapsed = 0

	while true do
		local ticked = if imprecise then elapsed - elapsed % rate else elapsed

		if step(ticked) then
			break
		end

		elapsed += task.wait(if imprecise then rate - elapsed % rate else rate)
	end
end

local function countUp(callback: (number) -> ()): (number) -> boolean
	return function(elapsed)
		callback(elapsed)

		return false
	end
end

local function countDown(seconds: number, callback: (number) -> ()): (number) -> boolean
	return function(elapsed)
		local remaining = math.max(seconds - elapsed, 0)

		callback(remaining)

		return remaining <= 0
	end
end



function Clock.upAsync(callback: (number) -> (), rate: number?)
	run(rate or 1, rate == nil, countUp(callback))
end

function Clock.preciseUpAsync(callback: (number) -> ())
	run(0, false, countUp(callback))
end

function Clock.downAsync(seconds: number, callback: (number) -> (), rate: number?)
	run(rate or 1, rate == nil, countDown(seconds, callback))
end

function Clock.preciseDownAsync(seconds: number, callback: (number) -> ())
	run(0, false, countDown(seconds, callback))
end



return Clock
