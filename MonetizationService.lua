--[[
Author     Ziffixture (74087102)
Date       24/04/02 (YY/MM/DD)
Version    1.3.0b
]]



--!strict
type GamePassOwnershipCache = {
	[Player]: {[number]: true},
}

type AssetData = {
	Id      : number,
	Name    : string,
	Handler : (Player) -> (),
}

type AssetIdMap = {
	[number]: AssetData,
}

type CategorizedAssets = {
	GamePass         : AssetIdMap,
	DeveloperProduct : AssetIdMap,
}

-- In accordance with https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt (23/10/20)
type DeveloperProductReceipt = {
	PurchaseId            : number,
	PlayerId              : number,
	ProductId             : number,
	PlaceIdWherePurchased : number,
	CurrencySpent         : number,
	CurrencyType          : Enum.CurrencyType,
}



local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")


local MonetizationService = {}


local NOT_PROCESSED_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local PURCHASE_GRANTED  = Enum.ProductPurchaseDecision.PurchaseGranted


local gamePassOwnershipCache = {} :: GamePassOwnershipCache

local categorizedAssets = {} :: CategorizedAssets
categorizedAssets.GamePass         = {}
categorizedAssets.DeveloperProduct = {}



--[[
@return    void

Processes the GamePasses and DeveloperProducts child folders into a lookup table.
]]
local function boostrapAssets()
	local gamePass         = assert(script:FindFirstChild("GamePass"), "Could not find GamePass directory.")
	local developerProduct = assert(script:FindFirstChild("DeveloperProduct"), "Could not find DeveloperProduct directory.")

	local function loadModules(container: AssetIdMap, modules: {ModuleScript})
		for _, module in modules do
			local asset = require(module) :: AssetData

			container[asset.Id] = asset
		end
	end

	loadModules(categorizedAssets.GamePass, gamePass:GetChildren())
	loadModules(categorizedAssets.DeveloperProduct, developerProduct:GetChildren())
end


--[[
@param     Player     player          | The player who observed the game-pass.
@param     number     gamePassId      | The asset ID of the game-pass.
@param     boolean    wasPurchased    | Whether or not the game-pass was purchased.
@return    void

If purchased, invokes the associated game-pass' handler function with the player who purchased the game-pass.
]]
local function onGamePassPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end

	local gamePass = categorizedAssets.GamePass[gamePassId]
	if not gamePass then
		warn(`Unregistered game-pass {gamePassId}.`)

		return
	end

	gamePassOwnershipCache[player][gamePassId] = true
	gamePass.Handler(player)
end


--[[
@param     DeveloperProductReceipt         receipt    | The details about the developer product purchase.
@return    Enum.ProductPurchaseDecision

Invokes the associated developer product handler function with the player who purchased the developer product.
]]
local function onDeveloperProductPurchaseFinished(receipt: DeveloperProductReceipt): Enum.ProductPurchaseDecision	
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return NOT_PROCESSED_YET
	end

	local developerProduct = categorizedAssets.DeveloperProduct[receipt.ProductId]
	if not developerProduct then
		warn(`Unregistered developer product {receipt.ProductId}.`)

		return NOT_PROCESSED_YET
	end

	developerProduct.Handler(player)

	return PURCHASE_GRANTED
end


--[[
@param     Player    player    | The player who is leaving the server.
@return    void

Clears the given player from the "gamePassOwnerCache".
]]
local function onPlayerRemoving(player: Player)
	gamePassOwnershipCache[player] = nil
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean    
@throws

Acts as a wrapper function to MarketplaceService:UserOwnsGamePassAsync, where Roblox's static cache is
replaced with a dynamic cache.
]]
function MonetizationService.userOwnsGamePassAsync(userId: number, gamePassId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end

	if not gamePassOwnershipCache[player] then
		gamePassOwnershipCache[player] = {}
	end
	
	if gamePassOwnershipCache[player][gamePassId] then
		gamePassOwnershipCache[player][gamePassId] = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end

	return gamePassOwnershipCache[player][gamePassId] or false
end


--[[
@param     Player    player    | The player whose gamepasses to load.
@return    void
@throws

Calls the game-pass handler function of all game-passes owned by the given player.
]]
function MonetizationService.loadGamePasses(player: Player)
	for _, gamePass in categorizedAssets.GamePass do
		if MonetizationService.userOwnsGamePassAsync(player.UserId, gamePass.Id) then
			task.defer(gamePass.Handler, player)
		end
	end
end



boostrapAssets()


MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
MarketplaceService.ProcessReceipt = onDeveloperProductPurchaseFinished


return MonetizationService
