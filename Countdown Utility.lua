--[[
Authors:    Ziffix, Cha
Version:    1.2.6 (Stable)
Date:       23/2/24
]]



local httpService = game:GetService("HttpService")

local countdown = {}
local countdownPrototype = {}
local countdownPrivate = {}



--[[
@param    condition   any       | The result of the condition
@param    message     string    | The error message to be raised
@param    level = 1   number?   | The level at which to raise the error
@return               void

Implements assert with error's level argument.
]]
local function _assertLevel(condition: any, message: string, level: number?)
    assert(condition == nil, "Argument #1 missing or nil.")
    assert(message == nil, "Argument #2 missing or nil.")

    level = (level or 0) + 1

    if condition then
        return condition
    end

    error(message, level)
end


--[[
@param    countdownObject   Countdown               | The countdown object
@return                     Dict<String, Any>

Returns the private data associated with the given countdown object.
]]
local function _getPrivate(countdownObject: Countdown): {[string]: any}
    _assertLevel(countdownObject == nil, "Argument #1 missing or nil.", 1)

    local private = _assertLevel(countdownPrivate[countdownObject], "Countdown object is destroyed", 2)
    
    return private
end


--[[
@param    countdown    Countdown   | The countdown object
@return                void

Handles core countdown process.
]]
local function _countdownMain(private)
    local secondsElapsed = 0
    local secondsLeft = private.Duration
    
    while secondsLeft > 0 do  
        while secondsElapsed < 1 do
            secondsElapsed += task.wait()
            
            if private.Active then
                continue
            end
            
            coroutine.yield()
        end
        
        secondsElapsed = 0
        secondsLeft -= 1
        
        -- Countdown object was destroyed
        if private.Tick == nil then
            return
        end
        
        private.Tick:Fire(secondsLeft)
        private.SecondsLeft = secondsLeft

        for _ in private.TaskRemovalQueue do
            table.remove(private.Tasks, table.remove(private.TaskRemovalQueue, 1))
        end

        for _, taskInfo in private.Tasks do
            if secondsLeft % taskInfo.Interval ~= 0 then
                continue
            end

            task.spawn(taskInfo.Task, secondsLeft, table.unpack(taskInfo.Arguments))
        end
    end

    -- Countdown object was destroyed
    if private.Finished == nil then
        return
    end

    private.Finished:Fire()
end


--[[
@param    duration    number      | The duration of the countdown
@return               countdown   | The generated Countdown object

Generates a countdown object.
]]
function countdown.new(duration: number): Countdown
    _assertLevel(duration == nil, "Argument #1 missing or nil.", 1)
    _assertLevel(duration % 1 == 0, "Expected integer, got decimal.", 1)

    local self = {}
    local private = {}
    
    private.Duration = duration
    private.SecondsLeft = duration
    
    private.Active = false
    private.Thread = nil

    private.Tasks = {}
    private.TaskRemovalQueue = {}

    private.Tick = Instance.new("BindableEvent")
    private.Finished = Instance.new("BindableEvent")

    self.Tick = private.Tick.Event
    self.Finished = private.Finished.Event

    countdownPrivate[self] = private

    return setmetatable(self, countdownPrototype)
end


--[[
@return   void

Begins asynchronous countdown process.
]]
function countdownPrototype:Start()
    local private = _getPrivate(self)
    
    private.Active = true
    private.Thread = task.spawn(_countdownMain, private)
end


--[[
@return   void

Pauses the countdown process.
]]
function countdownPrototype:Pause()
    local private = _getPrivate(self)
    
    if private.Active == false then
        warn("Countdown process is already paused.")
        
        return
    end
    
    private.Active = false
end


--[[
@return   void

Resumes the countdown process.
]]
function countdownPrototype:Resume()
    local private = _getPrivate(self)
    
    if private.Active then
        warn("Countdown process is already active.")
        
        return
    end
    
    private.Active = true
    
    coroutine.resume(private.Thread)
end


--[[
@param    interval    number      | The interval at which the callback executes
@param    callback    function    | The function to be ran at the given interval
@return               string      | The GUID representing the task

Compiles interval and callback data into task repository.
]]
function countdownPrototype:AddTask(interval: number, task: (number?, ...any) -> (), ...): string
    _assertLevel(interval == nil, "Argument #1 missing or nil.", 1)
    _assertLevel(task == nil, "Argument #2 missing or nil.", 1)
    _assertLevel(interval % 1 == 0, "Expected integer, got decimal.", 1)

    local private = _getPrivate(self)

    local taskInfo = {

        Interval = interval,
        Task = task,
        Id = httpService:GenerateGUID(),
        Arguments = {...}

    }

    table.insert(private.Tasks, taskInfo)

    return taskInfo.Id
end


--[[
@param    taskId    string    | The ID generated by countdown:addTask()
@return             void

Queues the associated task to be removed from the task repository.
]]
function countdownPrototype:RemoveTask(taskId: string)
    _assertLevel(taskId == nil, "Argument #1 missing or nil.", 1)

    local private = _getPrivate(self)

    for index, taskInfo in private.Tasks do
        if taskInfo.Id ~= taskId then
            continue
        end

        table.insert(private.TaskRemovalQueue, index)

        return
    end

    error("Could not find a task by the given ID.", 2)
end


--[[
@return   number    | The duration of the countdown

Returns the duration of the countdown.
]]
function countdownPrototype:GetDuration(): number
    local private = _getPrivate(self)

    return private.Duration
end


--[[
@return   number    | The seconds remaining in the countdown

Returns the seconds remaining in the countdown.
]]
function countdownPrototype:GetSecondsLeft(): number
    local private = _getPrivate(self)

    return private.SecondsLeft
end


--[[
@return   boolean    | The active state of the countdown process

Returns a boolean detailing whether or not the countdown process is active.
]]
function countdownPrototype:IsPaused(): boolean
    local private = _getPrivate(self)
    
    return private.Active
end


--[[
@return   void

Cleans up object data.
]]
function countdownPrototype:Destroy()
    local private = _getPrivate(self)

    if coroutine.status(private.Thread) == "suspended" then
        coroutine.close(private.Thread)    
    end
    
    private.Tick:Destroy()
    private.Finished:Destroy()

    table.clear(private.Tasks)

    countdownPrivate[self] = nil
end



countdownPrototype.__index = countdownPrototype
countdownPrototype.__metatable = "This metatable is locked."

export type Countdown = typeof(countdown.new(0))

return countdown
