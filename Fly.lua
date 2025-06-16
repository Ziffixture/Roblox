--[[
Author     Ziffixture (74087102)
Date       06/15/2025 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")


local GRAVITY = Vector3.yAxis * workspace.Gravity
local FORCE   = 400
local DRAG    = 2


local Character         = script.Parent
local Humanoid          = Character:FindFirstChildOfClass("Humanoid") :: Humanoid
local HumanoidRootPart  = Humanoid.RootPart :: BasePart
local RootRigAttachment = HumanoidRootPart:FindFirstChild("RootRigAttachment") :: Attachment

local VectorForce      = script:WaitForChild("VectorForce")
local AlignOrientation = script:WaitForChild("AlignOrientation")


local flyingConnection: RBXScriptConnection
local flying = false



local function updateFlight(deltaTime: number)
	local mass = HumanoidRootPart.AssemblyMass
	
	VectorForce.Force = mass * GRAVITY
	
	local velocity = HumanoidRootPart.AssemblyLinearVelocity
	if velocity == Vector3.zero then
		return
	end
	
	local push = Humanoid.MoveDirection * FORCE * mass
	local drag = -velocity.Unit * velocity.Magnitude ^ 1.2 * DRAG * mass
	
	VectorForce.Force += push + drag
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	
	if input.KeyCode ~= Enum.KeyCode.F then
		return
	end
	
	flying = not flying
	
	if flying then
		Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		
		flyingConnection = RunService.PostSimulation:Connect(updateFlight)
	else
		flyingConnection:Disconnect()
		
		Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	
	VectorForce.Enabled      = flying
	AlignOrientation.Enabled = flying
end



VectorForce.Attachment0      = RootRigAttachment
AlignOrientation.Attachment0 = RootRigAttachment

UserInputService.InputBegan:Connect(onInputBegan)
