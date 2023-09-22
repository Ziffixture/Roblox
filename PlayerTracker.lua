--[[
Authors:    Ziffix
Version:    1.3.1 (Untested)
Date:       23/4/29
]]



local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
 
local PlayerTracker = {}

local playerTrackerPrototype = {}
local playerTrackerPrivate = {}
 
 

--[[
@param    condition   any       | The result of the condition
@param    message     string    | The error message to be raised
@param    level = 2   number?   | The level at which to raise the error
@return               void

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
@param    playerTracker     PlayerTracker        | The PlayerTracker object
@return                     Dict<String, Any>

Returns the private data associated with the given PlayerTracker object.
]]
local function _getPrivate(playerTracker: PlayerTracker): {[string]: any}
    _assertLevel(countdownObject == nil, "Argument #1 missing or nil.", 1)

    local private = _assertLevel(playerTrackerPrivate[playerTracker], "PlayerTracker object was destroyed", 2)
    
    return private
end


--[[
@param    parts   Array<BasePart>               | The array of BaseParts to scan
@return           Dictionary<Player, boolean>   | A dictionary of the players found

Processes array of BaseParts for affiliated Player instances. Filters out dead players.
]]
local function _analyzePartsForPlayers(parts: {BasePart}): {[Player]: boolean}
    _assertLevel(parts == nil, "Argument #1 missing or nil.", 1)
 
    local playersFound = {}
 
    for _, part in parts do
        local character = part.Parent
  
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid == nil or humanoid:GetState() == Enum.HumanoidStateType.Dead then
            continue
        end
    
        local player = Players:GetPlayerFromCharacter(character)
        if player == nil then
            continue
        end
    
        playersFound[player] = true
    end
 
    return playersFound
end


--[[
@param    playerTracker   PlayerTracker   | The array of BaseParts to scan
@return                   void

Updates the PlayerTracker's internal map of Players, and population.
]]
local function _updatePlayerTracker(playerTracker: PlayerTracker, parts: {BasePart})
    _assertLevel(playerTracker == nil, "Argument #1 missing or nil.", 1)
    _assertLevel(parts == nil, "Argument #2 missing or nil.", 1)
 
    local private = _getPrivate(playerTracker)
 
    local currentPlayers = private.PlayerMap
    local currentPopulation = private.Population
    local capacity = private.Capacity
 
    local newPlayers = _analyzePartsForPlayers(parts)
 
    for player in newPlayers do
        if capacity and private.Population >= capacity then
            break
        end
 
        if currentPlayers[player] then
            continue
        end
 
        private.Population += 1
        private.PopulationChanged:Fire(private.Population)
        private.PlayerEntered:Fire(player)
    end
 
    for player in currentPlayers do
        if newPlayers[player] then
            continue
        end
    
        currentPlayers[player] = nil
 
        private.Population -= 1
        private.PopulationChanged:Fire(private.Population)
        private.PlayerLeft:Fire(player)
    end
end
 
 
--[[
@param    trackingSpace         BasePart          | The BasePart that will be scanned for players
@param    capacity              number?           | The maximum number of players the tracker will process
@param    trackingParameters    OverlapParams?    | The OverlapParams for the tracking query
@return                         PlayerTracker     | The generated PlayerTracker object

Generates a PlayerTracker object.
]]
function PlayerTracker.new(trackingSpace: BasePart, capacity: number?, trackingParameters: OverlapParams?): PlayerTracker
    _assertLevel(trackingSpace == nil, "Argument #1 missing or nil.", 1)
 
    local self = {}
    local private = {}
        
    private.IsTracking = false
    private.TrackingSpace = TrackingSpace
    private.TrackingParameters = TrackingParameters
    private.TrackingConnection = nil
 
    private.PlayerMap = {}
    private.Population = 0
    private.Capacity = capacity
  
    private.PlayerLeft = Instance.new("BindableEvent")
    private.PlayerEntered = Instance.new("BindableEvent")
    private.PopulationChanged = Instance.new("BindableEvent")
 
    self.PlayerLeft = private.PlayerLeft.Event
    self.PlayerEntered = private.PlayerEntered.Event
    self.PopulationChanged = private.PopulationChanged.Event
  
    playerTrackerPrivate[self] = private
 
    trackingSpace.Destroying:Connect(function()
        self:Destroy()
    end)
 
    return setmetatable(self, playerTrackerPrototype)
end
 


--[[
@return   void

Begins updating the PlayerTracker object every RunService.Heartbeat.
]]
function playerTrackerPrototype:StartTracking()
    local private = _getPrivate(self)
 
    if private.IsTracking then
        warn("PlayerTracker is already tracking.")
    
        return
    end
  
    private.IsTracking = true
        
    local trackingSpace = private.TrackingSpace
    local trackingParameters = private.TrackingParameters
 
    private.TrackingConnection = RunService.Heartbeat:Connect(function()
        _updatePlayerTracker(
            self,
            workspace:GetPartBoundsInBox(trackingSpace.CFrame, trackingSpace.Size, trackingParameters)
        )
    end)
end


--[[
@return   void

Ceases updating the PlayerTracker.
]]
function playerTrackerPrototype:StopTracking()
    local private = _getPrivate(self)
    
    private.TrackingConnection:Disconnect()
    private.IsTracking = false
end

 
--[[
@return   Array<Player>

Returns an array of the players currently in the tracking space.
]]
function playerTrackerPrototype:GetPlayers(): {Player}
    local private = _getPrivate(self)
    local players = {}
 
    for players in private.PlayerMap do
        table.insert(players, player)
    end
 
    return players
end


--[[
@return   number

Returns the current population of the tracking space.
]]
function playerTrackerPrototype:GetPopulation(): number
    local private = _getPrivate(self)
 
    return private.Population
end


--[[
@return   number

Returns the capacity of the tracking space.
]]
function playerTrackerPrototype:GetCapacity(): number
    local private = _getPrivate(self)
 
    return private.Capacity
end


--[[
@param    capacity  number  | The new capacity of the tracking space 
@return             void

Updates the capacity of the tracking space.
]]
function playerTrackerPrototype:SetCapacity(newCapacity: number)
    _assertLevel(newCapacity == nil, "Argument #1 missing or nil.", 1)
 
    local private = _getPrivate(self)
 
    private.Capacity = newCapacity
end


--[[
@return   boolean  | The state of the tracking process

Returns a boolean detailing whether or not the tracking process is active.
]]
function playerTrackerPrototype:IsTracking(): boolean
    local private = _getPrivate(self)
 
    return private.IsTracking
end


--[[
@return   void

Cleans up object data.
]]
function playerTrackerPrototype:Destroy()
    local private = _getPrivate(self)
 
    private.PlayerLeft:Destroy()
    private.PlayerEntered:Destroy()
    private.PopulationChanged:Destroy()
 
    self:StopTracking()
    
    playerTrackerPrivate[self] = nil
end



playerTrackerPrototype.__index = playerTrackerPrototype
playerTrackerPrototype.__metatable = "This metatable is locked."

export type PlayerTracker = {

   StartTracking: (PlayerTracker) -> (),
   StopTracking: (PlayerTracker) -> (),
 
   GetPlayers: (PlayerTracker) -> {Player},
   GetPopulation: (PlayerTracker) -> number,
   GetCapacity: (PlayerTracker) -> number,
 
   SetCapacity: (PlayerTracker, number) -> (),
 
   IsTracking: (PlayerTracker) -> boolean,
 
   Destroy: (PlayerTracker) -> ()

}

return PlayerTracker
