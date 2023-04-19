--[[
	Author: Ziffix
	Version: 1.0.0
	Date:	4/19/23
]]



local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")


local API_AUTHORIZATION_TOKEN = ""
local API_URL = "https://httpbin.org/get"

local GROUP_ID = 4511384
local GROUP_ROLE_RETRIEVAL_FAILURE = "A problem occurred while trying to retrieve " .. GROUP_ID .. "'s group data: %s"
local GROUP_ROLE_UPDATE_FAILURE = "A problem occurred while trying to update %s's role to \"%s\": %s"
local groupRoles = nil

--[[
	Intended to prevent the system from demoting important
	users in the group, such as the owner
]]
local blacklist = {
	-- user ID,
	-- user ID,
}



--[[
	@return		N/A		Dict<number, string>?	| A dictionary that maps ranks to roles.

	Produces a dictionary that maps the ranks of GROUP_ID's roles
	to the names of said roles.
]]
local function _getGroupRoles(): {string}?
	local roles = {}

	local success, response = pcall(function()
		return GroupService:GetGroupInfoAsync(GROUP_ID)
	end)

	if not success then
		warn(GROUP_ROLE_RETRIEVAL_FAILURE:format(response))

		return
	end

	for _, info in response.Roles do
		roles[info.Rank] = info.Name
	end

	return roles
end


--[[
	@param		player		Player	| The target player.
	@param		rank		number	| The target rank.
	@return		N/A			boolean | Whether or not the function executed successfully.
	
	Calls the API endpoint in attempt to update the
	player's role in the group based off of the given
	rank.
]]
local function updateRank(player: Player, rank: number): boolean
  	--[[
  		If available, optimizes the function by eliminating
  		redundant requests.
  	]]
	if groupRoles and not groupRoles[rank] then
		return false
	end

	if table.find(blacklist, player.UserId) then
		return false
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

	local role = groupRoles[rank] or "Unknown"

	if not success then
		warn(GROUP_ROLE_UPDATE_FAILURE:format(player.Name, role, response))
		
		return false
	end

	if not response.Success then
		warn(GROUP_ROLE_UPDATE_FAILURE:format(player.Name, role, "HTTP " .. response.StatusCode .. " " .. response.StatusMessage))
		
		return false
	end

	return true
end



groupRoles = _getGroupRoles()

return updateRank