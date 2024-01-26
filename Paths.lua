--[[
Author(s)    Ziffixture
Date         23/12/20
Version      1.4.0b
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Types         = ReplicatedStorage.Types
local ObjectTypes   = require(Types.ObjectTypes)
local InstanceTypes = require(Types.InstanceTypes)

local DevKit            = require(ReplicatedStorage.DevKit)
local BootstrapChildren = DevKit.Functions.BootstrapChildren


local Paths            = {}
Paths.TRANSITION_RULES = {} :: TransitionRuleMap



--[[
@param     InstanceTypes.Path      paths    | The path from which to derive its connecting paths.
@return    {InstanceTypes.Path}

A helper function that retrieves the connecting paths within the given path instance.
]]
local function getConnectedPaths(path: InstanceTypes.Path): {InstanceTypes.Path}
	local connectedPaths: any = path.Connections:GetChildren()
	local result = {}

	for index, child in connectedPaths :: {ObjectValue} do
		result[index] = child.Value
	end

	return result :: {InstanceTypes.Path}
end



--[[
@param     {InstanceTypes.Path}    paths    | The paths whose waypoints to colourize.
@return    void

A helper function that applies a BrickColor to each waypoint of the given paths.
]]
local function colourWaypointsOfPaths(paths: {InstanceTypes.Path}, colour: BrickColor)
	for _, path in paths do
		for _, waypoint: BasePart in path.Waypoints:GetChildren() :: any do
			waypoint.BrickColor = colour
		end
	end
end


--[[
@param     InstanceTypes.PathGraph             graph    | A physical path graph.
@return    ObjectTypes.CategorizedPathGraph

Isolates the beginning, junction, and end paths in the given graph.
]]
function Paths.CategorizeGraph(graph: InstanceTypes.PathGraph): ObjectTypes.CategorizedPathGraph
	local paths: {InstanceTypes.Path} = graph:GetChildren() :: any

	local pathBeginnings : {InstanceTypes.Path} = {} -- All paths that have no incoming connections.
	local pathJunctions  : {InstanceTypes.Path} = {} -- All paths that have one or more incoming and outgoing connections.
	local pathEndings    : {InstanceTypes.Path} = {} -- All paths that have no outgoing connections.

    --[[
    As we process the connected paths of each path, we record what paths are connected
    to later isolate which paths aren't (aka. path beginnings)
    ]]
	local hasIncomingConnections: {[InstanceTypes.Path]: true} = {}

	for _, path in paths do
		local connectedPaths: {ObjectValue} = path.Connections:GetChildren() :: any

		if #connectedPaths >= 1 then
			-- One or more outgoing connections.
			table.insert(pathJunctions, path)
		else
			-- No outgoing connections.
			table.insert(pathEndings, path)
		end

		-- Record connected paths.
		for _, connectedPath in connectedPaths do
			hasIncomingConnections[connectedPath.Value :: InstanceTypes.Path] = true
		end
	end

    -- Re-visit paths that have outgoing connections.
    for index = #pathJunctions, 1, -1 do
        local path = pathJunctions[index]

        if not hasIncomingConnections[path] then
            -- No incoming connections.
            table.insert(pathBeginnings, path)
            table.remove(pathJunctions, index)
        end
    end

	return {
		Beginnings = pathBeginnings,
		Junctions  = pathJunctions,
		Endings    = pathEndings,

		Instance   = graph,
	}
end


--[[
@param    BasePart    part0     | The part which Attachment0 is assigned to.
@param    BasePart    part1     | The part which Attachment1 is assigned to.
@param    Instance    parent    | The instance to which the Beam is parented.

A helper function used to expose the relationships between the waypoints of paths.
For example: the end node of one path to the start node of another.
]]
local function linkWithBeam(partA: BasePart, partB: BasePart, parent: Instance): Beam
	local attachment0 = Instance.new("Attachment")
	local attachment1 = Instance.new("Attachment")

	attachment0.Parent = partA
	attachment1.Parent = partB

	local beam = Instance.new("Beam")

	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Parent      = parent

    return beam
end


--[[
@param    InstanceTypes.Path    path               | The path to trace.
@param    {}                    pathsVisited       | The paths that have already been traced.
@param    BasePart?             lastEndWaypoint    | The last waypoint of the previous path.

A recursive helper function that, with Beams, traces the waypoints of each path connected to the given path.
]]
local function tracePath(path: InstanceTypes.Path, pathsVisited: {}, lastEndWaypoint: BasePart?)
	local waypoints = Paths.GetWaypoints(path)

    --[[
	Connecting a single path's waypoints is different from connecting two paths. To achieve this,
	the last waypoint of a path is recorded so it may be linked with the first of another.
	]]
	if lastEndWaypoint then
		local beam = linkWithBeam(lastEndWaypoint :: BasePart, waypoints[1], path)
		beam.Name  = "Beam0"
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	end

	--[[
	Ensure we don't trace a path that's already been traced. This check is done second
	to allow for the end waypoint of a newly visited path to connect with the start waypoint
	of an already visited path.
	]]
	if not pathsVisited[path] then
		pathsVisited[path] = true
	else
		return
	end

	--[[
	Initialize the last known waypoint of this path to be the first waypoint of the path. This is done
	because the following loop walks the waypoints in pairs, and we might not get the chance to
	do so with paths containing only one waypoint.
	]]
	lastEndWaypoint = waypoints[1]

	-- Walk the waypoints in pairs, connect a beam between the two, and update the last known waypoint.
	for index = 1, #waypoints - 1 do
		local currentWaypoint = waypoints[index]
		local nextWaypoint    = waypoints[index + 1]

		local beam = linkWithBeam(currentWaypoint, nextWaypoint, path)
		beam.Name  = `Beam{index}`
		beam.Color = ColorSequence.new(currentWaypoint.Color)

		lastEndWaypoint = nextWaypoint
	end

	for _, connectedPath: ObjectValue in path.Connections:GetChildren() :: any do
		tracePath(connectedPath.Value :: any, pathsVisited, lastEndWaypoint)
    end
end


--[[
@param     ObjectTypes.CategorizedPathGraph     categorizedGraph    | A categorized path graph.
@return    void

Visually debugs the relationship between waypoints and paths.
]]
function Paths.Debug(categorizedGraph: ObjectTypes.CategorizedPathGraph)
	colourWaypointsOfPaths(categorizedGraph.Beginnings, BrickColor.Green())
	colourWaypointsOfPaths(categorizedGraph.Junctions, BrickColor.Yellow())
	colourWaypointsOfPaths(categorizedGraph.Endings, BrickColor.Red())

	local pathsVisited = {}

	for _, path in categorizedGraph.Beginnings do
		tracePath(path, pathsVisited, nil)
	end
end


--[[
@param     InstanceTypes.PathGraph    graph    | A physical path graph.
@return    void

Removes beamwork and colouring from waypoints.
]]
function Paths.UndoDebug(graph: InstanceTypes.PathGraph): ObjectTypes.CategorizedPathGraph
	local paths: {InstanceTypes.Path} = graph:GetChildren() :: any

	for _, path in paths do
		-- Destroy beams within path.
		for _, child in path:GetChildren() do
			if child.ClassName == "Beam" then
				child:Destroy()
			end
		end

		-- Destroy attachments within waypoints and reset their colour.
		for _, waypoint: BasePart in path.Waypoints:GetChildren() :: any do
			for _, child in waypoint:GetChildren() do
				if child.ClassName == "Attachment" then
					child:Destroy()
				end
			end

			waypoint.BrickColor = BrickColor.Gray()
		end
	end
end


--[[
@param     InstanceTypes.Path?    path     | The path whose connected paths will be considered.
@param     InstanceTypes.Enemy    enemy    | The enemy who's walking that path.
@return    InstanceTypes.Path?

A helper function that selects the next path from a given path based on the given
enemy's transition rule.
]]
local function getNextPath(path: InstanceTypes.Path?, enemy: InstanceTypes.Enemy): InstanceTypes.Path?
    if not path then
        return
    end

    local connectedPaths = getConnectedPaths(path)
    local transitionRule = Paths.GetTransitionRule(enemy)

    return transitionRule(connectedPaths, enemy)
end

--[[
@param     InstanceTypes.Path     startPath    | The path at which the enemy begins walking.
@param     InstanceTypes.Enemy    enemy        | The enemy walking the path of the iterator.
@return    () -> BasePart?

Makes an iterator that traverses over waypoints of the path graph rooted at startPath. The given enemy subscribes to a
transition rule, which is queried every iteration and decides how the iterator moves onto the next path.
]]
function Paths.MakeIterator(startPath: InstanceTypes.Path, enemy: InstanceTypes.Enemy): () -> BasePart?
    local currentPath = startPath
    local currentWaypoints = Paths.GetWaypoints(currentPath)
    local currentWaypointIndex = 0

    return function()
        currentWaypointIndex += 1

        -- Waypoints of last path have been exhausted
        if not currentWaypoints[currentWaypointIndex] then
            currentPath = getNextPath(currentPath, enemy)

            -- No available paths to keep traversing.
            if not currentPath then
                return nil
            end

            currentWaypoints = Paths.GetWaypoints(currentPath)
            currentWaypointIndex = 1
        end

        return currentWaypoints[currentWaypointIndex]
    end
end


--[[
@param     InstanceTypes.Path    path    | The path from which to derive its waypoints.
@return    {BasePart}

Bypasses Instance:GetChildren's insertion order by reading the path's numbered waypoints.
]]
function Paths.GetWaypoints(path: InstanceTypes.Path): {BasePart}
	local waypoints = path.Waypoints
	local result = {}

	for index = 1, #waypoints:GetChildren() do
		table.insert(result, waypoints[index])
	end

	return result :: {InstanceTypes.Path}
end


--[[
@param     InstanceTypes.Enemy           enemy    | The enemy to read the transition rule from.
@return    ObjectTypes.TransitionRule
@throws

Reads from the StringValue within the enemy instance that specifies the transition rule it subscribes to.
Throws an error if the subscribed transition rule does not exist.
]]
function Paths.GetTransitionRule(enemy: InstanceTypes.Enemy): ObjectTypes.TransitionRule
	local targetRule     = enemy.TransitionRule.Value
	local transitionRule = Paths.TRANSITION_RULES[targetRule]

	if not transitionRule then
		error(`Could not find a transition rule called "{targetRule}".`)
	end

	return transitionRule
end



BootstrapChildren(script, Paths.TRANSITION_RULES, function(transitionRule: ModuleScript)
	local capitializedWords = {}

	for word in string.gmatch(transitionRule.Name, "%u%U*") do
		table.insert(capitializedWords, string.upper(word))
	end

	return table.concat(capitializedWords, "_"), require(transitionRule)
end)


type TransitionRuleMap = {
	[string]: ObjectTypes.TransitionRule
}


return table.freeze(Paths)
