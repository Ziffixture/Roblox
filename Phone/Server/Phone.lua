--[[
Author     Ziffixture (74087102)
Date       05/27/2025 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")


local Feature = script.Parent
local Caller  = require(Feature.Caller)

local SharedFeature = ReplicatedStorage.Phone
local SharedRemotes = SharedFeature.Remotes
local CallerAction  = SharedRemotes.CallerAction


local ANONYMOUS_GAME_PASS = 1235115793


local protocols = {}



local function onProtocol(caller: Player, protocol: string, recipient: Player)
	local action = protocols[protocol]
	if not action then
		error(`Unrecognized protocol "{protocol}".`)
	end
	
	local caller    = Caller.get(caller)           :: Caller.Caller
	local recipient = Caller.get(recipient :: any) :: Caller.Caller
	
	if not (caller or recipient) then
		warn(`Could not communicate; unable to resolve callers.`)
	end

	return action(caller, recipient)
end


function protocols.Dial(caller: Caller.Caller, recipient: Caller.Caller)
	caller:Dial(recipient)
end

function protocols.Accept(caller: Caller.Caller, recipient: Caller.Caller)
	caller:Accept(recipient)
end

function protocols.Decline(caller: Caller.Caller, recipient: Caller.Caller)
	caller:Decline(recipient)
end

function protocols.HangUp(caller: Caller.Caller)
	caller:HangUp()
end

function protocols.Cancel(caller: Caller.Caller)
	caller:Cancel()
end

function protocols.ToggleAnonymous(caller: Caller.Caller)
	if not MarketplaceService:UserOwnsGamePassAsync(caller._Player.UserId, ANONYMOUS_GAME_PASS) then
		return
	end
	
	caller:SetAnonymous(not caller:IsAnonymous())
	
	return caller:IsAnonymous()
end

function protocols.ToggleAccepting(caller: Caller.Caller)
	caller:SetAccepting(not caller:IsAccepting())
end



Players.PlayerAdded:Connect(Caller.register)
Players.PlayerRemoving:Connect(Caller.deregister)

CallerAction.OnServerEvent:Connect(onProtocol)
