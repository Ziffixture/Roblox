--[[
Author     Ziffix (74087102)
Date       06/10/2025 (MM/DD/YYYY)
Version    1.0.2
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")


local Vendor = ReplicatedStorage:WaitForChild("Vendor")
local Signal = require(Vendor:WaitForChild("Signal"))

local Player      = Players.LocalPlayer
local PlayerGui   = Player:WaitForChild("PlayerGui")
local ColorPicker = PlayerGui:WaitForChild("ColorPicker") :: ColorPicker

local Feature = script.Parent
local Color   = Feature:WaitForChild("Color")

local Controller = {}
Controller.ColorActioned = Signal.new() :: Signal.Signal<boolean, Color3?> 
Controller.ColorPrompted = Signal.new() :: Signal.Signal<Color3?, UDim2?> 



function Controller.actionColor(save: boolean)
	Controller.ColorActioned:Fire(save, save and Color.Value or nil)
end

function Controller.promptPickColorAsync(initialColor: Color3?, position: UDim2?): (boolean, Color3?)
	Controller.ColorPrompted:Fire(initialColor, position)
	
	return Controller.ColorActioned:Wait()
end



type ColorPicker = ScreenGui & {
	Container : Frame,
}


return Controller
