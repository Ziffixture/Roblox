--[[
Author     Ziffixture (74087102)
Date       24/05/30 (YY/MM/DD)
Version    1.0.0 (Beta)
]]


--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local GuiService        = game:GetService("GuiService")
local Players           = game:GetService("Players")


if RunService:IsServer() then
	error("This module can only be used on the client.")
end


local Vendor = ReplicatedStorage:WaitForChild("Vendor")
local Signal = require(Vendor:WaitForChild("Signal"))

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local GuiObjectHover = {}


local registeredGuiObjects        : {GuiObjectData}      = {} :: {GuiObjectData}
local processGuiObjectsConnection : RBXScriptConnection? = nil



local function registerGuiObject(guiObject: GuiObject): GuiObjectData
	local data = {} :: GuiObjectData
	data.Instance     = guiObject
	data.MouseEntered = Signal.new()
	data.MouseLeft    = Signal.new()
	data.WasInside    = false
	
	table.insert(registeredGuiObjects, data)
	
	return data
end

local function unregisterGuiObject(guiObject: GuiObject): GuiObjectData?
	for index, data in registeredGuiObjects do
		if data.Instance == guiObject then
			table.remove(registeredGuiObjects, index)
			
			return data
		end
	end
	
	return nil
end

local function processGuiObjects()
	local mouseLocation      = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local frontmostGuiObject = PlayerGui:GetGuiObjectsAtPosition(mouseLocation.X, mouseLocation.Y)[1]
	
	for _, data in registeredGuiObjects do
		if data.Instance == frontmostGuiObject then
			if not data.WasInside then
				data.WasInside = true
				data.MouseEntered:Fire()
			end
		else
			if data.WasInside then
				data.WasInside = false
				data.MouseLeft:Fire()
			end
		end
	end
end


function GuiObjectHover.generateHoverEvents(guiObject: GuiObject): (Signal.Signal<>, Signal.Signal<>)
	local data = registerGuiObject(guiObject)
	
	guiObject.Destroying:Once(function()
		GuiObjectHover.expireHoverEvents(guiObject)
	end)
	
	if #registeredGuiObjects == 1 then
		processGuiObjectsConnection = RunService.RenderStepped:Connect(processGuiObjects)
	end
	
	return data.MouseEntered, data.MouseLeft
end

function GuiObjectHover.expireHoverEvents(guiObject: GuiObject)
	local data = unregisterGuiObject(guiObject)
	if not data then
		warn(`GuiObject "{guiObject}" was never registered.`)
		
		return
	end
	
	data.MouseEntered:DisconnectAll()
	data.MouseLeft:DisconnectAll()
	
	if processGuiObjectsConnection and #registeredGuiObjects == 0 then
		processGuiObjectsConnection:Disconnect()
	end
end



type GuiObjectData = {
	Instance  : GuiObject,
	
	MouseEntered : Signal.Signal<>,
	MouseLeft    : Signal.Signal<>,
	
	WasInside : boolean,
}


return GuiObjectHover
