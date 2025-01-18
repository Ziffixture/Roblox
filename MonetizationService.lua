--[[
Author     Ziffixture (74087102)
Date       01/17/2024 (MM/DD/YYYY)
Version    2.0.0
]]



--!strict
type GamePassOwnershipCache = {
	[Player]: {[number]: true},
}

type AssetData = {
	Id      : number,
	Name    : string,
	Price   : number?,
	Handler : (Player) -> (),

}

type AssetIdMap = {
	[number]: AssetData,
}

type CategorizedAssets = {
	GamePass : AssetIdMap,
	Product  : AssetIdMap,
}

-- In accordance with https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt (11/05/2024)
type ProductReceipt = {
	PurchaseId            : number,
	PlayerId              : number,
	ProductId             : number,
	PlaceIdWherePurchased : number,
	CurrencySpent         : number,
	CurrencyType          : Enum.CurrencyType,
}



local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")


local NOT_PROCESSED_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local PURCHASE_GRANTED  = Enum.ProductPurchaseDecision.PurchaseGranted


local Feature               = script.Parent
local Configuration         = Feature.Configuration
local OwnGamePassesInStudio = Configuration.OwnGamePassesInStudio 

local MonetizationService = {}


local gamePassOwnershipCache = {} :: GamePassOwnershipCache

local categorizedAssets    = {} :: CategorizedAssets
categorizedAssets.GamePass = {}
categorizedAssets.Product  = {}



--[[
@param     number           assetId     | The Id of the asset whose price to query.
@param     Enum.InfoType    infoType    | The InfoType of the asset being queried.
@return    number?

Attempts to retrieve the price of the given asset in Robux.
]]
local function getPriceInRobuxAsync(assetId: number, infoType: Enum.InfoType): number?
	local success, response = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, infoType)
	end)

	if not success then
		warn(`Price retrieval failure for {infoType.Name} {assetId}; {response}`)

		return
	end

	return response.PriceInRobux
end


--[[
@param     Player     player          | The player who observed the game-pass.
@param     number     gamePassId      | The asset ID of the game-pass.
@param     boolean    wasPurchased    | Whether or not the game-pass was purchased.
@return    void

If purchased, invokes the game-pass' handler function with the player who purchased the game-pass.
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
@param     ProductReceipt                  receipt    | The details about the product purchase.
@return    Enum.ProductPurchaseDecision

Invokes the product's handler function with the player who purchased the product.
]]
local function onProductPurchaseFinished(receipt: ProductReceipt): Enum.ProductPurchaseDecision	
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return NOT_PROCESSED_YET
	end

	local product = categorizedAssets.Product[receipt.ProductId]
	if not product then
		warn(`Unregistered developer product {receipt.ProductId}.`)

		return NOT_PROCESSED_YET
	end

	product.Handler(player)

	return PURCHASE_GRANTED
end


--[[
@param     AssetData    asset       | The asset to register.
@param     string       category    | The asset category.
@return    void

Attempts to register the asset to MonetizationService.
]]
local function tryRegisterAsset(asset: AssetData, category: string)
	local registry = categorizedAssets[category]
	if registry[asset.Id] then
		error(`{category} {asset.Id} has already been implemented.`, 3)
	end

	asset.Price = getPriceInRobuxAsync(asset.Id, Enum.InfoType[category])

	registry[asset.Id] = asset
end


--[[
@param     Player       player      | The owner of the game-pass.
@param     AssetData    gamePass    | The game-pass to load.
@return    void

Attempts to run the game-pass' handler function on the given player.
]]
local function tryLoadGamePass(player: Player, gamePass: AssetData)
	if MarketplaceService.userOwnsGamePassAsync(player.UserId, gamePass.Id) then
		task.defer(gamePass.Handler, player)
	end
end


--[[
@param     AssetData    gamePass    | The game-pass to load.
@return    void

Attempts to run the game-pass' handler function on all players.
]]
local function tryLoadGamePassForAll(gamePass: AssetData)
	for _, player in Players do
		tryLoadGamePass(player, gamePass)
	end
end


--[[
@param     Player    player    | The player who joined the game.
@return    void

Attempts to load all game-passes for the player.
]]
local function onPlayerAdded(player: Player)
	for _, gamePass in categorizedAssets.GamePass do
		tryLoadGamePass(player, gamePass)
	end
end


--[[
@param     Player    player    | The player who joined the game.
@return    void

Invalidates the cache associated with the player.
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
	if RunService:IsStudio() and OwnGamePassesInStudio.Value then
		return true
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end

	if not gamePassOwnershipCache[player] then
		gamePassOwnershipCache[player] = {}
	end

	if not gamePassOwnershipCache[player][gamePassId] then
		gamePassOwnershipCache[player][gamePassId] = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end

	return gamePassOwnershipCache[player][gamePassId]
end


--[[
@param     AssetData    gamePass    | The game-pass to register.
@return    void    
@throws

Attempts to register the game-pass to MonetizationService. If successful, attempts to
load the game-pass for all players.
]]
function MonetizationService.registerGamePass(gamePass: AssetData)
	tryRegisterAsset(gamePass, "GamePass")
	tryLoadGamePassForAll(gamePass)
end


--[[
@param     AssetData    product    | The product to register.
@return    void    
@throws

Attempts to register the product to MonetizationService.
]]
function MonetizationService.registerDeveloperProduct(product: AssetData)
	tryRegisterAsset(product, "Product")
end



for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)	
end
	
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
	
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
MarketplaceService.ProcessReceipt = onProductPurchaseFinished


return MonetizationService
