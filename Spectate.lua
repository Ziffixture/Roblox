--[[
Author     Ziffixture (74087102)
Date       01/14/2025 (MM/DD/YYYY)
Version    1.3.2
]]



--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local UserInputService     = game:GetService("UserInputService")
local Players              = game:GetService("Players")


local PLAYER_MOVEMENT_DISABLE_FLAG = "DisablePlayerMovement"

local CurrentCamera = workspace.CurrentCamera
local LocalPlayer   = Players.LocalPlayer


local Vendor  = ReplicatedStorage:WaitForChild("Vendor")
local Connect = require(Vendor:WaitForChild("Connect")) -- https://github.com/SolarScuffle-Bot/ConnectUtil
local Signal  = require(Vendor:WaitForChild("Signal")) -- https://github.com/Data-Oriented-House/LemonSignal

local Feature = script.Parent
local Types   = require(Feature:WaitForChild("Types"))

local Gui       = LocalPlayer.PlayerGui:WaitForChild("Spectate")
local Spectate  = Gui:WaitForChild("Spectate")
local Container = Gui:WaitForChild("Container")

local Centre   = Container:WaitForChild("Centre")
local Username = Centre:WaitForChild("Username")
local Previous = Centre:WaitForChild("Previous")
local Next     = Centre:WaitForChild("Next")


local tray: Types.Tray = {
	KeyBindConnections = {},

	RawCharacterAddedConnections    = {},
	RawCharacterRemovingConnections = {},
	AncestryChangedConnections      = {},

	ButtonConnections = {},
}

local isSpectating = false



local function safeInput(key: Enum.KeyCode, callback: (InputObject) -> ()): RBXScriptConnection
	return UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.KeyCode ~= key then
			return
		end

		callback(input)
	end)
end

local function disablePlayerMovement()
	ContextActionService:BindAction(
		PLAYER_MOVEMENT_DISABLE_FLAG,
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		table.unpack(Enum.PlayerActions:GetEnumItems())
	)
end

local function enablePlayerMovement()
	ContextActionService:UnbindAction(PLAYER_MOVEMENT_DISABLE_FLAG)
end

local function getTrackedCharactersInWorkspace(excludePlayers: {Player}): ({Types.Character}?, Signal.Signal<>?, Signal.Signal<>?)
	local players = {}

	for _, player in Players:GetPlayers() do
		if not table.find(excludePlayers, player) then
			table.insert(players, player)
		end
	end

	if #players == 0 then
		return nil, nil, nil
	end

	local characters = {}
	local characterAdded   = Signal.new()
	local characterRemoved = Signal.new()

	local function onCharacterRemoving(character: Model, player: Player)
		local index = table.find(characters, character :: Types.Character)
		if not index then
			return
		end

		table.remove(characters, index)

		characterRemoved:Fire()
	end

	local function onCharacterAdded(character: Model, player: Player)
		if not tray.AncestryChangedConnections[character] then
			tray.AncestryChangedConnections[character] = character.AncestryChanged:Connect(function(_, newParent: Instance)
				if newParent ~= workspace then
					onCharacterRemoving(character, player)
				elseif newParent == workspace then
					onCharacterAdded(character, player)
				end
			end)
		end

		table.insert(characters, character :: Types.Character)

		characterAdded:Fire()
	end

	local function trackCharacter(player: Player)
		local characterAdded, characterRemoving = Connect.character(player, onCharacterAdded, function(character, player)
			tray.AncestryChangedConnections[character]:Disconnect()

			onCharacterRemoving(character, player)
		end)

		table.insert(tray.RawCharacterAddedConnections, characterAdded :: RBXScriptConnection)
		table.insert(tray.RawCharacterRemovingConnections, characterRemoving :: RBXScriptConnection)
	end

	for _, player in players do
		trackCharacter(player)
	end

	tray.PlayerAddedConnection = Players.PlayerAdded:Connect(trackCharacter)

	return characters, characterAdded, characterRemoved
end

local function trySetCameraToCharacter(character: Types.Character?)
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		CurrentCamera.CameraSubject = humanoid
	end
end

local function stopSpectating()
	trySetCameraToCharacter(LocalPlayer.Character)
	enablePlayerMovement()

	;(tray.CharacterRemovedConnection :: Signal.Connection<>):Disconnect()
	;(tray.PlayerAddedConnection :: RBXScriptConnection):Disconnect()
	
	Connect.clean(tray)

	isSpectating      = false
	Container.Visible = false
end

local function tryStartSpectating()
	local characters, _, characterRemoved = getTrackedCharactersInWorkspace({LocalPlayer})
	if not characters then
		return
	end

	local index = 1

	local function tryLoadSubject()
		local character = characters[index]
		trySetCameraToCharacter(character)

		Username.Text = character.Name
	end

	local function reAdjustIndex(offset: number?)
		index = (index + (offset or 0) - 1) % #characters + 1
	end

	local function nextCharacter()
		reAdjustIndex(1)
		tryLoadSubject()
	end

	local function previousCharacter()
		reAdjustIndex(-1)
		tryLoadSubject()
	end

	tray.CharacterRemovedConnection = (characterRemoved :: Signal.Signal<>):Connect(function()
		local characterCount = #characters
		if characterCount == 0 then
			stopSpectating()

			return
		end

		reAdjustIndex()
		tryLoadSubject()
	end)

	tray.KeyBindConnections.E = safeInput(Enum.KeyCode.E, nextCharacter)
	tray.KeyBindConnections.Q = safeInput(Enum.KeyCode.Q, previousCharacter)

	local nextConnection     = Next.Activated:Connect(nextCharacter)
	local previousConnection = Previous.Activated:Connect(previousCharacter)

	table.insert(tray.ButtonConnections, nextConnection)
	table.insert(tray.ButtonConnections, previousConnection)

	disablePlayerMovement()
	tryLoadSubject()

	isSpectating      = true
	Container.Visible = true
end

local function onSpectate()
	if isSpectating then
		stopSpectating()
	else
		tryStartSpectating()
	end
end



Spectate.Activated:Connect(onSpectate)
