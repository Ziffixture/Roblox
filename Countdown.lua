--[[
Authors:    Ziffix
Version:    1.3.0 (Untested)
Date:       23/05/07
]]



local Countdown = {}

local countdownPrototype = {}
local countdownPrivate = {}



--[[
@param     any        condition    | The result of the condition
@param     string     message      | The error message to be raised
@param     number?    level = 2    | The level at which to raise the error
@return    void

Implements assert with error's level argument.
]]
local function _assertLevel(condition: any, message: string, level: number?)
    if condition == nil then 
        error("Argument #1 missing or nil.", 2) 
    end

    if message == nil then 
        error("Argument #2 missing or nil.", 2) 
    end

    -- Lifts the error out of this function.
    level = (level or 1) + 1

    if condition then
        return condition
    end

    error(message, level)
end


--[[
@param     Countdown    countdown    | The countdown object
@return    

Returns the private data associated with the given countdown object.
]]
local function _getPrivate(countdown: Countdown): {[string]: any}
    _assertLevel(countdown == nil, "Argument #1 missing or nil.", 1)

    local private = _assertLevel(countdownPrivate[countdown], "Countdown object is destroyed", 2)
    
    return private
end


--[[
@param     callback    function<any, any>    | The function to be threaded
@return    N/A         thread                | N/A

Threads a function that wraps around the given callback in such a
way that the thread cannot die.
]]
local function _immortalThread(callback: (...any) -> any): thread
    local thread = coroutine.create(function(...)
        local arguments = {...}
            
        while true do
            callback(table.unpack(arguments))
                
            arguments = {coroutine.yield()}
        end
    end)
    
    return thread
end


--[[
@param     countdown    Countdown    | The countdown object
@return    N/A          void         | N/A

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

            coroutine.resume(taskInfo.Task, secondsLeft, table.unpack(taskInfo.Arguments))
        end
    end

    -- Countdown object was destroyed
    if private.Finished == nil then
        return
    end

    private.Finished:Fire()
end


--[[
@param     duration    number        | The duration of the countdown
@return    N/A         countdown     | The generated Countdown object

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
@return    N/A    void   | N/A

Begins asynchronous countdown process.
]]
function countdownPrototype:Start()
    local private = _getPrivate(self)
    
    private.Active = true
    private.Thread = task.spawn(_countdownMain, private)
end


--[[
@return    N/A    void   | N/A

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
@return    void

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
@param     number           interval    | The interval at which the callback executes.
@param     CountdownTask    task        | The function to be run at the given interval.
@return    void

Adds the given task to the countdown process.
]]
function countdownPrototype:AddTask(interval: number, task: CountdownTask, ...)
    _assertLevel(interval == nil, "Argument #1 missing or nil.", 1)
    _assertLevel(task == nil, "Argument #2 missing or nil.", 1)
    _assertLevel(interval % 1 == 0, "Expected integer, got decimal.", 1)

    local private = _getPrivate(self)

    local taskInfo = {
        Interval = interval,
        Task = _immortalThread(task),
        Arguments = {...},
    }

    table.insert(private.Tasks, taskInfo)
end


--[[
@param     number    taskId    | The ID generated by Countdown:AddTask().
@return    void

Queues the associated task to be removed from the countdown process.
]]
function countdownPrototype:RemoveTask(taskId: number)
    _assertLevel(taskId == nil, "Argument #1 missing or nil.", 1)

    local private = _getPrivate(self)

    --[[
    With private.TaskRemovalQueue being read from left -> right, private.TaskRemovalQueue
    is set to maintain a descending order of values to avoid index discoordination when 
    removing the targeted tasks.
    ]]
    local insertionIndex = 1
        
    for _, queuedIndex in private.TaskRemovalQueue do
        if queuedIndex > taskId then
            insertionIndex += 1
        end
    end

    table.insert(private.TaskRemovalQueue, insertionIndex, taskId)

    error("Could not find task with the given id " .. taskId)
end


--[[
@return    number    | The duration of the countdown.

Retrieves the duration of the countdown.
]]
function countdownPrototype:GetDuration(): number
    local private = _getPrivate(self)

    return private.Duration
end


--[[
@return    number    | The seconds remaining in the countdown.

Retrieves the seconds remaining in the countdown.
]]
function countdownPrototype:GetSecondsLeft(): number
    local private = _getPrivate(self)

    return private.SecondsLeft
end


--[[
@return    boolean    | The active state of the countdown process.

Retrieves a boolean detailing whether or not the countdown process is active.
]]
function countdownPrototype:IsPaused(): boolean
    local private = _getPrivate(self)
    
    return private.Active
end


--[[
@return    void

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


export type CountdownTask = (number?, ...any) -> ()

type CountdownPrivate = {
    Duration         : number,
    SecondsLeft      : number,
    
    Active           : boolean,
    Thread           : thread,

    Tasks            : {CountdownTask},
    TaskRemovalQueue : {number},

    Tick             : BindableEvent,
    Finished         : BindableEvent,
}

export type Countdown = {
    Start          : (Countdown) -> (),
    Pause          : (Countdown) -> (),
    Resume         : (Countdown) -> ()
    
    AddTask        : (Countdown, number, CountdownTask, ...) -> string,
    RemoveTask     : (Countdown, string) -> (),
    
    GetDuration    : (Countdown) -> number,
    GetSecondsLeft : (Countdown) -> number,
    
    IsPaused       : (Countdown) -> boolean,
     
    Destroy        : (Countdown) -> (),
}


return countdown
