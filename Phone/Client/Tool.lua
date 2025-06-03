--[[
Author     Ziffixture (74087102)
Date       05/27/2025 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
type Phone = Tool & {
	Handle : BasePart,
}



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService   = game:GetService("TextChatService")
local Players           = game:GetService("Players")


local Vendor           = ReplicatedStorage:WaitForChild("Vendor")
local PlayerEssentials = require(Vendor:WaitForChild("PlayerEssentials"))

local Phone        = ReplicatedStorage:WaitForChild("Phone")
local PhoneRemotes = Phone:WaitForChild("Remotes")

local GuiAction    = PhoneRemotes:WaitForChild("GuiAction")
local ToolAction   = PhoneRemotes:WaitForChild("ToolAction")
local CallerAction = PhoneRemotes:WaitForChild("CallerAction")

local Tool   = script.Parent
local Handle = Tool:WaitForChild("Handle")

local Player    = Players.LocalPlayer
local Character = PlayerEssentials.guaranteeCharacterAsync(Player)


local protocols = {}
protocols.Tool   = {}
protocols.Caller = {}



local function onEquipped()
	GuiAction:Fire("Open")
end

local function onUnequipped()
	GuiAction:Fire("Close")
end

local function displayBubble(message: string, alternate: BasePart?)
	local source = alternate or Handle
	if not source:IsDescendantOf(workspace) then
		return
	end
	
	TextChatService:DisplayBubble(source, message)
end

local function onProtocol(subprotocol: string, protocol: string, ...)
	local action = protocols[subprotocol][protocol]
	if not action then
		return 
	end

	action(...)
end

local function filterProtocol(subprotocol: string)
	return function(protocol: string, ...)
		onProtocol(subprotocol, protocol, ...)
	end
end


function protocols.Tool.Dialing()
	displayBubble("*Dialing*")
end

function protocols.Tool.Dropped()
	displayBubble("*Dropped*")
end

function protocols.Tool.HangUp()
	displayBubble("*Hung up*")
end

function protocols.Tool.InCall()
	displayBubble("*Picked up*")
end

function protocols.Caller.Chatted(caller: Player, anonymous: boolean, calling: Player, message: string)	
	local character = calling.Character
	if not character then
		return
	end
	
	local phone = character:FindFirstChild(Tool.Name) :: Phone
	if not phone then
		return
	end
	
	local username = anonymous and "Anonymous" or caller.Name
	
	displayBubble(`{username}: {message}`, phone.Handle)
end

function protocols.Caller.InCall()
	Tool.Parent = Character
end



Tool.Equipped:Connect(onEquipped)
Tool.Unequipped:Connect(onUnequipped)

ToolAction.Event:Connect(filterProtocol("Tool"))
CallerAction.OnClientEvent:Connect(filterProtocol("Caller"))
