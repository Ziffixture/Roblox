--[[
Author     Ziffixture (74087102)
Date       12/14/2025 (MM/DD/YYYY)
Version    1.0.0

Grassroots placement system demo.
]]



type Movable = Model & {
	ClickDetector : ClickDetector,
}



local CollectionService = game:GetService("CollectionService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")


local Camera = workspace.CurrentCamera :: Camera
local Player = Players.LocalPlayer



-- Utility
--------------------------------------------------
local function getMousePosition3D(distance: number, parameters: RaycastParams?): Vector3?
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray           = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local result        = workspace:Raycast(ray.Origin, ray.Direction * distance, parameters)
	
	return result and result.Position
end

local function setModelTransparency(model: Model, transparency: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = transparency
		end
	end
end

local function setModelDoesPhysics(model: Model, doesPhysics: boolean)
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		
		descendant.Anchored   = doesPhysics
		descendant.CanCollide = doesPhysics
	end
end
--------------------------------------------------


-- Placement
--------------------------------------------------
local MOVABLE_TAG              = "Movable"
local MOVABLE_RAYCAST_DISTANCE = 50
local MOVABLE_PLACEMENT_BUTTON = Enum.UserInputType.MouseButton1 


local movables                      = {}
local movableFilter: RaycastParams? = nil 
local movableCurrent: Movable?      = nil
local movableConnection             = nil



local function setMovablesEnabled(enabled: boolean)
	local maxActivationDistance = enabled and 32 or 0
	
	for _, movable in CollectionService:GetTagged(MOVABLE_TAG) do
		movable.ClickDetector.MaxActivationDistance = maxActivationDistance
	end
end

local function setMovableSelected(movable: Movable, selected: boolean)
	setMovablesEnabled(not selected)
	setModelDoesPhysics(movable, not selected)
	setModelTransparency(movable, selected and 0.5 or 0)
end

local function createMovableFilter(movable: Movable): RaycastParams?
	local character = Player.Character
	if not character then
		return
	end
	
	local parameters = RaycastParams.new()
	parameters.FilterType                 = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { character, movable }
	
	return parameters
end

local function getNewMovableCFrame(offset: Vector3): CFrame?
	local mousePosition = getMousePosition3D(MOVABLE_RAYCAST_DISTANCE, movableFilter)
	if not mousePosition then
		return
	end

	local newPosition = mousePosition + offset
	local newCFrame   = CFrame.new(newPosition)
	
	return newCFrame
end

local function onMovableSelected(movable: Movable)
	if movableCurrent then
		return
	end
	
	setMovableSelected(movable, true)
	
	local size          = movable:GetExtentsSize()
	local size_y_offset = Vector3.yAxis * size.Y / 2
	
	local function updateMovablePosition()
		local newCFrame = getNewMovableCFrame(size_y_offset)
		if newCFrame then
			movable:PivotTo(newCFrame)
		end
	end
	
	movableFilter     = createMovableFilter(movable)
	movableCurrent    = movable
	movableConnection = RunService.PostSimulation:Connect(updateMovablePosition)
end

local function onMovablePlaced(movable: Movable)
	do
		local size          = movable:GetExtentsSize()
		local size_y_offset = Vector3.yAxis * size.Y / 2
		
		local finalCFrame = getNewMovableCFrame(size_y_offset)
		if finalCFrame then
			movable:PivotTo(finalCFrame)
		end
	end
	
	setMovableSelected(movable, false)
	
	movableFilter  = nil
	movableCurrent = nil
	
	movableConnection:Disconnect()
end

local function onTryPlaceMovable(input: InputObject, gameProcessedInput: boolean)
	if gameProcessedInput then
		return
	end
	
	if input.UserInputType ~= MOVABLE_PLACEMENT_BUTTON then
		return
	end
	
	if movableCurrent then
		onMovablePlaced(movableCurrent)
	end
end

local function initializeMovable(movable: Movable)
	movable.ClickDetector.MouseClick:Connect(function()
		onMovableSelected(movable)
	end)
end

local function initializeMovables()
	for _, movable in CollectionService:GetTagged(MOVABLE_TAG) do
		initializeMovable(movable :: Movable)
	end
	
	UserInputService.InputBegan:Connect(onTryPlaceMovable)
	CollectionService:GetInstanceAddedSignal("Movable"):Connect(initializeMovable)
end



initializeMovables()
--------------------------------------------------
