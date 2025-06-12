--[[
Author     Ziffixture (74087102)
Date       06/12/2025 (MM/DD/YYYY)
Version    1.1.4
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService       = game:GetService("TextService")
local Players           = game:GetService("Players")


local Vendor = ReplicatedStorage.Vendor
local Maid   = require(Vendor.Maid)

local Feature       = script.Parent
local Configuration = Feature.Configuration 

local SharedFeature = ReplicatedStorage.Phone
local SharedTypes   = require(SharedFeature.Types)
local SharedRemotes = SharedFeature.Remotes

local Caller          = {}
local CallerPrototype = {}


local callers = {} :: CallerMap



local function tryFilterMessageAsync(message: string, source: Player): string?
	if not Configuration.BroadcastFilter.Value then
		return message
	end
	
	local success, response = pcall(function()
		local result   = TextService:FilterStringAsync(message, source.UserId)
		local filtered = result:GetNonChatStringForBroadcastAsync()
	end)
	
	if not success then
		warn(`Failed to filter message from {source}; {response}`)
		
		return
	end
	
	return response
end


function Caller.propagateAll(...)
	SharedRemotes.CallerAction:FireAllClients(...)
end

function Caller.register(player: Player): Caller
	local self = (setmetatable({}, CallerPrototype) :: any) :: Caller

	self._Player     = player
	self._Recipient  = nil
	self._Dialing    = nil
	self._Receiving  = {}
	self._Accepting  = true
	self._Anonymous  = false
	self._Instigator = false
	self._Maid       = Maid.new()
	
	callers[player] = self
	
	return self
end

function Caller.deregister(player: Player)
	if callers[player] then
		callers[player]:Destroy()
	end
end

function Caller.get(player: Player): Caller?
	return callers[player]
end

function CallerPrototype.Propagate(self: Caller, ...)
	SharedRemotes.CallerAction:FireClient(self._Player, ...)
end

function CallerPrototype.PropagateAll(self: Caller, ...)
	SharedRemotes.CallerAction:FireAllClients(self._Player, ...)
end

function CallerPrototype.CanDial(self: Caller, recipient: Caller): boolean
	if self._Dialing then
		return false
	end
	
	local available    = recipient._Accepting
	local accomodating = #recipient._Receiving < Configuration.MaxReceiving.Value
	
	return available and accomodating
end

function CallerPrototype.CanAccept(self: Caller, caller: Caller): boolean
	local dialed    = caller:IsDialing(self) and not caller:IsInCall()
	local receiving = self:IsReceiving(caller) and self._Accepting

	return dialed and receiving
end

function CallerPrototype.Dial(self: Caller, recipient: Caller)
	if not self:CanDial(recipient) then
		self:Propagate("Dropped")
		
		return 
	end
	
	self:Cancel()

	self._Dialing = recipient
	self:Propagate("Dialing")
	
	recipient:Receive(self)
end

function CallerPrototype.Receive(self: Caller, caller: Caller)
	table.insert(self._Receiving, caller)

	self:Propagate("Receiving", caller._Player, caller._Anonymous)
end

function CallerPrototype.Accept(self: Caller, caller: Caller)
	if not self:CanAccept(caller) then
		return
	end
	
	for index = #self._Receiving, 1, -1 do
		local otherCaller = self._Receiving[index]
		if otherCaller ~= caller then
			self:Drop(otherCaller)
		end
	end
	
	self:HangUp()
	self:EnterCallWith(caller)
end

function CallerPrototype.EnterCallWith(self: Caller, caller: Caller)
	self:StopReceiving(caller)
	caller:StopDialing()
	
	self._Recipient    = caller
	caller._Recipient  = self
	caller._Instigator = true
	
	self:ReplicateChats()
	caller:ReplicateChats()
	
	local timestamp = DateTime.now().UnixTimestamp

	self:Propagate("InCall", timestamp, caller._Player, caller._Anonymous)
	caller:Propagate("InCall", timestamp, self._Player, self._Anonymous)
end

function CallerPrototype.ReplicateChats(self: Caller)
	local player    = self._Player
	local anonymous = self._Anonymous and self._Instigator

	self._Maid:GiveTask(player.Chatted:Connect(function(message: string)
		local recipient = self._Recipient
		if not recipient then
			return
		end
		
		local filteredMessage = tryFilterMessageAsync(message, player) or "Failed to filter."

		Caller.propagateAll("Chatted", player, anonymous, recipient._Player, message)
	end))
end

function CallerPrototype.Decline(self: Caller, caller: Caller)
	if not self:IsReceiving(caller) then
		return
	end
	
	self:Drop(caller)
end

function CallerPrototype.HangUp(self: Caller)
	if not self:IsInCall() then
		return
	end
	
	local recipient  = self._Recipient :: Caller
	self._Recipient  = nil
	self._Instigator = false
	self._Maid:DoCleaning()

	recipient:HangUp()
	recipient:Propagate("HangUp")
end

function CallerPrototype.Drop(self: Caller, caller: Caller)
	if not self:IsReceiving(caller) then
		return
	end
	
	self:StopReceiving(caller)

	caller:StopDialing()
	caller:Propagate("Dropped")
end

function CallerPrototype.Cancel(self: Caller, caller: Caller?)
	if caller then
		self:Propagate("Cancel", caller._Player)
		self:StopReceiving(caller)
		
		return
	end

	if self._Dialing then
		self._Dialing:Cancel(self)
	end
	
	self:StopDialing()
end

function CallerPrototype.StopReceiving(self: Caller, caller: Caller)
	table.remove(self._Receiving, table.find(self._Receiving, caller))
end

function CallerPrototype.StopDialing(self: Caller)
	self._Dialing = nil
end

function CallerPrototype.IsInCall(self: Caller): boolean
	return self._Recipient ~= nil
end

function CallerPrototype.IsDialing(self: Caller, recipient: Caller)
	return self._Dialing == recipient
end

function CallerPrototype.IsReceiving(self: Caller, caller: Caller)
	return table.find(self._Receiving, caller) ~= nil
end

function CallerPrototype.IsAccepting(self: Caller)
	return self._Accepting
end

function CallerPrototype.IsAnonymous(self: Caller)
	return self._Anonymous
end

function CallerPrototype.SetAccepting(self: Caller, accepting: boolean)
	self._Accepting = accepting
end

function CallerPrototype.SetAnonymous(self: Caller, anonymous: boolean)
	self._Anonymous = anonymous
end

function CallerPrototype.Destroy(self: Caller)
	self:HangUp()

	callers[self._Player] = nil

	for key in self do
		self[key] = nil
	end
end



CallerPrototype.__index = CallerPrototype


export type Caller = {
	_Player     : Player,
	_Recipient  : Caller?,
	_Dialing    : Caller?,
	_Receiving  : {Caller},
	_Accepting  : boolean,
	_Anonymous  : boolean,
	_Instigator : boolean,
	_Maid       : Maid.Maid,

	Propagate    : (self: Caller, ...any) -> (),
	PropagateAll : (self: Caller, ...any) -> (),

	CanDial   : (self: Caller, recipient: Caller) -> (),
	CanAccept : (self: Caller, caller: Caller) -> (),

	Dial           : (self: Caller, recipient: Caller) -> (),
	Accept         : (self: Caller, caller: Caller) -> (),
	EnterCallWith  : (self: Caller, caller: Caller) -> (),
	ReplicateChats : (self: Caller) -> (),
	Receive        : (self: Caller, caller: Caller) -> (),
	Decline        : (self: Caller, caller: Caller) -> (),
	Drop           : (self: Caller, caller: Caller) -> (),
	HangUp         : (self: Caller) -> (),
	Cancel         : (self: Caller, caller: Caller?) -> (),
	StopDialing    : (self: Caller) -> (),
	StopReceiving  : (self: Caller, caller: Caller) -> (),

	IsInCall    : (self: Caller) -> boolean,
	IsDialing   : (self: Caller, recipient: Caller) -> boolean,
	IsReceiving : (self: Caller, caller: Caller) -> boolean,
	IsAccepting : (self: Caller) -> boolean,
	IsAnonymous : (self: Caller) -> boolean,

	SetAccepting : (self: Caller, accepting: boolean) -> (),
	SetAnonymous : (self: Caller, anonymous: boolean) -> (),

	Destroy : (self: Caller) -> (),	
}

type CallerMap = {
	[Player]: Caller,
}


return Caller
