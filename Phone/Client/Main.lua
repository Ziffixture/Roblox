--[[
Author     Ziffixture (74087102)
Date       05/31/2025 (MM/DD/YYYY)
Version    1.0.1
]]



--!strict
type ButtonContainer = Frame & {
	Button : TextButton,
}



local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local UserInputService   = game:GetService("UserInputService")
local Players            = game:GetService("Players")


local Vendor             = ReplicatedStorage:WaitForChild("Vendor")
local Maid               = require(Vendor:WaitForChild("Maid"))
local Sounds             = require(Vendor:WaitForChild("Sounds"))
local Searchable         = require(Vendor:WaitForChild("Searchable"))
local PromptConfirmAsync = require(Vendor:WaitForChild("PromptConfirmAsync"))

local Player = Players.LocalPlayer

local Phone        = ReplicatedStorage:WaitForChild("Phone")
local PhoneTypes   = require(Phone:WaitForChild("Types"))
local PhoneRemotes = Phone:WaitForChild("Remotes")
local PhoneSounds  = Phone:WaitForChild("Sounds")

local GuiAction    = PhoneRemotes:WaitForChild("GuiAction")
local ToolAction   = PhoneRemotes:WaitForChild("ToolAction")
local CallerAction = PhoneRemotes:WaitForChild("CallerAction")

local Gui     = script.Parent
local Caller  = script:WaitForChild("Caller")
local Contact = script:WaitForChild("Contact")

local Incoming = Gui:WaitForChild("Incoming")

local Island         = Gui:WaitForChild("Island")
local HangUp         = Island:WaitForChild("HangUp")
local TurnOff        = Island:WaitForChild("TurnOff")
local Anonymous      = Island:WaitForChild("Anonymous")

local Centre         = Island:WaitForChild("Centre")
local InCall         = Centre:WaitForChild("InCall")
local Home           = Centre:WaitForChild("Home")
local Search         = Home:WaitForChild("Search")
local Suggestion     = Home:WaitForChild("Suggestion")
local ScrollingFrame = Home:WaitForChild("ScrollingFrame")
local UiListLayout   = ScrollingFrame:WaitForChild("UIListLayout")


local ENABLED_COLOR  = Color3.fromRGB(20, 205, 95)
local DISABLED_COLOR = Color3.fromRGB(195, 25, 0)

local ANONYMOUS_ICON      = "rbxassetid://17132521951"
local ANONYMOUS_GAME_PASS = 1235115793


local protocols = {}
local maid      = Maid.new()

local inCall    = false
local dialing   = false
local accepting = true
local anonymous = false



local function isReceiving()
	return #Incoming:GetChildren() > 2
end

local function getUserThumbnailAsync(player: Player): string
	local success, response = pcall(function()
		local image, isReady = Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		
		return isReady and image
	end)
	
	return success and response or ANONYMOUS_ICON
end

local function getCallerDetails(player: Player, anonymous): (string, string)
	local icon     = anonymous and ANONYMOUS_ICON or getUserThumbnailAsync(player)
	local username = anonymous and "Anonymous" or player.Name
	
	return icon, username
end

local function getRenderedContacts(): {GuiObject}
	local contacts = {}
	
	for _, child in ScrollingFrame:GetChildren() do
		if child:IsA("ImageButton") then
			table.insert(contacts, child)
		end
	end
	
	return contacts
end

local function removeContact(player: Player)
	local contact = ScrollingFrame:FindFirstChild(player.Name)
	if contact then
		contact:Destroy()
	end
end

local function renderContact(player: Player)
	local container         = Contact:Clone()
	container.Username.Text = player.Name
	container.Icon.Image    = getUserThumbnailAsync(player) or ANONYMOUS_ICON
	container.Name          = player.Name
	container.Parent        = ScrollingFrame
	
	container.Activated:Connect(function()
		if dialing then
			CallerAction:FireServer("Cancel")
		end
		
		CallerAction:FireServer("Dial", player)
	end)
end

local function renderContacts()
	for _, player in Players:GetPlayers() do
		if player ~= Player then
			task.defer(renderContact, player)
		end
	end
	
	Players.PlayerAdded:Connect(renderContact)
	Players.PlayerRemoving:Connect(removeContact)
end

local function renderCallerAsync(player: Player, anonymous: boolean)
	local container = Caller:Clone()
	local centre    = container.Centre
	local details   = centre.Details

	local icon, username = getCallerDetails(player, anonymous)

	details.Icon.Image    = icon
	details.Username.Text = username
	
	container.Name   = player.Name
	container.Parent = Incoming

	local accepts = PromptConfirmAsync(centre)
	local action  = accepts and "Accept" or "Decline"
	
	CallerAction:FireServer(action, player)
	container:Destroy()
	
	if not isReceiving() then
		Sounds.stopSound(PhoneSounds.Receiving)
	end
end

local function handleCavasSize()
	local function onRenderedContactsChanged()
		local absoluteContentSize = UiListLayout.AbsoluteContentSize

		ScrollingFrame.CanvasSize = UDim2.fromOffset(
			absoluteContentSize.X,
			absoluteContentSize.Y
		)
	end
	
	onRenderedContactsChanged()
	
	ScrollingFrame.ChildAdded:Connect(onRenderedContactsChanged)
	ScrollingFrame.ChildRemoved:Connect(onRenderedContactsChanged)
end

local function onButtonActivated(container: ButtonContainer, callback: (TextButton) -> ()): RBXScriptConnection
	local button = container.Button
	
	return button.Activated:Connect(function()
		callback(button)
	end)
end

local function onToggleAnonymous(button: TextButton)
	if not MarketplaceService:UserOwnsGamePassAsync(Player.UserId, ANONYMOUS_GAME_PASS) then
		MarketplaceService:PromptGamePassPurchase(Player, ANONYMOUS_GAME_PASS)
		
		return
	end
	
	anonymous = not anonymous
	
	button.Text             = anonymous and "ANONYMOUS ON" or "ANONYMOUS OFF"
	button.BackgroundColor3 = anonymous and ENABLED_COLOR or DISABLED_COLOR
	
	CallerAction:FireServer("ToggleAnonymous")
end

local function onTurnOff(button: TextButton)
	accepting = not accepting

	button.Text             = accepting and "TURN OFF" or "TURN ON"
	button.BackgroundColor3 = accepting and ENABLED_COLOR or DISABLED_COLOR

	CallerAction:FireServer("ToggleAccepting")
end

local function onHangUp()
	CallerAction:FireServer("HangUp")
end

local function onProtocol(protocol: string, ...)
	local action = protocols[protocol]
	if not action then
		return
	end

	action(...)
end


function protocols.Dialing()
	dialing = true
	
	ToolAction:Fire("Dialing")
	
	Sounds.stopSound(PhoneSounds.Dropped)
	Sounds.playSoundAsync(PhoneSounds.Dial)
	Sounds.playSoundAsync(PhoneSounds.Dialing)
end

function protocols.Receiving(caller: Player, anonymous: boolean)
	Sounds.playSound(PhoneSounds.Receiving, true)	
	
	renderCallerAsync(caller, anonymous)
end

function protocols.Dropped()
	dialing = false
	
	ToolAction:Fire("Dropped")
	
	Sounds.stopSound(PhoneSounds.Dial)
	Sounds.stopSound(PhoneSounds.Dialing)
	Sounds.playSound(PhoneSounds.Dropped)
end

function protocols.Cancel(caller: Player)
	local container = Incoming:FindFirstChild(caller.Name)
	if container then
		container:Destroy()
	end
	
	if not isReceiving() then
		Sounds.stopSound(PhoneSounds.Receiving)
	end
end

function protocols.InCall(timestamp: number, caller: Player, anonymous: boolean)
	dialing = false
	inCall  = true
	
	ToolAction:Fire("InCall")
	
	Sounds.stopSound(PhoneSounds.Dial)
	Sounds.stopSound(PhoneSounds.Dialing)
	Sounds.stopSound(PhoneSounds.Dropped)
	Sounds.stopSound(PhoneSounds.Receiving)
	Sounds.playSound(PhoneSounds.PickUp)
	
	for _, container in Incoming:GetChildren() do
		if container:IsA("Frame") then
			container:Destroy()
		end
	end

	local icon, username = getCallerDetails(caller, anonymous)

	InCall.Icon.Image    = icon
	InCall.Username.Text = username

	Island.Visible  = true
	InCall.Visible  = true
	HangUp.Visible  = true
	TurnOff.Visible = false
	Home.Visible    = false

	maid:GiveTask(task.defer(function()
		local secondsElapsed = math.min(0, DateTime.now().UnixTimestamp - timestamp)
		
		while inCall do
			InCall.Timer.Text = string.format("%d:%02d", secondsElapsed // 60, secondsElapsed % 60)
			
			secondsElapsed += 1
			
			task.wait(1)
		end
	end))
end

function protocols.HangUp()
	inCall = false
	
	Sounds.playSound(PhoneSounds.HangUp)
	
	maid:DoCleaning()
	ToolAction:Fire("HangUp")

	InCall.Visible  = false
	HangUp.Visible  = false
	TurnOff.Visible = true
	Home.Visible    = true
end

function protocols.Open()
	Island.Visible = true
	
	Sounds.playSound(PhoneSounds.Equip)
end

function protocols.Close()
	Island.Visible = false
	
	if inCall then
		CallerAction:FireServer("HangUp")
	elseif dialing then
		CallerAction:FireServer("Cancel")
	end
end



renderContacts()
handleCavasSize()

onButtonActivated(HangUp, onHangUp)
onButtonActivated(TurnOff, onTurnOff)
onButtonActivated(Anonymous, onToggleAnonymous)

Searchable(Home, getRenderedContacts)

GuiAction.Event:Connect(onProtocol)
CallerAction.OnClientEvent:Connect(onProtocol)
