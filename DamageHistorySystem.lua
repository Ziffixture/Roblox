--[[
Author     Ziffixture (74087102)
Date       24/03/26
Version    1.1.2b
]]



--!strict
type DamageToken = {
	Dealer : Player?,
	Damage : number,
	Cause  : string,
}

type DamageHistory = {
	Humanoid : Humanoid,
	Tokens   : {DamageToken}
}

type DamageHistories = {[Humanoid]: DamageHistory}

export type DeathSummary = {
	Assists             : {Player},
	AssistCountAsKiller : Player?,
	Killer              : Player?,
	Cause               : string,
}

export type DamageParameters = {
	Target : Player,
	Dealer : Player?,
	Amount : number,
	Cause  : string,
}



local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Utility          = ReplicatedStorage.Utility
local Signal           = require(Utility.Signal)
local PlayerEssentials = require(Utility.PlayerEssentials)

local Feature       = script.Parent
local Configuration = Feature.Configuration
local FriendlyFire  = Configuration.FriendlyFire

local KillsService = {}
KillsService.PlayerKilled = Signal.new() :: Signal.Signal<Player, DeathSummary>


local damageHistories: DamageHistories = {}



--[[
@param     DamageHistory    damageHistory    | The damage history in which the damage token is appeneded to.
@param     DamageToken      damageToken      | The damage token to append.

Records the damage token as the lastest damage token in the given damage history.
]]
local function appendDamageToken(damageHistory: DamageHistory, damageToken: DamageToken)
	table.insert(damageHistory.Tokens, damageToken)
end


--[[
@param     DamageHistory    damageHistory    | The history of damage dealt to a particular Humanoid.
@return    DeathSummary

Constructs a death summary based on the given damage history.
]]
local function buildDeathSummary(damageHistory: DamageHistory): DeathSummary
	local latestToken = damageHistory.Tokens[#damageHistory.Tokens]
	local killer      = latestToken.Dealer
	
	local deathSummary = {} :: DeathSummary
	deathSummary.Assists             = {}
	deathSummary.AssistCountAsKiller = nil
	deathSummary.Killer              = killer
	deathSummary.Cause               = latestToken.Cause
	
	local damageTotals = {} :: {[Player]: number}

	for _, token in damageHistory.Tokens do
		if not token.Dealer or token.Dealer == killer then
			continue
		end

		damageTotals[token.Dealer] = (damageTotals[token.Dealer] or 0) + token.Damage
	end

	local halfMaxHealth = damageHistory.Humanoid.MaxHealth / 2

	for dealer, totalDamage in damageTotals do
		if totalDamage >= halfMaxHealth then
			deathSummary.AssistCountAsKiller = dealer
		else
			table.insert(deathSummary.Assists, dealer)
		end
	end

	return deathSummary
end


--[[
@param     Player     playerA    | A player.
@param     Player     playerB    | A player.
@return    boolean

Check if two teammates are fighting against each other, and whether or not it's permitted.
]]
function KillsService.isFriendlyFire(playerA: Player, playerB: Player): boolean
	return not FriendlyFire.Value and playerA.Team == playerB.Team
end


--[[
@param     Player    attacked      | The player to deal damage to.
@param     number    amount        | The amount of damage to deal.
@param     Player    attacker      | The player dealing the damage.
@param     string    weaponName    | The name of the weapon dealing damage.
@return    void

If possible, deals a specific amount of damage to the given player. Records this damage in the given player's
damage history.
]]
function KillsService.dealDamage(damageParameters: DamageParameters)
	local attackedHumanoid = PlayerEssentials.getHumanoid(damageParameters.Target)
	if not attackedHumanoid then
		warn(`Unable to damage {damageParameters.Target.Name} (no Humanoid available).`)

		return
	end

	if attackedHumanoid.Health == 0 then
		return
	end

	local damageHistory = damageHistories[attackedHumanoid]

	appendDamageToken(damageHistory, {
		Dealer = damageParameters.Dealer,
		Damage = damageParameters.Amount,
		Cause  = damageParameters.Cause,
	})

	attackedHumanoid.Health -= damageParameters.Amount
end


--[[
@param     Player    player    | The player to track the damage of.
@return    void

Starts a track record of the player's damage. Reports a summary of this damage upon death.
]]
function KillsService.trackDamage(player)
	local humanoid = PlayerEssentials.getHumanoid(player)
	if not humanoid then
		warn(`Unable to track {player.Name}'s damage (no Humanoid available).`)

		return
	end

	local damageHistory = {} :: DamageHistory
	damageHistory.Humanoid = humanoid
	damageHistory.Tokens   = {}

	damageHistories[humanoid] = damageHistory

	local previousHealth = humanoid.Health
	local previousToken  = nil

	humanoid.HealthChanged:Connect(function(newHealth)
		local latestToken = damageHistory.Tokens[#damageHistory.Tokens]
		
		local healthDifference = math.abs(newHealth - previousHealth)

		if newHealth > previousHealth then
			local oldestToken = damageHistory.Tokens[1]
			if not oldestToken then
				return
			end

			oldestToken.Damage -= healthDifference
			if oldestToken.Damage <= 0 then
				table.remove(damageHistory.Tokens, 1)
			end
		else
			-- If no new record of damage exists, the damage was caused by an external force.
			if previousToken ~= latestToken then
				return
			end
			
			appendDamageToken(damageHistory, {
				Dealer = nil,
				Damage = healthDifference,
				Cause  = "Envrionment",
			})
		end

		previousHealth = newHealth
		previousToken  = latestToken
	end)

	humanoid.Died:Once(function()
		damageHistories[humanoid] = nil

		KillsService.PlayerKilled:Fire(player, buildDeathSummary(damageHistory))
	end)
end



return KillsService
