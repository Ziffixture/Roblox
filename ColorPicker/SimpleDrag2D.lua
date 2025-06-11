--[[
Author     Ziffix (74087102)
Date       06/09/2025 (MM/DD/YYYY)
Version    1.0.1
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local GuiService        = game:GetService("GuiService")


local Vendor = ReplicatedStorage:WaitForChild("Vendor")
local Signal = require(Vendor:WaitForChild("Signal"))
local Maid   = require(Vendor:WaitForChild("Maid"))

local SimpleDrag2D = {}
SimpleDrag2D.__index = SimpleDrag2D



local function onInput(inputEvent: RBXScriptSignal, userInputType: Enum.UserInputType, callback: () -> ()): RBXScriptConnection
	return inputEvent:Connect(function(input: InputObject)
		if input.UserInputType == userInputType then
			callback()
		end
	end)
end


function SimpleDrag2D.new(dragging: GuiObject, container: GuiObject, axes: Vector2): SimpleDrag2D
	local draggingScreenGui = dragging:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui
	if not draggingScreenGui then
		error("Drag subject must have a ScreenGui.")
	end
	
	local self = (setmetatable({}, SimpleDrag2D) :: any) :: SimpleDrag2D
	
	self.Maid = Maid.new()

	self.xAxis = axes.X == 1
	self.yAxis = axes.Y == 1

	self.Container = container
	
	self.Dragged           = Signal.new()
	self.Dragging          = dragging
	self.DraggingScreenGui = draggingScreenGui
	
	self:SetDragInstigator(dragging)
	self:SetDragInstigator(container)

	return self
end

function SimpleDrag2D.SetDragInstigator(self: SimpleDrag2D, dragInstigator: GuiObject)
	local function onDragged()
		self:PositionDragging()
	end
	
	local function onDragEnded()
		self.Maid:DoCleaning()
	end
	
	local function onDragStarted()
		self.Maid:GiveTask(onInput(UserInputService.InputChanged, Enum.UserInputType.MouseMovement, onDragged))
		self.Maid:GiveTask(onInput(UserInputService.InputEnded, Enum.UserInputType.MouseButton1, onDragEnded))
	end
	
	onInput(dragInstigator.InputBegan, Enum.UserInputType.MouseButton1,onDragStarted)
end

function SimpleDrag2D.GetMouseLocation(self: SimpleDrag2D): Vector2
	local mouseLocation = UserInputService:GetMouseLocation()

	if not self:IgnoreGuiInset() then
		mouseLocation -= GuiService:GetGuiInset()
	end

	return mouseLocation
end

function SimpleDrag2D.GetPosition(self: SimpleDrag2D): UDim2
	local mouseLocation = self:GetMouseLocation()

	local draggingPosition = self.Dragging.Position

	local absoluteContainerSize     = self.Container.AbsoluteSize
	local absoluteContainerPosition = self.Container.AbsolutePosition

	local xScale: number
	local yScale: number

	if self.xAxis then
		xScale = math.clamp(mouseLocation.X - absoluteContainerPosition.X, 0, absoluteContainerSize.X) / absoluteContainerSize.X
	else
		xScale = draggingPosition.X.Scale
	end

	if self.yAxis then
		yScale = math.clamp(mouseLocation.Y - absoluteContainerPosition.Y, 0, absoluteContainerSize.Y) / absoluteContainerSize.Y
	else
		yScale = draggingPosition.Y.Scale
	end

	return UDim2.fromScale(xScale, yScale)
end

function SimpleDrag2D.PositionDragging(self: SimpleDrag2D)
	self.Dragging.Position = self:GetPosition()
	
	self.Dragged:Fire()
end

function SimpleDrag2D.IgnoreGuiInset(self: SimpleDrag2D): boolean
	return self.DraggingScreenGui.IgnoreGuiInset
end



type SimpleDrag2D = {
	Maid : any,

	xAxis : boolean,
	yAxis : boolean,

	Dragged           : Signal.Signal<>,
	Dragging          : GuiObject,
	DraggingScreenGui : ScreenGui,

	Container : GuiObject,

	IgnoreGuiInset    : (self: SimpleDrag2D) -> boolean,
	SetDragInstigator : (self: SimpleDrag2D, dragInstigator: GuiObject) -> (),
	GetMouseLocation  : (self: SimpleDrag2D) -> Vector2,
	GetPosition       : (self: SimpleDrag2D) -> UDim2,
	PositionDragging  : (self: SimpleDrag2D) -> (),
}


return SimpleDrag2D
