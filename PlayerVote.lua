--[[
Author     Ziffixture (74087102)
Date       03/29/2024 (MM/DD/YYYY)
Version    1.5.0

A closure-based object that holds a player-involved vote.
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Vendor = ReplicatedStorage.Vendor
local Signal = require(Vendor.Signal) -- https://github.com/Data-Oriented-House/LemonSignal

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
	@throws
	
	Counts the player's vote towards a specific option. Revokes their vote from 
	the previously voted option.
	]]
	function self:Cast(player: Player, option: T)
		if not self:HasOption(option) then
			error(`Option {option} is not a valid member of this vote.`)
		end

		self:Revoke(player)

		poll[option] += 1
		optionVotedBy[player] = option

		self.Changed:Fire(option, poll[option])
	end


	--[[
	@param     Player    player    | The player submitting their vote.
	@return    T
	
	Revokes the vote cast by the given player. Returns the option they voted for.
	]]
	function self:Revoke(player: Player): T?
		local currentOption: T? = optionVotedBy[player]
		if not currentOption then
			return
		end

		poll[currentOption] -= 1
		optionVotedBy[player] = nil

		self.Changed:Fire(currentOption, poll[currentOption])

		return currentOption
	end


	--[[
	@return    T
	
	Tallys the votes and returns the highest voted option. If there are multiple
	options under the highest vote, one is chosen at random.
	]]
	function self:GetWinner(): T
		local highestVote    : number = 0
		local highestOptions : {T}    = {}

		for option, votes in poll do
			if highestVote < votes then
				highestVote    = votes
				highestOptions = {option}
			elseif highestVote == votes then
				table.insert(highestOptions, option)
			end
		end

		return highestOptions[math.random(#highestOptions)]
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


	--[[
	@param     T         option    | The option whose vote count to retrieve.
	@return    number
	@throws
	
	Returns the current number of votes for the given option.
	]]
	function self:GetVotes(option: T): number
		if self:HasOption(option) then
			error(`Given option is not a member of the vote. ({tostring(option)})`)
		end

		return poll[option]
	end


	--[[
	@param     T          option    | The option to check.
	@return    boolean
	
	Checks whether or not the given option is a member of this vote.
	]]
	function self:HasOption(option: T): boolean
		return poll[option] ~= nil
	end


	return self :: any
end



type PlayerVoteLookup<T> = {
	[Player]: T,
}

export type Poll<T> = {
	[T]: number,
}

export type PlayerVote<T> = {
	Cast   : (self: PlayerVote<T>, player: Player, option: T) -> (),
	Revoke : (self: PlayerVote<T>, player: Player) -> T?, 

	GetWinner  : (self: PlayerVote<T>) -> T,
	GetPoll    : (self: PlayerVote<T>) -> Poll<T>,
	GetOptions : (self: PlayerVote<T>) -> {T},
	GetVotes   : (self: PlayerVote<T>, option: T) -> number,

	HasOption : (self: PlayerVote<T>, option: T) -> boolean,

	Changed : Signal.Signal<T, number>,
}


return PlayerVote
