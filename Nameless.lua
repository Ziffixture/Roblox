--[[
Author:     Ziffix
Version:    1.2.0
Date:	    4/19/23
Notes:

WARNING!!!

This code is a potential source of data regression; it is not
designed to cease functioning in case of data retrival failure.
]]



type RoleInfo = {
 
    Name: string,
    Rank: string,
  
}



local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")


local API_AUTHORIZATION_TOKEN = ""
local API_URL = ""

local GROUP_ID = 0
local GROUP_ROLE_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve group data: %s"
local GROUP_ROLE_UPDATE_FAILURE = "A problem occurred while trying to update %s's role to \"%s\": %s"
local GROUP_RANK_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve %s's current rank: %s"
local GROUP_RANK_CAP = 254 -- Should not exceed 254

local groupRoles = nil
local currentRank = {}

local blacklist = {
    -- user ID,
    -- user ID,
}



--[[
@param       player       Player  | The Player instance of the newly connnected client.
@return      N/A          void    | N/A

Initializes an entry in the currentRank cache associated
with the given Player instance.
]]
local function onPlayerAdded(player: Player)
    local success, response = pcall(function()
        return player:GetRankInGroup(GROUP_ID)
    end)
  
    if not success then
        warn(GROUP_RANK_RETRIEVAL_FAILURE:format(player.Name, response))
    
        --[[
        Due to the check on line 181, the entry must be
        made regardless in order to promote an update in
        the user's cache.
        ]]
        currentRank[player] = 0
    
        return
    end
  
    currentRank[player] = response
end


--[[
@param       player       Player  | The Player instance of disconnecting client.
@return      N/A          void    | N/A

Removes the entry in the currentRank cache associated
with the given Player instance.
]]
local function onPlayerRemoving(player: Player)
    currentRank[player] = nil
end

--[[
@return      N/A      RoleInfo?   | A dictionary containing the role's name and rank data.

Retrieves the "Roles" table returned by GroupService:GetGroupInfoAsync.
]]
local function _getGroupRoleInfo(): RoleInfo?
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
@param       rank     number      | An arbitary rank.
@return      N/A      RoleInfo    | A dictionary containing the role's name and rank data.

Retrieves the first role which is inferior or equivalent
to the given rank.
]]
local function _getRole(rank: number): RoleInfo
    for index, info in groupRoles do
        if info.Rank == rank then
            return info
        end
    
        if info.Rank > rank then
            return groupRoles[index - 1]
        end
    end
end


--[[
@param        player      Player	| The target player.
@param        rank        number	| The target rank.
@return       N/A         boolean 	| Whether or not the function executed successfully.
	
Calls the API endpoint in an attempt to update the player's 
role in the group based off on the given rank.
]]
local function updateRank(player: Player, rank: number): boolean
    if table.find(blacklist, player.UserId) then
        return true
    end
  
    if rank > GROUP_RANK_CAP then
        return true
    end
  
    local role = _getRole(rank)
  
    if role.Rank == currentRank[player] then
        return true
    end

    local body = {
        user = player.UserId,
        rank = rank,
    }

    local packet = {
        Url = API_URL,
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
    Ensures that the entry isn't re-initialized if
    the player had disconnected in the time the
    thread was suspended.
    ]]
    if currentRank[player] then
        currentRank[player] = role.Rank
    end
  
    return true
end



groupRoles = _getGroupRoleInfo()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

return updateRank
