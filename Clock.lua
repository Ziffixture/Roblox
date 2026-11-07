--[[
Author     Ziffixture (74087102)
Date       06/15/2026 (MM/DD/YYYY)
Version    1.0.1
]]



--!strict
local Clock = {}



local function waitAsync(seconds: number, imprecise: boolean): number
    local deltaTime = task.wait(seconds)

    if imprecise then
        deltaTime = math.floor(deltaTime / seconds) * seconds
    end

    return deltaTime
end

local function upAsync(callback: (number) -> (), rate: number, imprecise: boolean)
    local seconds = 0

    while true do
        callback(seconds)

        seconds += waitAsync(rate, imprecise)
    end
end

local function downAsync(seconds: number, callback: (number) -> (), rate: number, imprecise: boolean)
    while true do
        callback(seconds)

        if seconds <= 0 then
            break
        end
        
        seconds -= waitAsync(rate, imprecise)
        seconds  = math.max(seconds, 0)
    end
end


function Clock.upAsync(callback: (number) -> (), rate: number?)
    local imprecise = rate ~= nil
    
    up_async(callback, rate or 1, imprecise)
end

function Clock.preciseUpAsync(callback: (number) -> ())
    up_async(callback, 0, false)
end

function Clock.downAsync(seconds: number, callback: (number) -> (), rate: number?)
    local imprecise = rate ~= nil
    
    downAsync(seconds, callback, rate or 1, imprecise)
end

function Clock.preciseDownAsync(seconds: number, callback: (number) -> ())
    downAsync(seconds, callback, 0, false)
end



return Clock
