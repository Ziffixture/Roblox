--[[
Author:     Ziffix
Version:    1.3.1 (Untested)
Date:	    4/22/23
]]



type RoleInfo = {
    Name: string,
    Rank: string,
}



local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")


local UPDATE_BLACKLIST = {
    -- user ID,
    -- user ID,
}

local API_AUTHORIZATION_TOKEN = ""
local API_ENDPOINT = ""

local GROUP_ID = 0
local GROUP_RANK_CAP = 254 -- Should not exceed 254

local GROUP_ROLE_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve group data: %s"
local GROUP_ROLE_UPDATE_FAILURE = "A problem occurred while trying to update %s's role to \"%s\": %s"
local GROUP_RANK_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve %s's current rank: %s"

local groupRolesCache = nil
local userRankCache = {}



--[[
@param       condition	  any  	   | The result of the condition.
@param       message	  string   | The error message to be raised.
@param       level = 1	  number?  | The level at which to raise the error.
@return      N/A          void     | N/A

Implements assert with error's level argument.
]]
local function _assertLevel(condition: any, message: string, level: number?)
    assert(condition ~= nil, "Argument #1 missing or nil.")
    assert(message ~= nil, "Argument #2 missing or nil.")

    level = (level or 1) + 1

    if condition then
        return condition
    end

    error(message, level)
end


--[[
@param       player	  Player  | The Player instance of the newly connnected client.
@return      N/A          void    | N/A

Initializes an entry in the userRankCache cache associated
with the given Player instance.
]]
local function _initializeRankInCache(player: Player)
    _assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
	
    local success, response = pcall(function()
        return player:GetRankInGroup(GROUP_ID)
    end)
  
    if not success then
        warn(GROUP_RANK_RETRIEVAL_FAILURE:format(player.Name, response))
    
        --[[
        Due to the check on line 226, the entry must be
        made regardless in order to promote an update in
        the user's cache.
        ]]
        userRankCache[player] = 0
    
        return
    end
  
    userRankCache[player] = response
end


--[[
@param       player       Player  | The Player instance of disconnecting client.
@return      N/A          void    | N/A

Removes the entry in the userRankCache cache associated
with the given Player instance.
]]
local function _removeRankFromCache(player: Player)
    _assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
	
    userRankCache[player] = nil
end


--[[
@return      N/A      RoleInfo?  | A dictionary containing the role's name and rank data.

Retrieves the "Roles" table returned by GroupService:GetGroupInfoAsync.
]]
local function _getGroupRoles(): RoleInfo?
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
@param       rank     number    | A valid group rank.
@return      N/A      RoleInfo  | A dictionary containing the role's name and rank data.

Retrieves the role directly linked to the given rank or 
the last role which is inferior to the given rank. Requires
the given rank to be a positive integer above 0.
]]
local function _getRightmostRoleInfo(rank: number): RoleInfo
    _assertLevel(rank ~= nil, "Argument #1 missing or nil.", 1)
    _assertLevel(rank > 0, "Rank must be a positive integer above 0.", 1)
	
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
@return       N/A         boolean  | Whether or not the function executed successfully.
	
Attempts to update the player's group role by calling 
the API endpoint with the given rank. Requires the given 
rank to be a positive integer above 0.
]]
local function updateRank(player: Player, rank: number): boolean
    _assertLevel(player ~= nil, "Argument #1 missing or nil.", 1)
    _assertLevel(rank ~= nil, "Argument #2 missing or nil.", 1)
    _assertLevel(rank > 0, "Rank must be a positive integer above 0.", 1)
	
    if table.find(UPDATE_BLACKLIST, player.UserId) then
        return true
    end
  
    if rank > GROUP_RANK_CAP then
        return true
    end
  
    local role = "Unknown"

    --[[
    If available, applies the groupRolesCache to 
    reduce redundant calls made to the API endpoint.
    ]]
    if groupRolesCache then
	local info = _getRightmostRoleInfo(rank)
		
	if info.Rank == userRankCache[player] then
	    return true		
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
		
        return false
    end

    if not response.Success then
        warn(GROUP_ROLE_UPDATE_FAILURE:format(player.Name, role, "HTTP " .. response.StatusCode .. " " .. response.StatusMessage))
		
        return false
    end

    --[[
    Ensures that the entry isn't resurrected if
    the player had disconnected in the time the
    thread was suspended.
    ]]
    if userRankCache[player] then
        userRankCache[player] = role.Rank
    end
  
    return true
end



groupRolesCache = _getGroupRoles()

Players.PlayerAdded:Connect(_initializeRankInCache)
Players.PlayerRemoving:Connect(_removeRankFromCache)

return updateRank
