--[[
Author     Ziffix (74087102)
Date       23/10/2
Version    1.0.b

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
@param     number     timePosition       | The time position within the parabolic trajectory.
@param     Vector3    origin             | The origin of the parabolic trajectory.
@param     Vector3    initialVelocity    | The initial velocity outlining the parabolic trajectory.
@return    Vector3  

Calculates the position in the parabolic trajectory at a given time.
]]
local function getPositionAtTime(timePosition: number, origin: Vector3, initialVelocity: Vector3): Vector3
    return 0.5 * GRAVITY_ACCELERATION * timePosition ^ 2 + initialVelocity * timePosition + origin
end


--[[
@param     Instance    instance    | The instance to read the attribute from.
@param     string      name        | The name of the attribute to read.
@return    T?
@throws 

Wraps Instance:GetAttribute to raise an error if the attribute is not found.
]]
local function getAttribute<T>(instance: Instance, name: string): T?
    local value = instance:GetAttribute(name)
    if value == nil then
        error("Instance \"" .. instance.Name .. "\" missing attribute \"" .. name .. "\".")
    end
    
    return value :: T
end


--[[
@param     Vector3    otherPart    | The origin of the parabolic trajectory.
@return    void       

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
    if not health or health.Min <= 0 then
        return
    end

    local associatedPlayer = Players:GetPlayerFromCharacter(character)
    if not associatedPlayer or associatedPlayer ~= PLAYER then
        return
    end
	
    local marble = Marble.get(character)
    if not marble then
        return
    end
	
    local info = cannonInfo[cannon]

    playerInFlight = true
    marble:SetControlsEnabled(false)
    marble:SetPhysicsEnabled(false)
	
    local secondsElapsed = 0
    while secondsElapsed < info.FlightTime do
        character:PivotTo(CFrame.new(getPositionAtTime(secondsElapsed, info.LaunchOrigin.Position, info.InitialVelocity)))
		
        secondsElapsed += RunService.PostSimulation:Wait()
    end

    playerInFlight = false
    marble:SetControlsEnabled(true)
    marble:SetPhysicsEnabled(true)
end


--[[
@param     Model    cannon    | The cannon instance.
@return    void

Initializes the given cannon.
]]
local function initializeCannon(cannon: Model)
    local barrel = cannon:WaitForChild("Barrel")
    local trigger = cannon:WaitForChild("Trigger")
	
    local launchOrigin = barrel:WaitForChild("LaunchOrigin")
    local launchEnd = cannon:WaitForChild("LaunchEnd")
	
    local flightTime = getAttribute(cannon, "FlightTime")
    local freezeOnLanding = getAttribute(cannon, "FreezeOnLanding")
      
    local info = {
        Barrel             = barrel,
        Trigger            = trigger,
		
        LaunchOrigin       = launchOrigin,
        LaunchEnd          = launchEnd,
		
        FlightTime         = flightTime,
        FreezeOnLanding    = freezeOnLanding,
        InitialVelocity    = Vector3.zero,
    }
	
    cannonInfo[cannon] = info
	
    --[[
    After aligning the cannon with the initial velocity, the trajectory's starting point shifts, 
    altering the entire path. Consequently, we must recalculate both the trajectory and the 
    cannon's orientation. Fortunately, these adjustments converge quickly, requiring only a 
    small number of iterations.
    ]]
    if CANNON_ALIGNMENT_ITERATIONS <= 0 then
        error("At least one alignment needs to be performed.")
    end
	
    for _ = CANNON_ALIGNMENT_ITERATIONS, 1, -1 do
        local barrelPosition = barrel:GetPivot().Position
        local originPosition = launchOrigin.Position
        local initialVelocity = getInitialVelocity(originPosition, launchEnd.Position, flightTime)
		
        barrel:PivotTo(CFrame.lookAt(barrelPosition, originPosition + initialVelocity))
	
        info.InitialVelocity = initialVelocity

        task.wait()
    end
	
    trigger.Touched:Connect(function(otherPart)
        onTriggerTouched(cannon, otherPart)
    end)	
end


--[[
@return    void

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
	
    FlightTime         : number,
    FreezeOnLanding    : boolean,
    InitialVelocity    : Vector3,
}
