--!strict
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")


local Parent        = script.Parent
local Dragging      = Parent:WaitForChild("Dragging")
local Configuration = Parent:WaitForChild("Configuration")



local function onAllChildren<T>(parent: Instance, callback: (T, ...any) -> (), ...)
	for _, child in parent:GetChildren() do
		callback(child :: any, ...)
	end
end

local function onMouseButton1(inputEvent: RBXScriptSignal, callback: () -> ()): RBXScriptConnection
	return inputEvent:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			callback()
		end
	end)
end

local function getMousePosition(): UDim2
	local mouseLocation = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	
	return UDim2.fromOffset(mouseLocation.X, mouseLocation.Y)
end

local function getClosestHotbarSlot(dragging: GuiObject, hotbarSlots): GuiObject?
	local closestSlot     = nil
	local closestDistance = math.huge

	for _, slot in hotbarSlots do
		if slot:GetAttribute("Occupied") then
			continue
		end
		
		local distance = (slot.AbsolutePosition - dragging.AbsolutePosition).Magnitude
		if distance > Configuration.AcceptanceRadius.Value then
			continue
		end

		if closestDistance > distance then
			closestDistance = distance

			closestSlot = slot
		end
	end

	return closestSlot
end

local function setToHotbarSlot(dragging: GuiObject, slot: GuiObject)
	slot:SetAttribute("Occupied", true)
	
	dragging.AnchorPoint = Vector2.zero
	dragging.Position    = UDim2.new()
	dragging.Size        = UDim2.fromScale(1, 1)
	dragging.Parent      = slot
end

local function createDraggableCopy(guiObject: GuiObject): GuiObject
	local draggable    = guiObject:Clone()
	local absoluteSize = guiObject.AbsoluteSize / 2
	
	draggable.Size        = UDim2.fromOffset(absoluteSize.X, absoluteSize.Y)
	draggable.AnchorPoint = Vector2.one * 0.5
	draggable.Parent      = Dragging
	
	return draggable
end

local function tryInitializeSlot(slot: GuiObject, hotbarSlots)
	if slot.ClassName ~= "ImageLabel" then
		return
	end

	local imageLabel = slot:WaitForChild("ImageLabel") :: ImageLabel
	
	local dragConnection
	local dragCopy
	
	onMouseButton1(imageLabel.InputBegan, function()
		dragCopy = createDraggableCopy(imageLabel)

		dragConnection = UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				dragCopy.Position = getMousePosition()
			end
		end)
	end)
	
	onMouseButton1(imageLabel.InputEnded, function()
		dragConnection:Disconnect()

		local closestSlot = getClosestHotbarSlot(dragCopy, hotbarSlots)
		if closestSlot then
			setToHotbarSlot(dragCopy, closestSlot)
		else
			dragCopy:Destroy()
		end
	end)
end

local function tryRegisterHotbarSlot(slot: GuiObject, hotbarSlots)
	if slot:IsA("GuiObject") then
		table.insert(hotbarSlots, slot)
	end
end

local function tryInitializeSelection(selection: GuiObject)
	if selection.ClassName ~= "Frame" then
		return
	end
	
	local container = selection:WaitForChild("Container") :: GuiObject
	local hotbar    = selection:WaitForChild("Hotbar") :: GuiObject
	local units     = container:WaitForChild("Units") :: GuiObject
	
	local hotbarSlots = {}
	
	onAllChildren(hotbar, tryRegisterHotbarSlot, hotbarSlots)
	onAllChildren(units, tryInitializeSlot, hotbarSlots)
end



onAllChildren(Parent, tryInitializeSelection)
