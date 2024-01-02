--[[
Author     Ziffix
Version    1.4.0 (Untested)
Date	   24/01/01
]]



local GroupService = game:GetService("GroupService")
local HttpService  = game:GetService("HttpService")
local Players      = game:GetService("Players")


local Configuration = require(script.Configuration)

local API_AUTHORIZATION_TOKEN = Configuration.API_AUTHORIZATION_TOKEN
local API_ENDPOINT            = Configuration.API_ENDPOINT

local GROUP_ID       = Configuration.GROUP_ID
local GROUP_RANK_CAP = Configuration.GROUP_RANK_CAP

local GROUP_RANK_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve %s's current rank; %s"
local GROUP_ROLE_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve group data; %s"
local GROUP_ROLE_UPDATE_FAILURE	   = "A problem occurred while trying to update %s's role to \"%s\"; %s"

local groupRolesCache = nil
local userRankCache   = {}



--[[
@param     any        condition    | The result of the condition.
@param     string     message      | The error message to be raised.
@param     number?    level = 2    | The level at which to raise the error.
@return    void

Implements assert with error's level argument.
]]
local function _assertLevel(condition: any, message: string, level: number?)
    if condition == nil then 
        error("Argument #1 missing or nil.", 2)
    end

    if message == nil then 
        error("Argument #2 missing or nil.", 2)
    end

    -- Lifts the error out of this function.
    level = (level or 1) + 1

    if condition then
        return condition
    end

    error(message, level)
end


--[[
@param     Player    player    | The Player instance of the newly connected client.
@return    number?

Attempts to make an entry in the userRankCache cache under the given Player instance.
]]
local function initializeRankInCache(player: Player): number?
    assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
	
    local success, response = pcall(function()
        return player:GetRankInGroup(GROUP_ID)
    end)
  
    if not success then
        warn(GROUP_RANK_RETRIEVAL_FAILURE:format(player.Name, response))
    
        return
    end
  
    userRankCache[player] = response
	
    return response
end


--[[
@param     Player    player    | The Player instance of disconnected/disconnecting client.
@return    void

Removes the entry in the userRankCache cache associated with the given Player instance.
]]
local function removeRankFromCache(player: Player)
    assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
	
    userRankCache[player] = nil
end


--[[
@param     Player    player    | The player whose rank to retrieve.
@return    void

Attempts to retrieve the user's rank from the userRankCache. If the
entry does not exist, the function will attempt to initialize one.
]]
local function getRank(player: Player): number?
    assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
	
    return userRankCache[player] or initializeRankInCache(player)
end


--[[
@param     number    rank    | The rank to verify.
@return    boolean

Checks if the given rank is an integer within the range of [1, 255].
]]
local function isValidGroupRank(rank: number): boolean
    assertLevel(rank ~= nil, "Argument #1 missing or nil.", 1)
	
    return rank > 0 and rank < 256 and rank % 1 == 0
end


--[[
@return    RoleInfo?

Retrieves the "Roles" table returned by GroupService:GetGroupInfoAsync.
]]
local function getGroupRoles(): RoleInfo?
    local success, response = pcall(function()
        return GroupService:GetGroupInfoAsync(GROUP_ID)
    end)

    if not success then
        warn(GROUP_ROLE_RETRIEVAL_FAILURE:format(response))

        return
    end
  
    return response.Roles
end


--[[
@param     number      rank    | A valid group rank.
@return    RoleInfo

Retrieves the role directly linked to the given rank or the last role which is inferior 
to the given rank. Requires the given rank be be a valid group rank (see isValidGroupRank), and 
for the groupRolesCache to be initialized.
]]
local function getRightmostRoleInfo(rank: number): RoleInfo
    assertLevel(rank ~= nil, "Argument #1 missing or nil.", 1)
    assertLevel(isValidGroupRank(rank), "Expected integer in range [1, 255], got " .. rank, 1)
    assertLevel(groupRolesCache ~= nil, "groupRolesCache has not been initialized; consider adding a check before calling this function.", 1)
	
    for index, info in groupRolesCache do
        if info.Rank == rank then
            return info
        end
    
        if info.Rank > rank then
            return groupRolesCache[index - 1]
        end
    end
end


--[[
@param     Player          player    | The target player.
@param     number          rank      | The target rank.
@return    UpdateStatus
	
Attempts to update the player's group role by calling the API endpoint with the given rank.
]]
local function updateRank(player: Player, rank: number): UpdateStatus
    assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
    assertLevel(rank ~= nil, "Argument #2 missing or nil.", 1)

    if not isValidGroupRank(rank) then
	return "Rejected"	
    end

    local currentRank = getRank(player)
	
    if not currentRank then
        return "Failed"
    end

    if currentRank >= GROUP_RANK_CAP or rank > GROUP_RANK_CAP then
	return "Rejected"	
    end
	
    local role = "Unkown"

    --[[
    If available, apply the groupRolesCache to compensate for level-jumping
    and reduce redundant calls made to the API endpoint.
    ]]
    if groupRolesCache then
        local info = getRightmostRoleInfo(rank)
		
    	if info.Rank == userRankCache[player] then
		return "Rejected"
    	end
	
    	role = info.Name
    end

    local body = {
        user = player.UserId,
        rank = rank,
    }

    local packet = {
        Url = API_ENDPOINT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["X-Authorization-Token"] = API_AUTHORIZATION_TOKEN,
        },
        Body = HttpService:JSONEncode(body),
    }

    local success, response = pcall(function()
        return HttpService:RequestAsync(packet)
    end)
  
    if not success then
        warn(GROUP_ROLE_UPDATE_FAILURE:format(player.Name, role, response))
		
        return "Failed"
    end

    if not response.Success then
        warn(GROUP_ROLE_UPDATE_FAILURE:format(player.Name, role, "HTTP " .. response.StatusCode .. " " .. response.StatusMessage))
		
        return "Failed"
    end

    --[[
    Ensures that the entry isn't resurrected if the player had 
    disconnected at the time the thread was suspended.
    ]]
    if userRankCache[player] then
        userRankCache[player] = rank -- Trusted to correlate to a valid role if no failures occurred.
    end
  
    return "Success"
end



type RoleInfo = {
    Name: string,
    Rank: number,
}

type UpdateStatus = "Failed" | "Rejected" | "Success"


groupRolesCache = getGroupRoles()

Players.PlayerAdded:Connect(initializeRankInCache)
Players.PlayerRemoving:Connect(removeRankFromCache)


return {
    UpdateRank = updateRank,
}
