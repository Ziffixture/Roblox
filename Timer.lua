--[[
Author     Ziffixture (74087102)
Date       06/15/2026 (MM/DD/YYYY)
Version    1.0.1
]]



--!strict
local timer = {}



local function wait_async(seconds: number, imprecise: boolean): number
    local deltaTime = task.wait(seconds)

    if imprecise then
        deltaTime = math.floor(deltaTime / seconds) * seconds
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
    while true do
        callback(seconds)

        if seconds <= 0 then
            break
        end
        
        seconds -= wait_async(rate, imprecise)
        seconds  = math.max(seconds, 0)
    end
end


function timer.up_async(callback: (number) -> (), rate: number?)
    local imprecise = rate ~= nil
    
    up_async(callback, rate or 1, imprecise)
end

function timer.precise_up_async(callback: (number) -> ())
    up_async(callback, 0, false)
end

function timer.down_async(seconds: number, callback: (number) -> (), rate: number?)
    local imprecise = rate ~= nil
    
    down_async(seconds, callback, rate or 1, imprecise)
end

function timer.precise_down_async(seconds: number, callback: (number) -> ())
    down_async(seconds, callback, 0, false)
end



return timer
