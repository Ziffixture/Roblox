--[[
Author     Ziffixture (74087102)
Date       24/03/29
Version    1.2.0b

A closure-based object that holds a player-involved vote.
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Vendor = ReplicatedStorage.Vendor
local Signal = require(Vendor.Signal)


local PlayerVote = {}



--[[
@param     {T}        options    | The list of options in this poll.
@return    Poll<T>
	
Creates a poll object with the given options.
]]
local function makePoll<T>(options: {T}): Poll<T>
	local poll: Poll<T> = {} 

	for _, subject in options do
		poll[subject] = 0
	end

	return poll
end


--[[
@param     {T}              options    | The list of options available for vote.
@return    PlayerVote<T>

Constructs a PlayerVote object with the given options.
]]
function PlayerVote.new<T>(options: {T}): PlayerVote<T>
	local self   = {} :: PlayerVote<T>
	self.Changed = Signal.new()

	local optionVotedBy : PlayerVoteLookup<T> = {}
	local poll          : Poll<T>             = makePoll(options)


	--[[
	@param     Player    player    | The player submitting their vote.
	@param     T         option    | The option chosen by the player.
	@return    void
	
	Counts the player's vote towards a specific option. Decrements their vote from 
	the previously voted option.
	]]
	function self:Cast(player: Player, option: T)
		local currentOption: T = optionVotedBy[player]
		if currentOption then
			poll[currentOption] -= 1
		end

		poll[option] += 1

		optionVotedBy[player] = option

		self.Changed:Fire(option, poll[option])
	end


	--[[
	@return    T
	
	Tallys the votes and returns the highest voted option. If there are multiple
	options under the highest vote, one is chosen at random.
	]]
	function self:GetWinner(): T
		local voteGroups  : {[number]: {T}} = {}
		local highestVote : number          = 0

		for option, votes in poll do
			if highestVote <= votes then
				highestVote = votes

				if voteGroups[votes] == nil then
					voteGroups[votes] = {option}
				else
					table.insert(voteGroups[votes], option)
				end
			end
		end

		local highestVoteGroup = voteGroups[highestVote]

		return highestVoteGroup[math.random(#highestVoteGroup)]
	end
	
	
	--[[
	@param     T         option    | The option whose vote count to retrieve.
	@return    number
	@throws
	
	Returns the current number of votes for the given option.
	]]
	function self:GetVotes(option: T): number
		if not poll[option] then
			error(`Given option is not a member of the vote. ({tostring(option)})`)
		end
		
		return poll[option]
	end
	
	
	--[[
	@return    Poll<T>
	
	Returns the current state of the vote.
	]]
	function self:GetPoll(): Poll<T>
		return table.clone(poll)
	end


	--[[
	@return    T
	
	Returns a list of the options available for vote.
	]]
	function self:GetOptions(): {T}
		return table.clone(options)
	end


	return self :: any
end



type PlayerVote<T> = {
	Cast : (self: PlayerVote<T>, player: Player, option: T) -> (),

	GetVotes   : (self: PlayerVote<T>, option: T) -> number,
	GetOptions : (self: PlayerVote<T>) -> {T},
	GetPoll    : (self: PlayerVote<T>) -> Poll<T>,
	GetWinner  : (self: PlayerVote<T>) -> T,

	Changed : Signal.Signal<T, number>,
}

type PlayerVoteLookup<T> = {
	[Player]: T,
}

export type Poll<T> = {
	[T]: number,
}



return PlayerVote
