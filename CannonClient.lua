--[[
Author:     Ziffix (74087102)
Date:       23/09/29
Version:    1.0.0 (Stable)

Notes:

Implements cannon physics using projectile motion modelling with manual CFrame-ing,
https://devforum.roblox.com/t/modeling-a-projectiles-motion/176677
]]



local CollectionService              = game:GetService("CollectionService")
local ReplicatedStorage              = game:GetService("ReplicatedStorage")
local RunService                     = game:GetService("RunService")
local Players                        = game:GetService("Players")

local Marble                         = require(ReplicatedStorage:WaitForChild("Classes"):WaitForChild("Marble"))

local GRAVITY_ACCELERATION           = Vector3.yAxis * -workspace.Gravity

local CANNON_ALIGNMENT_ITERATIONS    = 2
local CANNON_TAG                     = "Cannon"

local PLAYER                         = Players.LocalPlayer

local cannonInfo                     = {} :: {[Model]: CannonInfo}
local playerInFlight                 = false



--[[
@param     origin         Vector3  | The origin of the parabolic trajectory.
@param     destination    Vector3  | The end of the parabolic trajectory.
@param     duration       number   | The time it takes to travel the parabolic trajectory.
@return                   Vector3  

Calculates the initial velocity required to travel a parabolic trajectory.
]]
local function getInitialVelocity(origin: Vector3, destination: Vector3, duration: number): Vector3
    return (destination - origin - 0.5 * GRAVITY_ACCELERATION * duration ^ 2) / duration
end


--[[
@param     timePosition       number   | The time position within the parabolic trajectory.
@param     origin             Vector3  | The origin of the parabolic trajectory.
@param     initialVelocity    Vector3  | The initial velocity outlining the parabolic trajectory.
@return                       Vector3  

Calculates the position in the parabolic trajectory at a given time.
]]
local function getPositionAtTime(timePosition: number, origin: Vector3, initialVelocity: Vector3): Vector3
    return 0.5 * GRAVITY_ACCELERATION * timePosition ^ 2 + initialVelocity * timePosition + origin
end


--[[
@param     otherPart    Vector3  | The origin of the parabolic trajectory.
@return                 void       

Filters for a collision with the LocalPlayer's marble instance and ejects
the player out of the cannon.
]]
local function onTriggerTouched(cannon: Model, otherPart: BasePart)	
    if playerInFlight then
        return
    end
	
    local character = otherPart:FindFirstAncestorOfClass("Model")
    if not character then
        return
    end
	
    local health = character:GetAttribute("Health")
    if not health or health <= 0 then
        return
    end

    local associatedPlayer = Players:GetPlayerFromCharacter(character)
    if not associatedPlayer or associatedPlayer ~= PLAYER then
        return
    end
	
    local marble = Marble.get(character)
    if not marble then
        --[[
        Ziffix 23/09/29: It's a known issue for this to occur often. Might as well contribute to the
        debug epidemic.
        ]]
        warn(debug.traceback("Could not retrieve " .. player.Name .. "'s marble."))
		
        return
    end
	
    local info = cannonInfo[cannon]

    playerInFlight = true
    marble:SetControlsEnabled(false)
    marble:SetPhysicsEnabled(false)
	
    local secondsElapsed = 0
    while secondsElapsed < info.TravelTime do
        marble:Teleport(CFrame.new(getPositionAtTime(secondsElapsed, info.LaunchOrigin.Position, info.InitialVelocity)))
		
        secondsElapsed += RunService.RenderStepped:Wait()
    end

    playerInFlight = false
    marble:SetControlsEnabled(true)
    marble:SetPhysicsEnabled(true)
end


--[[
@param     cannon    Model  | The cannon instance
@return              void

Initializes the given cannon.
]]
local function initializeCannon(cannon: Model)
    local barrel = cannon:WaitForChild("Barrel")
    local trigger = cannon:WaitForChild("Trigger")
	
    local launchOrigin = barrel:WaitForChild("LaunchOrigin")
    local launchEnd = cannon:WaitForChild("LaunchEnd")
	
    local travelTime = cannon:GetAttribute("TravelTime")
    if not travelTime then
        warn("Cannon \"" .. cannon.Name .. "\" does not have a set travel time.")
		
        return
    end
      
    local info = {
        Barrel             = barrel,
        Trigger            = trigger,
		
        LaunchOrigin       = launchOrigin,
        LaunchEnd          = launchEnd,
		
        TravelTime         = travelTime,
        InitialVelocity    = Vector3.zero,
    }
	
    cannonInfo[cannon] = info
	
    --[[
    After aligning the cannon with the initial velocity, the trajectory's starting point shifts, 
    altering the entire path. Consequently, we must recalculate both the trajectory and the 
    cannon's orientation. Fortunately, these adjustments converge quickly, requiring only a few iterations.
    ]]
    if CANNON_ALIGNMENT_ITERATIONS <= 0 then
        error("At least one alignment needs to be performed.")
    end
	
    for _ = CANNON_ALIGNMENT_ITERATIONS, 1, -1 do
        local barrelPosition = barrel:GetPivot().Position
        local originPosition = launchOrigin.Position
        local initialVelocity = getInitialVelocity(originPosition, launchEnd.Position, travelTime)
		
        barrel:PivotTo(CFrame.lookAt(barrelPosition, originPosition + initialVelocity))
	
        info.InitialVelocity = initialVelocity

        task.wait()
    end
	
    trigger.Touched:Connect(function(otherPart)
        onTriggerTouched(cannon, otherPart)
    end)	
end


--[[
@return              void

Begins an initialization process for all cannons that are and are to be.
]]
local function initializeCannons()
    for _, cannon in CollectionService:GetTagged(CANNON_TAG) do
        task.spawn(initializeCannon, cannon)
    end
	
    CollectionService:GetInstanceAddedSignal(CANNON_TAG):Connect(function(cannon)
        task.spawn(initializeCannon, cannon)
    end)
end



initializeCannons()

type CannonInfo = {
    Barrel             : Model,
    Trigger            : BasePart,
	
    LaunchOrigin       : BasePart,
    LaunchEnd          : BasePart,
	
    TravelTime         : number,
    InitialVelocity    : Vector3,
}
