--[[
Author     Ziffix (74087102)
Date       06/09/2025 (MM/DD/YYYY)
Version    1.0.1
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Vendor       = ReplicatedStorage:WaitForChild("Vendor")
local SimpleDrag2D = require(Vendor:WaitForChild("SimpleDrag2D"))

local ColorPickerFeature    = ReplicatedStorage:WaitForChild("ColorPicker")
local ColorPickerController = require(ColorPickerFeature:WaitForChild("Controller"))
local ColorPickerColor      = ColorPickerFeature:WaitForChild("Color")

local Gui       = script.Parent
local Container = Gui:WaitForChild("Container")

local Display    = Container:WaitForChild("Display")
local Selector   = Container:WaitForChild("Selector")
local Adjustment = Container:WaitForChild("Adjustment")
local Cancel     = Container:WaitForChild("Cancel")
local Save       = Container:WaitForChild("Save")


local WHITE = Color3.new(1, 1, 1)



local function getSelectedColor(): Color3
	local position = Selector.Pipette.Position
	
	return Color3.fromHSV(position.X.Scale, 1, 1)
end

local function getAdjustedColor(): Color3
	local selectedPosition = Selector.Pipette.Position
	local adjustedPosition = Adjustment.Pipette.Position
	
	return Color3.fromHSV(
		selectedPosition.X.Scale,
		adjustedPosition.X.Scale,
		1 - adjustedPosition.Y.Scale
	)
end

local function renderColor(color: Color3)
	Display.BackgroundColor3 = color
	
	Display.Colors.BrickColor.Text  = BrickColor.new(color).Name
	Display.Colors.Hexadecimal.Text = `#{string.upper(color:ToHex())}`
	
	ColorPickerColor.Value = color
end

local function renderSourceColor()
	local color = getSelectedColor()
	
	Selector.Pipette.BackgroundColor3 = color
	Adjustment.UIGradient.Color       = ColorSequence.new(WHITE, color)
end

local function renderColorFromPipettes()
	local color = getAdjustedColor()
	
	for _, input in Display.Colors.RGB:GetChildren() do
		if input:IsA("TextBox") then
			input.Text = math.floor(255 * color[input.Name]) -- Shh. This better.
		end
	end
	
	renderColor(color)
end

local function renderColorFromInputs()
	local color = Color3.fromRGB(
		Display.Colors.RGB.R.Text,
		Display.Colors.RGB.G.Text,
		Display.Colors.RGB.B.Text
	)

	local hue, saturation, value = color:ToHSV()
	
	Selector.Pipette.Position   = UDim2.fromScale(hue, 0.5)
	Adjustment.Pipette.Position = UDim2.fromScale(saturation, 1 - value)
	
	renderColor(color)
	renderSourceColor()
end

local function onSelectorDragged()
	renderColorFromPipettes()
	renderSourceColor()
end

local function handleInputUpdates()
	for _, input in Display.Colors.RGB:GetChildren() do
		if not input:IsA("TextBox") then
			continue
		end
		
		local previousInput = input.Text
		
		input:GetPropertyChangedSignal("Text"):Connect(function()
			input.Text = string.gsub(input.Text, "%D", "")
			input.Text = string.sub(input.Text, 1, 3)
			
			local number = tonumber(input.Text)
			if number then
				input.Text = math.clamp(number, 0, 255)
			end
		end)
		
		input.FocusLost:Connect(function()
			if input.Text == "" then
				input.Text = previousInput
				
				return
			end
			
			previousInput = input.Text
			
			renderColorFromInputs()
		end)
	end
end

local function initializePipette(container: PipetteContainer, axes: Vector2, onDrag: () -> ())
	local pipette     = container:WaitForChild("Pipette") :: Pipette
	local pipetteDrag = SimpleDrag2D.new(pipette, container, axes)

	pipetteDrag.Dragged:Connect(onDrag)
end

local function onColorPrompted(initialColor: Color3, position: UDim2)
	Container.Position = position or Container.Position
	Container.Visible  = true
	
	if initialColor then
		renderColor(initialColor)
	end
end

local function onActionColor(action: GuiButton, save: boolean)
	action.Activated:Connect(function()
		Container.Visible = false
		
		ColorPickerController.actionColor(save)
	end)
end



onActionColor(Save, true)
onActionColor(Cancel, false)

handleInputUpdates()

initializePipette(Selector, Vector2.xAxis, onSelectorDragged)
initializePipette(Adjustment, Vector2.new(1, 1), renderColorFromPipettes)

ColorPickerController.ColorPrompted:Connect(onColorPrompted)



type Pipette = Frame & {
	UIDragDetector : UIDragDetector,
}

type PipetteContainer = GuiObject & {
	Pipette : Pipette,
}
