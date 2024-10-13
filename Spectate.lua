--[[
Author     Ziffixture (74087102)
Date       24/10/12 (YY/MM/DD)
Version    1.1.5
]]



--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local UserInputService     = game:GetService("UserInputService")
local Players              = game:GetService("Players")


local PLAYER_MOVEMENT_DISABLE_FLAG = "DisablePlayerMovement"

local CURRENT_CAMERA = workspace.CurrentCamera
local LOCAL_PLAYER   = Players.LocalPlayer


local Vendor  = ReplicatedStorage:WaitForChild("Vendor")
local Connect = require(Vendor:WaitForChild("Connect"))
local Signal  = require(Vendor:WaitForChild("Signal"))

local Feature = script.Parent
local Types   = require(Feature:WaitForChild("Types"))

local Gui       = LOCAL_PLAYER.PlayerGui:WaitForChild("Spectate")
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



local function safeInput(key: Enum.KeyCode, callback: (InputObject) -> ())
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

local function getTrackedCharactersInWorkspace(excludePlayers: {Player}): ({Types.Character}, Signal.Signal<>, Signal.Signal<>)
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
		if character.Parent ~= workspace then
			return
		end

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

	for _, player in Players:GetPlayers() do
		if not table.find(excludePlayers, player) then
			trackCharacter(player)
		end
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
		CURRENT_CAMERA.CameraSubject = humanoid
	end
end

local function stopSpectating()
	Container.Visible = false
	isSpectating      = false

	trySetCameraToCharacter(LOCAL_PLAYER.Character)
	enablePlayerMovement()

	Connect.clean(tray.KeyBindConnections)

	Connect.clean(tray.AncestryChangedConnections)
	Connect.clean(tray.RawCharacterAddedConnections)
	Connect.clean(tray.RawCharacterRemovingConnections)

	Connect.clean(tray.ButtonConnections)

	;(tray.PlayerAddedConnection :: RBXScriptConnection):Disconnect()	
	;(tray.CharacterRemovedConnection :: Signal.Connection):Disconnect()
end

local function tryStartSpectating()
	local characters, _, characterRemoved = getTrackedCharactersInWorkspace({LOCAL_PLAYER})
	if #characters == 0 then
		return
	end

	local index = 1

	Container.Visible = true
	isSpectating      = true
	
	disablePlayerMovement()

	local function tryLoadSubject()
		local character = characters[index]
		trySetCameraToCharacter(character)

		Username.Text = character.Name
	end

	local function offsetIndex(offset)
		local length = #characters

		index = (index + offset - 1) % length + 1
		
		if index < 1 then
			index += length
		end
	end

	local function nextCharacter()
		offsetIndex(1)
		tryLoadSubject()
	end

	local function previousCharacter()
		offsetIndex(-1)
		tryLoadSubject()
	end

	tray.CharacterRemovedConnection = characterRemoved:Connect(function()
		local characterCount = #characters
		if characterCount == 0 then
			stopSpectating()

			return
		end

		if index > characterCount then
			index = 1
		end

		tryLoadSubject()
	end)

	tray.KeyBindConnections.E = safeInput(Enum.KeyCode.E, nextCharacter)
	tray.KeyBindConnections.Q = safeInput(Enum.KeyCode.Q, previousCharacter)

	local nextConnection     = Next.Activated:Connect(nextCharacter)
	local previousConnection = Previous.Activated:Connect(previousCharacter)

	table.insert(tray.ButtonConnections, nextConnection)
	table.insert(tray.ButtonConnections, previousConnection)

	tryLoadSubject()
end

local function onSpectate()
	if isSpectating then
		stopSpectating()
	else
		tryStartSpectating()
	end
end



Spectate.Activated:Connect(onSpectate)
