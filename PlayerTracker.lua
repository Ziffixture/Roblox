--[[
Authors:    Ziffix
Version:    1.3.6b
Date:       24/01/05
]]



--!strict
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")


local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker



--[[
@param     any        condition    | The result of the condition.
@param     string     message      | The error message to be raised.
@param     number?    level = 2    | The level at which to raise the error.
@return    void

Implements assert with error's level argument.
]]
local function assertLevel(condition: any, message: string, level: number?)
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
@param     {BasePart}    parts    | The array of BaseParts to analyze.
@return    PlayerMap

Processes array of BaseParts for affiliated Player instances. Filters out dead players.
]]
local function _analyzePartsForPlayers(parts: {BasePart}): PlayerMap
	assertLevel(parts ~= nil, "Argument #1 missing or nil.", 1)

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
	assertLevel(playerTracker ~= nil, "Argument #1 missing or nil.", 1)
	assertLevel(parts ~= nil, "Argument #2 missing or nil.", 1)

	local currentPlayers    = playerTracker._PlayerMap
	local currentPopulation = playerTracker._Population
	local capacity          = playerTracker._Capacity

	local newPlayers = _analyzePartsForPlayers(parts)

	for player in newPlayers do
		if capacity and currentPopulation >= capacity then
			break
		end

		if currentPlayers[player] then
			continue
		end
		
		currentPlayers[player] = true

		playerTracker._Population += 1
		playerTracker._PopulationChanged:Fire(playerTracker._Population)
		playerTracker._PlayerEntered:Fire(player)
	end

	for player in currentPlayers do
		if newPlayers[player] then
			continue
		end

		currentPlayers[player] = nil

		playerTracker._Population -= 1
		playerTracker._PopulationChanged:Fire(playerTracker._Population)
		playerTracker._PlayerLeft:Fire(player)
	end
end


--[[
@param     BasePart         trackingSpace         | The BasePart that will be scanned for players
@param     number?          capacity              | The maximum number of players the tracker will process
@param     OverlapParams    trackingParameters    | The OverlapParams for the tracking query
@return    PlayerTracker

Constructs a PlayerTracker object.
]]
function PlayerTracker.new(trackingSpace: BasePart, capacity: number?, trackingParameters: OverlapParams?): PlayerTracker
	assertLevel(trackingSpace ~= nil, "Argument #1 missing or nil.", 1)

	local self: PlayerTrackerLocal = {} :: PlayerTrackerLocal

	self._IsTracking         = false
	self._TrackingSpace      = trackingSpace
	self._TrackingParameters = trackingParameters
	self._TrackingConnection = nil

	self._PlayerMap  = {}
	self._Population = 0
	self._Capacity   = capacity

	self._PlayerLeft        = Instance.new("BindableEvent")
	self._PlayerEntered     = Instance.new("BindableEvent")
	self._PopulationChanged = Instance.new("BindableEvent")

	self.PlayerLeft        = self._PlayerLeft.Event
	self.PlayerEntered     = self._PlayerEntered.Event
	self.PopulationChanged = self._PopulationChanged.Event

	trackingSpace.Destroying:Connect(function()
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
		warn("PlayerTracker is already tracking.")

		return
	end

	self._IsTracking = true

	local trackingSpace      = self._TrackingSpace
	local trackingParameters = self._TrackingParameters

	self._TrackingConnection = RunService.PostSimulation:Connect(function()
		_updatePlayerTracker(
			self :: PlayerTrackerLocal,
			workspace:GetPartBoundsInBox(trackingSpace.CFrame, trackingSpace.Size, trackingParameters)
		)
	end)
end


--[[
@return    void

Ceases updating the PlayerTracker.
]]
function PlayerTracker:StopTracking()
	self._TrackingConnection:Disconnect()
	self._IsTracking = false
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
@param     number    capacity    | The new capacity of the tracking space 
@return    void

Updates the capacity of the tracking space.
]]
function PlayerTracker:SetCapacity(newCapacity: number)
	assertLevel(newCapacity ~= nil, "Argument #1 missing or nil.", 1)

	self._Capacity = newCapacity
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
	self._PlayerLeft:Destroy()
	self._PlayerEntered:Destroy()
	self._PopulationChanged:Destroy()

	self:StopTracking()
end



export type PlayerTracker = {
	StartTracking : (PlayerTracker) -> (),
	StopTracking  : (PlayerTracker) -> (),

	GetPlayers    : (PlayerTracker) -> {Player},
	GetPopulation : (PlayerTracker) -> number,
	GetCapacity   : (PlayerTracker) -> number,

	SetCapacity : (PlayerTracker, number) -> (),

	IsTracking : (PlayerTracker) -> boolean,

	Destroy : (PlayerTracker) -> (),

	PlayerLeft        : RBXScriptSignal,
	PlayerEntered     : RBXScriptSignal,
	PopulationChanged : RBXScriptSignal,
}

type PlayerMap = {[Player]: true}

type PlayerTrackerLocal = PlayerTracker & {	
	_IsTracking         : boolean,
	_TrackingSpace      : BasePart,
	_TrackingParameters : OverlapParams?,
	_TrackingConnection : RBXScriptConnection?,

	_PlayerMap  : PlayerMap,
	_Population : number,
	_Capacity   : number?,

	_PlayerLeft        : BindableEvent,
	_PlayerEntered     : BindableEvent,
	_PopulationChanged : BindableEvent,
}


return PlayerTracker
