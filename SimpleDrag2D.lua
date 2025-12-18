--[[
Author     Ziffixture (74087102)
Date       10/12/2025 (MM/DD/YYYY)
Version    1.1.0
]]



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local GuiService        = game:GetService("GuiService")


local Vendor = ReplicatedStorage:WaitForChild("Vendor")
local Signal = require(Vendor:WaitForChild("Signal"))
-- https://github.com/Data-Oriented-House/LemonSignal


local SimpleDrag2D = {}
SimpleDrag2D.__index = SimpleDrag2D



local function onInput(event: RBXScriptSignal, callback: () -> (), inputType: Enum.UserInputType, inputState: Enum.UserInputState?): RBXScriptConnection
	return event:Connect(function(input: InputObject)
		if inputState and input.UserInputState ~= inputState then
			return
		end

		if input.UserInputType == inputType then
			callback()
		end
	end)
end


function SimpleDrag2D.new(container: GuiObject, axes: Vector2): SimpleDrag2D?
	local self = setmetatable({}, SimpleDrag2D) :: SimpleDrag2D

	self.Connections = {}

	self.XAxis  = axes.X == 1
	self.YAxis  = axes.Y == 1
    self.XScale = 0
    self.YScale = 0

    self.Dragging  = false
	self.Dragged   = Signal.new()
	self.Released  = Signal.new()
	self.Container = container

    self.IgnoreGuiInset = false

	self:SetDragInstigator(container)

	return self
end

function SimpleDrag2D:GetMouseLocation(): Vector2
	local mouseLocation = UserInputService:GetMouseLocation()

	if not self.IgnoreGuiInset then
		mouseLocation -= GuiService:GetGuiInset()
	end

	return mouseLocation
end

function SimpleDrag2D:GetDraggingPosition(): Vector2
	local mouseLocation = self:GetMouseLocation()

	local absoluteContainerSize     = self.Container.AbsoluteSize
	local absoluteContainerPosition = self.Container.AbsolutePosition

	if self.XAxis then
		self.XScale = math.clamp(mouseLocation.X - absoluteContainerPosition.X, 0, absoluteContainerSize.X) / absoluteContainerSize.X
	end

	if self.YAxis then
		self.YScale = math.clamp(mouseLocation.Y - absoluteContainerPosition.Y, 0, absoluteContainerSize.Y) / absoluteContainerSize.Y
	end

	return Vector2.new(self.XScale, self.YScale)
end

function SimpleDrag2D:SetDragInstigator(instigator: GuiObject)
	local function onDragged()
		self:Drag()
	end

	local function onDragEnded()
		self:Release()
	end

	local function onDragStarted()
        onDragged()

		self.Connections[2] = onInput(UserInputService.TouchEnded, onDragEnded, Enum.UserInputType.Touch)
		self.Connections[1] = onInput(UserInputService.InputEnded, onDragEnded, Enum.UserInputType.MouseButton1)

		self.Connections[3] = onInput(UserInputService.TouchMoved,   onDragged, Enum.UserInputType.Touch)
		self.Connections[4] = onInput(UserInputService.InputChanged, onDragged, Enum.UserInputType.MouseMovement)
	end

	onInput(instigator.InputBegan, onDragStarted, Enum.UserInputType.Touch, Enum.UserInputState.Begin)
	onInput(instigator.InputBegan, onDragStarted, Enum.UserInputType.MouseButton1)
end

function SimpleDrag2D:SetIgnoreGuiInset(ignore: boolean)
    self.IgnoreGuiInset = ignore
end

function SimpleDrag2D:Drag()
    self.Dragging = true

    self.Dragged:Fire(self:GetDraggingPosition())
end

function SimpleDrag2D:Release()
	if self.Dragging then
		self.Dragging = false
	else
		return
	end

	for index = 1, #self.Connections do
		self.Connections[index]:Disconnect()
		self.Connections[index] = nil
	end

	self.Released:Fire()
end

function SimpleDrag2D:IsDragging(): boolean
    return self.Dragging
end



export type SimpleDrag2D = {
	Connections : {RBXScriptConnection},

	XAxis  : boolean,
	YAxis  : boolean,
	XScale : number,
	YScale : number,

    Dragging  : boolean,
	Dragged   : any,
	Released  : any,
	Container : GuiObject,

    IgnoreGuiInset : boolean,

    SetDragInstigator : (self: SimpleDrag2D, instigator: GuiObject) -> (),
    SetIgnoreGuiInset : (self: SimpleDrag2D, ignore: boolean) -> (),

    GetMouseLocation    : (self: SimpleDrag2D) -> Vector2,
	GetDraggingPosition : (self: SimpleDrag2D) -> Vector2,

    Drag    : (self: SimpleDrag2D) -> (),
    Release : (self: SimpleDrag2D) -> (),

    IsDragging : (self: SimpleDrag2D) -> boolean,
}



return SimpleDrag2D
