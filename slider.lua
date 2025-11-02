--[[
Author     Ziffixture (74087102)
Date       10/19/2025 (MM/DD/YYYY)
Version    1.1.9
]]



local tween_service = game:GetService("TweenService")
local players       = game:GetService("Players")


local utils   = _G.utils
local globals = _G.globals
local consts  = _G.consts
local enums   = _G.enums


local SLIDER_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quint)


local settings           = players.LocalPlayer.PlayerGui.Settings
local settings_container = settings.Container
local settings_prefabs   = settings_container.Prefabs

local slider = {}
slider.__index = slider



local function normalize(value: number, min: number, max: number): number
	return math.clamp((value - min) / (max - min), 0, 1)
end


function slider.new(): Slider
    local self = setmetatable({}, slider) :: Slider

    local raw   = settings_prefabs.Pages.Slider:Clone() :: RawSlider
    raw.Visible = true

    local input = raw.Input.Value
    local bar   = raw.Bar

    self.raw   = raw
    self.input = input

    self.drag     = utils.simple_drag_2d.new(bar, Vector2.xAxis)
    self.range    = nil
    self.value    = nil
    self.enabled  = false

    self.callback         = nil
    self.drag_callback    = nil
    self.release_callback = nil

    self.drag:set_drag_instigator(bar.Fill.Marker.Slider)

    self.drag.dragged:Connect(function(position: UDim2)
        if self.enabled then
            self:on_dragged(position)
        end
    end)

    self.drag.released:Connect(function()
        if self.release_callback then
            self.release_callback()
        end
    end)

    input:GetPropertyChangedSignal("Text"):Connect(function()
        if self.enabled then
            self:on_input_changed()
        end
    end)

    input.FocusLost:Connect(function(enter_pressed: boolean)
        if not self.enabled then
            return
        end

        if enter_pressed then
            self:on_input_set()
        end
    end)

    return self
end


function slider:set_name(name: string)
    self.raw.Name       = name
    self.raw.Title.Text = string.upper(name)
end

function slider:set_range(min: number, max: number)
    self.range = NumberRange.new(min, max)
end

function slider:set_value(value: number, ignore: boolean?)
    if not self.enabled then
        return
    end

    if not self:is_range_set() then
        return
    end

    if self.value == value then
        return
    end

    local new_value = math.clamp(value, self.range.Min, self.range.Max)
    local new_size  = UDim2.fromScale(normalize(new_value, self.range.Min, self.range.Max), 1)
    local new_text  = tostring(math.floor(new_value))

    if self:is_dragging() then
        self.raw.Bar.Fill.Size = new_size
    else
        tween_service:Create(self.raw.Bar.Fill, SLIDER_TWEEN_INFO, { Size = new_size }):Play()
    end

    self.value                   = new_value
    self.raw.Input.Value.Text = new_text

    if self.callback and not ignore then
        self.callback(self.value)
    end
end

function slider:set_callback(callback: (number) -> ())
    self.callback = callback
end

function slider:set_drag_callback(callback: (number) -> ())
    self.drag_callback = callback
end

function slider:set_release_callback(callback: () -> ())
    self.release_callback = callback
end

function slider:set_parent(parent: Instance)
    self.raw.Parent = parent
end

function slider:set_enabled(enabled: boolean)
    self.enabled = enabled

    if not enabled then
        self:release()
    end
end

function slider:on_dragged(position: Vector2)
    if not self.enabled then
        return
    end

    if not self:is_range_set() then
        return
    end

    self:set_value(math.lerp(
        self.range.Min,
        self.range.Max,
        position.X
    ))

    if self.drag_callback then
        self.drag_callback(self.value)
    end
end

function slider:on_input_set()
    if not self.enabled then
        return
    end

    local value = tonumber(self.input.Text) or self.value

    self:set_value(value)
end

function slider:on_input_changed()
    if self.enabled then
        self.input.Text = string.gsub(self.input.Text, "%D+", "")
    end
end

function slider:is_range_set(): boolean
    local is_set = self.range ~= nil
    if not is_set then
        warn("Failed to set value; no defined range.")
    end

    return is_set
end

function slider:is_dragging(): boolean
    return self.drag:is_dragging()
end

function slider:release()
    self.drag:release()
end



export type RawSliderInput = ImageLabel & {
    Value : TextBox,
}

export type RawSlider = Frame & {
    Title : TextLabel,
    Input : RawSliderInput,

    Bar : Frame & {
        Fill : Frame & {
            Glow : ImageLabel,

            Marker : Frame & {
                Slider : ImageButton,
            },
        },
    },
}

export type Slider =  {
    raw   : RawSlider,
    input : RawSliderInput,

    drag     : any,
    range    : NumberRange,
    value    : number,
    enabled  : boolean,

    callback         : (number) -> (),
    drag_callback    : (number) -> (),
    release_callback : () -> (),

    set_name             : (self: Slider, name: string) -> (),
    set_range            : (self: Slider, min: number, max: number) -> (),
    set_value            : (self: Slider, value: number, ignore: boolean?) -> (),
    set_callback         : (self: Slider, callback: (number) -> ()) -> (),
    set_drag_callback    : (self: Slider, callback: (number) -> ()) -> (),
    set_release_callback : (self: Slider, callback: () -> ()) -> (),
    set_parent           : (self: Slider, parent: Instance) -> (),
    set_enabled          : (self: Slider, enabled: boolean) -> (),

    on_dragged       : (self: Slider, position: Vector2) -> (),
    on_input_set     : (self: Slider) -> (),
    on_input_changed : (self: Slider) -> (),

    is_range_set : (self: Slider) -> boolean,
    is_dragging  : (self: Slider) -> boolean,

    release : (self: Slider) -> (),
}



return slider
