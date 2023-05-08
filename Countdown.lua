--[[
Authors:    Ziffix
Version:    1.3.0 (Stable)
Date:       23/05/07
]]



local HttpService = game:GetService("HttpService")


local Countdown = {}

local countdownPrototype = {}
local countdownPrivate = {}



--[[
@param     condition   any       | The result of the condition
@param     message     string    | The error message to be raised
@param     level = 2   number?   | The level at which to raise the error
@return    N/A         void      | N/A

Implements assert with error's level argument.
]]
local function _assertLevel(condition: any, message: string, level: number?)
    assert(condition ~= nil, "Argument #1 missing or nil.")
    assert(message ~= nil, "Argument #2 missing or nil.")

    -- Lifts the error out of this function.
    level = (level or 1) + 1

    if condition then
        return condition
    end

    error(message, level)
end


--[[
@param     countdownObject   Countdown           | The countdown object
@return    N/A               Dict<String, Any>   | N/A

Returns the private data associated with the given countdown object.
]]
local function _getPrivate(countdown: Countdown): {[string]: any}
    _assertLevel(countdown == nil, "Argument #1 missing or nil.", 1)

    local private = _assertLevel(countdownPrivate[countdown], "Countdown object is destroyed", 2)
    
    return private
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
@return    N/A    void   | N/A

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
@param     interval    number      | The interval at which the callback executes
@param     callback    function    | The function to be ran at the given interval
@return    N/A         string      | The GUID representing the task

Compiles task data into private.Tasks.
]]
function countdownPrototype:AddTask(interval: number, task: (number?, ...any) -> (), ...): string
    _assertLevel(interval == nil, "Argument #1 missing or nil.", 1)
    _assertLevel(task == nil, "Argument #2 missing or nil.", 1)
    _assertLevel(interval % 1 == 0, "Expected integer, got decimal.", 1)

    local private = _getPrivate(self)

    local taskInfo = {
        Interval = interval,
        Task = task,
        Id = HttpService:GenerateGUID(),
        Arguments = {...},
    }

    table.insert(private.Tasks, taskInfo)

    return taskInfo.Id
end


--[[
@param     taskId    string    | The ID generated by countdown:AddTask()
@return    N/A       void      | N/A

Queues the associated task to be removed from private.Tasks.
]]
function countdownPrototype:RemoveTask(taskId: string)
    _assertLevel(taskId == nil, "Argument #1 missing or nil.", 1)

    local private = _getPrivate(self)

    for taskIndex, taskInfo in private.Tasks do
        if taskInfo.Id ~= taskId then
            continue
        end

        --[[
        With private.TaskRemovalQueue being read from left -> right, private.TaskRemovalQueue
        is set to maintain a descending order of values to avoid index discoordination when 
        removing the targeted tasks.
        ]]
        local insertionIndex = 1
        
        for _, queuedIndex in private.TaskRemovalQueue do
            if queuedIndex > index then
                insertionIndex += 1
            end
        end
        
        table.insert(private.TaskRemovalQueue, insertionIndex, taskIndex)

        return
    end

    error("Could not find a task by the given ID.", 2)
end


--[[
@return    N/A    number     | The duration of the countdown

Retrieves the duration of the countdown.
]]
function countdownPrototype:GetDuration(): number
    local private = _getPrivate(self)

    return private.Duration
end


--[[
@return    N/A    number     | The seconds remaining in the countdown

Retrieves the seconds remaining in the countdown.
]]
function countdownPrototype:GetSecondsLeft(): number
    local private = _getPrivate(self)

    return private.SecondsLeft
end


--[[
@return    N/A    boolean    | The active state of the countdown process

Retrieves a boolean detailing whether or not the countdown process is active.
]]
function countdownPrototype:IsPaused(): boolean
    local private = _getPrivate(self)
    
    return private.Active
end


--[[
@return    N/A    void    | N/A

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

export type Countdown = {
    
    Start: (self) -> (),
    Pause: (self) -> (),
    Resume: (self) -> ()
    
    AddTask: (self, number, (number?, ...any) -> (), ...) -> string,
    RemoveTask: (self, string) -> (),
    
    GetDuration: (self) -> number,
    GetSecondsLeft: (self) -> number,
    
    IsPaused: (self) -> boolean,
    
    Destroy: (self) -> ()
    
}

return countdown
