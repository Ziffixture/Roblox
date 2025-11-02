--[[
Author     Ziffixture (74087102)
Date       10/12/2025 (MM/DD/YYYY)
Version    1.1.0
]]



local user_input_service = game:GetService("UserInputService")
local gui_service        = game:GetService("GuiService")


local utils   = _G.utils
local globals = _G.globals
local consts  = _G.consts
local enums   = _G.enums


local simple_drag_2d = {}
simple_drag_2d.__index = simple_drag_2d



local function on_input(event: RBXScriptSignal, callback: () -> (), input_type: Enum.UserInputType, input_state: Enum.UserInputState?): RBXScriptConnection
	return event:Connect(function(input: InputObject)
		if input_state and input.UserInputState ~= input_state then
			return
		end

		if input.UserInputType == input_type then
			callback()
		end
	end)
end


function simple_drag_2d.new(container: GuiObject, axes: Vector2): SimpleDrag2D?
	local self = setmetatable({}, simple_drag_2d) :: SimpleDrag2D

	self.connections = {}

	self.x_axis  = axes.X == 1
	self.y_axis  = axes.Y == 1
    self.x_scale = 0
    self.y_scale = 0

    self.dragging  = false
	self.dragged   = utils.signal.new()
	self.released  = utils.signal.new()
	self.container = container

    self:set_ignore_gui_inset(false)
	self:set_drag_instigator(container)

	return self
end

function simple_drag_2d:get_mouse_location(): Vector2
	local mouse_location = user_input_service:GetMouseLocation()

	if not self.ignore_gui_inset then
		mouse_location -= gui_service:GetGuiInset()
	end

	return mouse_location
end

function simple_drag_2d:get_dragging_position(): Vector2
	local mouse_location = self:get_mouse_location()

	local absolute_container_size     = self.container.AbsoluteSize
	local absolute_container_position = self.container.AbsolutePosition

	if self.x_axis then
		self.x_scale = math.clamp(mouse_location.X - absolute_container_position.X, 0, absolute_container_size.X) / absolute_container_size.X
	end

	if self.y_axis then
		self.y_scale = math.clamp(mouse_location.Y - absolute_container_position.Y, 0, absolute_container_size.Y) / absolute_container_size.Y
	end

	return Vector2.new(self.x_scale, self.y_scale)
end

function simple_drag_2d:set_drag_instigator(instigator: GuiObject)
	local function on_dragged()
		self:drag()
	end

	local function on_drag_ended()
		self:release()
	end

	local function on_drag_started()
        on_dragged()

		self.connections[2] = on_input(user_input_service.TouchEnded, on_drag_ended, Enum.UserInputType.Touch)
		self.connections[1] = on_input(user_input_service.InputEnded, on_drag_ended, Enum.UserInputType.MouseButton1)

		self.connections[3] = on_input(user_input_service.TouchMoved,   on_dragged, Enum.UserInputType.Touch)
		self.connections[4] = on_input(user_input_service.InputChanged, on_dragged, Enum.UserInputType.MouseMovement)
	end

	on_input(instigator.InputBegan, on_drag_started, Enum.UserInputType.Touch, Enum.UserInputState.Begin)
	on_input(instigator.InputBegan, on_drag_started, Enum.UserInputType.MouseButton1)
end

function simple_drag_2d:set_ignore_gui_inset(ignore: boolean)
    self.ignore_gui_inset = ignore
end

function simple_drag_2d:drag()
    self.dragging = true

    self.dragged:Fire(self:get_dragging_position())
end

function simple_drag_2d:release()
	if self.dragging then
		self.dragging = false
	else
		return
	end

	for index = 1, #self.connections do
		self.connections[index]:Disconnect()
		self.connections[index] = nil
	end

	self.released:Fire()
end

function simple_drag_2d:is_dragging(): boolean
    return self.dragging
end



export type SimpleDrag2D = {
	connections : {RBXScriptConnection},

	x_axis  : boolean,
	y_axis  : boolean,
	x_scale : number,
	y_scale : number,

    dragging  : boolean,
	dragged   : any,
	released  : any,
	container : GuiObject,

    ignore_gui_inset : boolean,

    set_drag_instigator   : (self: SimpleDrag2D, instigator: GuiObject) -> (),
    set_ignore_gui_inset  : (self: SimpleDrag2D, ignore: boolean) -> (),

    get_mouse_location    : (self: SimpleDrag2D) -> Vector2,
	get_dragging_position : (self: SimpleDrag2D) -> Vector2,

    drag    : (self: SimpleDrag2D) -> (),
    release : (self: SimpleDrag2D) -> (),

    is_dragging : (self: SimpleDrag2D) -> boolean,
}



return simple_drag_2d
