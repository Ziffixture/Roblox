--[[
Author     Ziffixture (74087102)
Date       06/15/2025 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")


local INPUT_MAP = {
	[Enum.KeyCode.A] = Vector3.new(-1, 0,  0),
	[Enum.KeyCode.S] = Vector3.new(0,  0,  1),
	[Enum.KeyCode.W] = Vector3.new(0,  0, -1),
	[Enum.KeyCode.D] = Vector3.new(1,  0,  0),
}


local Camera = workspace.CurrentCamera

local Character         = script.Parent
local Humanoid          = Character:FindFirstChildOfClass("Humanoid") :: Humanoid
local HumanoidRootPart  = Humanoid.RootPart :: BasePart
local RootRigAttachment = HumanoidRootPart:FindFirstChild("RootRigAttachment") :: Attachment

local LinearVelocity   = script:WaitForChild("LinearVelocity")
local AlignOrientation = script:WaitForChild("AlignOrientation")


local flyingConnection: RBXScriptConnection
local flying = false



local function updateFlight(deltaTime: number)
	local net = Vector3.zero

	for _, input in UserInputService:GetKeysPressed() :: {InputObject} do
		net += INPUT_MAP[input.KeyCode] or Vector3.zero
	end

	AlignOrientation.CFrame       = CFrame.lookAlong(HumanoidRootPart.Position, Camera.CFrame.LookVector)
	LinearVelocity.VectorVelocity = AlignOrientation.CFrame:VectorToWorldSpace(net * Humanoid.WalkSpeed ^ 1.25)
end

local function accomodateGroundTakeoffAsync()
	if Humanoid.FloorMaterial ~= Enum.Material.Air then
		Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		
		task.wait(0.1)
	end
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
		accomodateGroundTakeoffAsync()
		
		Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		flyingConnection = RunService.PostSimulation:Connect(updateFlight)
	else
		flyingConnection:Disconnect()

		Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	LinearVelocity.Enabled   = flying
	AlignOrientation.Enabled = flying
end



LinearVelocity.Attachment0   = RootRigAttachment
AlignOrientation.Attachment0 = RootRigAttachment

UserInputService.InputBegan:Connect(onInputBegan)
