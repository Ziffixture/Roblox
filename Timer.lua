--[[
Author     Ziffixture (74087102)
Date       04/15/2026 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
local timer = {}



local function wait_async(seconds: number, imprecise: boolean): number
    local deltaTime = task.wait(seconds)

    if imprecise then
        deltaTime = math.floor(deltaTime)
    end

    return deltaTime
end

local function up_async(callback: (number) -> (), rate: number, imprecise: boolean)
    local seconds = 0

    while true do
        callback(seconds)

        seconds += wait_async(rate, imprecise)
    end
end

local function down_async(seconds: number, callback: (number) -> (), rate: number, imprecise: boolean)
    repeat
        callback(seconds)
            
        seconds -= wait_async(rate, imprecise)
    until seconds <= 0
end


function timer.up_async(callback: (number) -> ())
    up_async(callback, 1, true)
end

function timer.precise_up_async(callback: (number) -> ())
    up_async(callback, 0, false)
end

function timer.down_async(seconds: number, callback: (number) -> ())
    down_async(seconds, callback, 1, true)
end

function timer.precise_down_async(seconds: number, callback: (number) -> ())
    down_async(seconds, callback, 0, false)
end



return timer