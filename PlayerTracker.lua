--[[
Authors    Ziffixture (74087102)
Date       24/08/21 (YY/MM/DD)
Version    1.3.9b
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")


local Vendor  = -- Path.to.Vendor
local Signal  = require(Vendor:WaitForChild("Signal"))
local Connect = require(Vendor:WaitForChild("Connect")


local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker



--[[
@param     {BasePart}    parts    | The array of BaseParts to analyze.
@return    PlayerMap

Processes array of BaseParts for affiliated Player instances. Filters out dead players.
]]
local function _analyzePartsForPlayers(parts: {BasePart}): PlayerMap
	local playersFound: PlayerMap = {}

	for _, part in parts do
		local character = part.Parent
		if not character then
			continue
		end

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
@param     PlayerTracker     playerTracker    | The PlayerTracker instance to update.
@param     {BasePart}        parts            | The parts within the PlayerTracker's tracking space.
@return    void

Updates the PlayerTracker's internal map of players and population.
]]
local function _updatePlayerTracker(playerTracker: PlayerTrackerLocal, parts: {BasePart})
	local currentPlayers = playerTracker._PlayerMap
	local capacity       = playerTracker._Capacity

	local newPlayers = _analyzePartsForPlayers(parts)

	for player in newPlayers do
		if capacity and playerTracker._Population >= capacity then
			break
		end

		if currentPlayers[player] then
			continue
		end
		
		currentPlayers[player] = true

		playerTracker._Population += 1

		playerTracker.PopulationChanged:Fire(playerTracker._Population)
		playerTracker.PlayerEntered:Fire(player)
	end

	for player in currentPlayers do
		if newPlayers[player] then
			continue
		end

		currentPlayers[player] = nil

		playerTracker._Population -= 1

		playerTracker.PopulationChanged:Fire(playerTracker._Population)
		playerTracker.PlayerLeft:Fire(player)
	end
end


--[[
@param     BasePart         trackingSpace         | The BasePart that will be scanned for players.
@param     number?          capacity              | The maximum number of players the tracker will process.
@param     OverlapParams    trackingParameters    | The OverlapParams for the tracking query.
@return    PlayerTracker

Constructs a PlayerTracker object.
]]
function PlayerTracker.new(trackingSpace: BasePart, capacity: number?, trackingParameters: OverlapParams?): PlayerTracker
	local self: PlayerTrackerLocal = {} :: PlayerTrackerLocal

	self._TrackingSpace      = trackingSpace
	self._IsTracking         = false
	self._TrackingParameters = trackingParameters
    
	self._ScanInterval = nil

	self._PlayerMap  = {}
	self._Population = 0
	self._Capacity   = capacity

	self.PlayerLeft        = Signal.new()
	self.PlayerEntered     = Signal.new()
	self.PopulationChanged = Signal.new()

    self._Tray = {}
    self._Tray.TrackingSpaceConnection = nil,
    self._Tray.TrackingConnection      = nil,
	self._Tray.TrackingSpaceConnection = trackingSpace.Destroying:Connect(function()
		self:Destroy()
	end)

	return setmetatable(self, PlayerTracker) :: any
end


--[[
@return    void

Begins updating the PlayerTracker every RunService.PostSimulation.
]]
function PlayerTracker:StartTracking()
	if self._IsTracking then
		return
	end

	self._IsTracking = true

	local trackingSpace      = self._TrackingSpace
	local trackingParameters = self._TrackingParameters

	local secondsElapsed = 0
	
	self._Tray.TrackingConnection = RunService.PostSimulation:Connect(function(deltaTime: number)
        if self.ScanInterval then
            secondsElapsed += deltaTime

            if secondsElapsed >= self._ScanInterval then
                secondsElapsed = 0        
            else
                return
            end
        end
			
		_updatePlayerTracker(
			self :: any,
			workspace:GetPartBoundsInBox(trackingSpace.CFrame, trackingSpace.Size, trackingParameters)
		)
	end)
end


--[[
@return    void

Ceases updating the PlayerTracker.
]]
function PlayerTracker:StopTracking()
	self._IsTracking = false
	self._Tray.TrackingConnection:Disconnect()
end


--[[
@return    {Player}

Returns an array of the players currently in the tracking space.
]]
function PlayerTracker:GetPlayers(): {Player}
	local players = {}

	for player in self._PlayerMap do
		table.insert(players, player)
	end

	return players
end


--[[
@return    number

Returns the current population of the tracking space.
]]
function PlayerTracker:GetPopulation(): number
	return self._Population
end


--[[
@return    number

Returns the capacity of the tracking space.
]]
function PlayerTracker:GetCapacity(): number
	return self._Capacity
end


--[[
@param     number?    capacity    | The new capacity of the tracking space.
@return    void

Updates the capacity of the tracking space.
]]
function PlayerTracker:SetCapacity(capacity: number?)
	self._Capacity = capacity
end


--[[
@param     number?    interval    | The new scan internal of the tracking space.
@return    void

Updates the scan interval of the tracking space.
]]
function PlayerTracker:SetScanInterval(interval: number?)
	self._ScanInterval = interval
end


--[[
@return    boolean

Returns a boolean detailing whether or not the tracking process is active.
]]
function PlayerTracker:IsTracking(): boolean
	return self._IsTracking
end


--[[
@return   void

Cleans up object data.
]]
function PlayerTracker:Destroy()
	self:StopTracking()

	Connect.clearKeys(self._Tray)
end



export type PlayerTracker = {
	StartTracking : (self: PlayerTracker) -> (),
	StopTracking  : (self: layerTracker) -> (),

	GetPlayers    : (self: PlayerTracker) -> {Player},
	GetPopulation : (self: PlayerTracker) -> number,
	GetCapacity   : (self: PlayerTracker) -> number,

	SetCapacity     : (self: PlayerTracker, capacity: number?) -> (),
    SetScanInterval : (self: PlayerTracker, scanInterval: number?) -> (), 

	IsTracking : (self: PlayerTracker) -> boolean,

    Destroy : (self: PlayerTracker) -> (),

	PlayerLeft        : Signal.Signal<Player>,
	PlayerEntered     : Signal.Signal<Player>,
	PopulationChanged : Signal.Singal<number>,
}

type PlayerMap = {[Player]: true}

type PlayerTrackerLocal = PlayerTracker & {	
	_TrackingSpace : BasePart,
	
	_IsTracking         : boolean,
	_TrackingParameters : OverlapParams?,

	_ScanInterval : number?
	
    _PlayerMap  : PlayerMap,
	_Population : number,
	_Capacity   : number?,

    _Tray = {
        TrackingSpaceConnection : RBXScriptSignal?,
        TrackingConnection      : RBXScriptSignal?,
    }
}



return PlayerTracker
