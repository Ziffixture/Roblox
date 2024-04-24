--[[
Author     Ziffixture (74087102)
Date       24/04/24 (YY/MM/DD)
Version    1.2.0b
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
	Time                : number,
	Cause               : string,
	Location            : Vector3?
}

export type DamageParameters = {
	Target           : Player,
	Dealer           : Player?,
	Amount           : number,
	Cause            : string,
	FriendlyFire     : boolean?,
	BypassForceField : boolean?,
}



local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Vendor           = ReplicatedStorage.Vendor
local Signal           = require(Vendor.Signal)
local PlayerEssentials = require(Vendor.PlayerEssentials)

local Feature       = script.Parent
local Configuration = Feature.Configuration
local FriendlyFire  = Configuration.FriendlyFire

local KillsService = {}
KillsService.PlayerKilled = Signal.new() :: Signal.Signal<Player, DeathSummary>


local damageHistories: DamageHistories = {}



--[[
@param     DamageHistory    damageHistory    | The damage history in which the damage token is appeneded to.
@param     DamageToken      damageToken      | The damage token to append.
@return    void

Records the damage token as the lastest damage token in the given damage history.
]]
local function appendDamageToken(damageHistory: DamageHistory, damageToken: DamageToken)
	table.insert(damageHistory.Tokens, damageToken)
end


--[[
@param     Humanoid         humanoid    | The Humanoid to associate a damage history with.
@return    DamageHistory

Initializes a damage history under the given Humanoid. Returns a reference to that damage history.
]]
local function initializeDamageHistory(humanoid: Humanoid): DamageHistory
	local damageHistory = {} :: DamageHistory
	damageHistory.Humanoid = humanoid
	damageHistory.Tokens   = {}

	damageHistories[humanoid] = damageHistory

	return damageHistory
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
	deathSummary.Time                = os.time()
	deathSummary.Cause               = latestToken.Cause
	deathSummary.Location            = nil

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

	local rootPart = damageHistory.Humanoid.RootPart
	if rootPart then
		deathSummary.Location = rootPart.Position
	end

	return deathSummary
end


--[[
@param     DamageParameters    damageParameters    | The parameters concerning this damage instance.
@return    boolean

Checks if two teammates are fighting against each other, and whether or not it's permitted.
]]
local function isFriendlyFire(damageParameters: DamageParameters): boolean	
	if not damageParameters.Dealer then
		return false
	end
	
	local allowed = FriendlyFire.Value and damageParameters.FriendlyFire
	if allowed then
		return false
	end
	
	local playerA = damageParameters.Dealer
	local playerB = damageParameters.Target

	return playerA.Team == playerB.Team
end


--[[
@param     DamageParameters    damageParameters    | The parameters concerning this damage instance.
@return    boolean

Checks if the target's force field is active, and whether or not that matters.
]]
local function isForceFieldActive(damageParameters: DamageParameters): boolean
	local character = damageParameters.Target.Character
	local bypass    = damageParameters.BypassForceField
	
	if not character or bypass then
		return false
	end
	
	return character:FindFirstChildOfClass("ForceField") ~= nil 
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
	if isFriendlyFire(damageParameters) or isForceFieldActive(damageParameters) then
		return
	end
	
	local attackedHumanoid = PlayerEssentials.getHumanoid(damageParameters.Target)
	if not attackedHumanoid then
		warn(`Unable to damage {damageParameters.Target.Name} (Humanoid unavailable)`)

		return
	end
	
	if attackedHumanoid.Health == 0 then
		return
	end

	local damageHistory = damageHistories[attackedHumanoid]
	if damageHistory then
		appendDamageToken(damageHistory, {
			Dealer = damageParameters.Dealer,
			Damage = damageParameters.Amount,
			Cause  = damageParameters.Cause,
		})
	else
		warn(`Damage is not being tracked for {damageParameters.Target.Name}—consider calling KillsService.trackDamage for this target.`)
	end

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
		warn(`Unable to track {player.Name}'s damage. (Humanoid unvailable)`)

		return
	end

	local damageHistory = initializeDamageHistory(humanoid)

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
			if previousToken ~= latestToken then
				return
			end
			-- If no new record of damage exists, the damage was caused by an external force.

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
	
	humanoid.Destroying:Once(function()
		damageHistories[humanoid] = nil
	end)
end



return KillsService
