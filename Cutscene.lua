--!strict
type Cutscene = {
	Start    : CFrame,
	Sequence : {Tween},
}



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")


local Camera   = workspace.CurrentCamera :: Camera
local Cutscene = ReplicatedStorage.Cutscene


const CUTSCENE_INFO = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) 



local function onLivingPlayerTouched(part: BasePart, callback: (Player) -> ()): RBXScriptConnection
	return part.Touched:Connect(function(otherPart: BasePart)
		local character = otherPart.Parent :: Model

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health == 0 then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if player then
			callback(player)
		end
	end)
end

local function processCutscene(): Cutscene
	local sequence = Cutscene.Sequence
	local count    = #sequence:GetChildren()
	local tweens   = table.create(count - 1) :: {Tween}

	for index = 2, count do
		local point = sequence[index]
		local tween = TweenService:Create(Camera, CUTSCENE_INFO, { CFrame = point.CFrame })

		table.insert(tweens, tween)
	end

	return {
		Start    = sequence[1].CFrame,
		Sequence = tweens,
	}
end

local function runCutsceneAsync(cutscene: Cutscene)
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame     = cutscene.Start

	for _, tween in cutscene.Sequence do
		tween:Play()
		tween.Completed:Wait()
	end

	Camera.CameraType = Enum.CameraType.Custom
end

local function initializeCutsceneAsync()
	local trigger = Cutscene.Trigger.Value
	if not trigger then
		trigger = Cutscene.Trigger.Changed:Wait()
	end

	local cutscene = processCutscene()

	onLivingPlayerTouched(trigger :: BasePart, function()
		runCutsceneAsync(cutscene)
	end)
end



initializeCutsceneAsync()
