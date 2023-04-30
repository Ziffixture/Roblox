--[[
Author:     Ziffix
Version:    1.4.0 (Untested)
Date:	    23/04/29
]]



type RoleInfo = {
    Name: string,
    Rank: string,
}



local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")


local API_AUTHORIZATION_TOKEN = ""
local API_ENDPOINT = ""

local GROUP_ID = 0
local GROUP_RANK_CAP = 254 -- Should not exceed 254
local GROUP_ROLE_UPDATE_STATUS = {
    Success = "Success",
    Rejected = "Rejected",
    Failed = "Failed",
}

local GROUP_ROLE_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve group data; %s"
local GROUP_ROLE_UPDATE_FAILURE = "A problem occurred while trying to update %s's role to \"%s\"; %s"
local GROUP_RANK_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve %s's current rank; %s"

local groupRolesCache = nil
local userRankCache = {}



--[[
@param       condition	  any  	   | The result of the condition.
@param       message	  string   | The error message to be raised.
@param       level = 2	  number?  | The level at which to raise the error.
@return      N/A          any      | N/A

Implements assert with error's level argument.
]]
local function assertLevel(condition: any, message: string, level: number?): any
    assert(condition ~= nil, "Argument #1 missing or nil.")
    assert(message ~= nil, "Argument #2 missing or nil.")

    -- Lifts error out of this function.
    level = (level or 1) + 1

    if condition then
        return condition
    end

    error(message, level)
end


--[[
@param       player	  Player   | The Player instance of the newly connnected client.
@return      N/A          number?  | The current group rank of the given player.

Attempts to initialize an entry in the userRankCache cache associated 
with the given Player instance.
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
@param       player       Player  | The Player instance of disconnecting client.
@return      N/A          void    | N/A

Removes the entry in the userRankCache cache associated with the 
given Player instance.
]]
local function removeRankFromCache(player: Player)
    assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
	
    userRankCache[player] = nil
end


--[[
@param       player       Player   | The Player whose rank to retrieve.
@return      N/A      	  number?  | The last recorded rank of the given player.

Attempts to retrieve the user's rank from the userRankCache. If the
entry does not exist, the function will attempt to initialize one.
]]
local function getRankInCache(player: Player): number?
    assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
	
    return userRankCache[player] or initializeRankInCache(player)
end


--[[
@return      N/A      RoleInfo?  | A dictionary containing the role's name and rank data.

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
@param       rank     number   | The rank to verify.
@return      N/A      boolean  | Whether or not the rank is valid.

Checks if the given rank is a positive integer within the range of [1, 255].
]]
local function isValidGroupRank(rank: number): boolean
    assertLevel(rank ~= nil, "Argument #1 missing or nil.", 1)
	
    return rank > 0 and rank < 256 and rank % 1 == 0
end


--[[
@param       rank     number    | A valid group rank.
@return      N/A      RoleInfo  | A dictionary containing the role's name and rank data.

Retrieves the role directly linked to the given rank or the last role 
which is inferior to the given rank. Requires the given rank be be a 
valid group rank (see isValidGroupRank), and for the groupRolesCache to be initialized.
]]
local function getRightmostRoleInfo(rank: number): RoleInfo
    assertLevel(rank ~= nil, "Argument #1 missing or nil.", 1)
    assertLevel(isValidGroupRank(rank), "Expected positive integer in range [1, 255], got " .. rank, 1)
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
@param        player      Player   | The target player.
@param        rank        number   | The target rank.
@return       N/A         string   | The status of the update procedure.
	
Attempts to update the player's group role by calling 
the API endpoint with the given rank.
]]
local function updateRank(player: Player, rank: number): "Success" | "Rejected" | "Failed"
    assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
    assertLevel(rank ~= nil, "Argument #2 missing or nil.", 1)

    if not isValidGroupRank(rank) then
	return GROUP_ROLE_UPDATE_STATUS.Rejected	
    end

    local currentRank = getRankInCache(player)
	
    if not currentRank then
        return GROUP_ROLE_UPDATE_STATUS.Failed
    end

    if currentRank >= GROUP_RANK_CAP or rank > GROUP_RANK_CAP then
	return GROUP_ROLE_UPDATE_STATUS.Rejected	
    end
	
    local roleInfo = "Unkown"

    --[[
    If available, applies the groupRolesCache to compensate for level-jumping
    and reduce redundant calls made to the API endpoint.
    ]]
    if groupRolesCache then
        local info = getRightmostRoleInfo(rank)
		
    	if info.Rank == userRankCache[player] then
	    return GROUP_ROLE_UPDATE_STATUS.Rejected
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
            ["x-authorization-token"] = API_AUTHORIZATION_TOKEN,
        },
        Body = HttpService:JSONEncode(body),
    }

    local success, response = pcall(function()
        return HttpService:RequestAsync(packet)
    end)
  
    if not success then
        warn(GROUP_ROLE_UPDATE_FAILURE:format(player.Name, role, response))
		
        return GROUP_ROLE_UPDATE_STATUS.Failed
    end

    if not response.Success then
        warn(GROUP_ROLE_UPDATE_FAILURE:format(player.Name, role, "HTTP " .. response.StatusCode .. " " .. response.StatusMessage))
		
        return GROUP_ROLE_UPDATE_STATUS.Failed
    end

    --[[
    Ensures that the entry isn't resurrected if
    the player had disconnected in the time the
    thread was suspended.
    ]]
    if userRankCache[player] then
        userRankCache[player] = role.Rank
    end
  
    return GROUP_ROLE_UPDATE_STATUS.Success
end



groupRolesCache = getGroupRoles()

Players.PlayerAdded:Connect(initializeRankInCache)
Players.PlayerRemoving:Connect(removeRankFromCache)

return {
    UpdateStatus = table.freeze(GROUP_ROLE_UPDATE_STATUS),
    UpdateRank = updateRank,
}
