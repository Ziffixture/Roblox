--[[
Author     Ziffixture (74087102)
Date       24/03/25
Version    1.0.1b
]]



--!strict
type DamageToken = {
	Attacker   : Player,
	Damage     : number,
	WeaponName : string,
}

type DamageHistory = {
	Humanoid : Humanoid,
	Tokens   : {DamageToken}
}

type DamageHistories = {[Humanoid]: DamageHistory}

export type DeathSummary = {
	Assists             : {Player},
	AssistCountAsKiller : Player?,
	Killer              : Player
}



local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Utility          = ReplicatedStorage.Utility
local Signal           = require(Utility.Signal)
local PlayerEssentials = require(Utility.PlayerEssentials)

local Feature       = script.Parent
local Configuration = Feature.Configuration
local FriendlyFire  = Configuration.FriendlyFire

local KillsService = {}
KillsService.PlayerKilled = Signal.new()

local damageHistories: DamageHistories = {}



--[[
@param     Player     playerA    | A player.
@param     Player     playerB    | A player.
@return    boolean

A helper function used to check if two players are under friendly fire.
]]
local function isFriendlyFire(playerA: Player, playerB: Player): boolean
	return not FriendlyFire.Value and playerA.Team == playerB.Team
end

--[[
@param     DamageHistory    damageHistory    | The history of damage dealt to a particular Humanoid.
@return    DeathSummary

Constructs a death summary based on the given damage history.
]]
local function buildDeathSummary(damageHistory: DamageHistory): DeathSummary?
	if #damageHistory.Tokens == 0 then
		return nil
	end
	
	local killer = damageHistory.Tokens[#damageHistory.Tokens].Attacker
	
	local damageTotals = {} :: {[Player]: number}
	local deathSummary = {} :: DeathSummary
	deathSummary.Assists             = {}
	deathSummary.AssistCountAsKiller = nil
	deathSummary.Killer              = killer

	for _, token in damageHistory.Tokens do
		if token.Attacker == killer then
			continue
		end
		
		damageTotals[token.Attacker] = (damageTotals[token.Attacker] or 0) + token.Damage
	end
	
	local halfMaxHealth = damageHistory.Humanoid.MaxHealth / 2
	
	for attacker, totalDamage in damageTotals do
		if totalDamage >= halfMaxHealth then
			deathSummary.AssistCountAsKiller = attacker
		else
			table.insert(deathSummary.Assists, attacker)
		end
	end
	
	return deathSummary
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
function KillsService.dealDamage(attacked: Player, amount: number, attacker: Player, weaponName: string)
	if isFriendlyFire(attacked, attacker) then
		return
	end
	
	local _, attackedHumanoid = PlayerEssentials.get(attacked)
	if not attackedHumanoid then
		warn(`Unable to damage {attacked.Name} (no Humanoid available).`)

		return
	end
	
	if attackedHumanoid.Health == 0 then
		return
	end
	
	local damageHistory = damageHistories[attackedHumanoid]
	
	local damageToken = {} :: DamageToken
	damageToken.Attacker   = attacker
	damageToken.Damage     = amount
	damageToken.WeaponName = weaponName
		
	table.insert(damageHistory.Tokens, damageToken)

	attackedHumanoid.Health -= amount
end


--[[
@param     Player    player    | The player to track the damage of.
@return    void

Starts a track record of the player's damage. Reports a summary of this damage upon death.
]]
function KillsService.trackDamage(player)
	local _, humanoid = PlayerEssentials.get(player)
	if not humanoid then
		warn(`Unable to track {player.Name}'s damage (no Humanoid available).`)
		
		return
	end
	
	local previousHealth = humanoid.Health
	
	local damageHistory = {} :: DamageHistory
	damageHistory.Humanoid = humanoid
	damageHistory.Tokens   = {}
	
	damageHistories[humanoid] = damageHistory
	
	humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth > previousHealth then
			local increment   = newHealth - previousHealth
			local oldestToken = damageHistory[1]

			oldestToken.Damage -= increment		
			if oldestToken.Damage <= 0 then
				table.remove(damageHistory, 1)
			end
		end
		
		previousHealth = newHealth
	end)
	
	humanoid.Died:Connect(function()
		damageHistories[humanoid] = nil
		
		KillsService.PlayerKilled:Fire(player, buildDeathSummary(damageHistory))
	end)
end



return KillsService
