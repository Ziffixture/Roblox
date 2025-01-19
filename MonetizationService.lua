--[[
Author     Ziffixture (74087102)
Date       01/18/2024 (MM/DD/YYYY)
Version    2.0.2
]]



--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")


local NOT_PROCESSED_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local PURCHASE_GRANTED  = Enum.ProductPurchaseDecision.PurchaseGranted


local MonetizationService = {}

local Feature       = script.Parent
local Types         = require(Feature.Types)
local Configuration = Feature.Configuration

local UnofficialGamePassOwners = DataStoreService:GetDataStore("UnofficialGamePassOwners", "Test1") 


local gamePassOwnershipCache = {} :: GamePassOwnershipCache

local categorizedAssets    = {} :: CategorizedAssets
categorizedAssets.GamePass = {}
categorizedAssets.Product  = {}



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
@param     AssetData    asset       | The asset to register.
@param     string       category    | The asset category.
@return    void

Attempts to register the asset to MonetizationService.
]]
local function tryRegisterAsset(asset: Types.AssetData, category: keyof<CategorizedAssets>)
	local assets = categorizedAssets[category]
	if assets[asset.Id] then
		error(`{category} {asset.Id} has already been implemented.`, 3)
	end

	asset.Price      = getPriceInRobuxAsync(asset.Id, Enum.InfoType[category])
	assets[asset.Id] = table.clone(asset)
end


--[[
@param     Player       player      | The owner of the game-pass.
@param     AssetData    gamePass    | The game-pass to load.
@return    void

Attempts to run the game-pass' handler function on the given player.
]]
function MonetizationService.tryLoadGamePass(player: Player, gamePass: Types.AssetData)
	if MonetizationService.userOwnsGamePassAsync(player.UserId, gamePass.Id) then
		task.defer(gamePass.Handler, player)
	end
end


--[[
@param     AssetData    gamePass    | The game-pass to load.
@return    void

Attempts to run the game-pass' handler function on all players.
]]
function MonetizationService.tryLoadGamePassForAll(gamePass: Types.AssetData)
	for _, player in Players:GetPlayers() do
		MonetizationService.tryLoadGamePass(player, gamePass)
	end
end


--[[
@param     Player    player    | The player who joined the game.
@return    void

Initializes a game-pass ownership cache for the player.
]]
local function onPlayerAdded(player: Player)
	gamePassOwnershipCache[player] = {}
end


--[[
@param     Player    player    | The player who's leaving the game.
@return    void

Invalidates the cache associated with the player.
]]
local function onPlayerRemoving(player: Player)
	gamePassOwnershipCache[player] = nil
end


--[[
@param     Player     player    | The player to query.
@return    boolean
@throws

Returns whether or not the game-pass is unofficially owned.
]]
local function getUnofficialOwnership(player: Player, gamePassId: number): boolean
	local gamePassIds = UnofficialGamePassOwners:GetAsync(player.UserId) :: GamePassOwnershipMap?
	if not gamePassIds then
		return false
	end
	
	return gamePassIds[gamePassId] ~= nil
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
	if RunService:IsStudio() and Configuration.OwnGamePassesInStudio.Value then
		return true
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) or getUnofficialOwnership(player, gamePassId)
	end
	
	local cache = gamePassOwnershipCache[player]
	
	if not cache[gamePassId] then
		cache[gamePassId] = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) or getUnofficialOwnership(player, gamePassId)
	end

	return cache[gamePassId]
end


--[[
@param     AssetData    gamePass    | The game-pass to register.
@return    void    
@throws

Attempts to register the game-pass to MonetizationService. If successful, attempts to
load the game-pass for all players.
]]
function MonetizationService.registerGamePass(gamePass: Types.AssetData)
	tryRegisterAsset(gamePass, "GamePass")
	
	MonetizationService.tryLoadGamePassForAll(gamePass)
end


--[[
@param     AssetData    product    | The product to register.
@return    void    
@throws

Attempts to register the product to MonetizationService.
]]
function MonetizationService.registerDeveloperProduct(product: Types.AssetData)
	tryRegisterAsset(product, "Product")
end


--[[
@return    {AssetData}    

Returns a copy of the game-pass assets. 
]]
function MonetizationService.getGamePasses(): {Types.AssetData}
	return table.clone(categorizedAssets.GamePass)
end


--[[
@return    {AssetData}    

Returns a copy of the product assets. 
]]
function MonetizationService.getProducts(): {Types.AssetData}
	return table.clone(categorizedAssets.Product)
end


--[[
@param     number        gamePassId    | The game-pass ID to query.
@return    AssetData?    

Returns a copy of the game-pass.
]]
function MonetizationService.getGamePass(gamePassId: number): Types.AssetData?
	local gamePass = categorizedAssets.GamePass[gamePassId]
	if not gamePass then
		return
	end
	
	return table.clone(gamePass)
end


--[[
@param     number        productId    | The product ID to query.
@return    AssetData?    

Returns a copy of the product.
]]
function MonetizationService.getProduct(productId: number): Types.AssetData?
	local product = categorizedAssets.Product[productId]
	if not product then
		return
	end

	return table.clone(product)
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    void    
@throws

Attempts to give the player the game-pass.
]]
function MonetizationService.tryGiveGamePass(userId: number, gamePassId: number)
	local gamePass = categorizedAssets.GamePass[gamePassId]
	if not gamePass then
		error(`Unregistered game-pass {gamePassId}`)
	end
	
	local player = Players:GetPlayerByUserId(userId)
	if player then
		gamePassOwnershipCache[player][gamePassId] = true
		
		MonetizationService.tryLoadGamePass(player, gamePass)
	end
	
	UnofficialGamePassOwners:UpdateAsync(userId, function(gamePassIds: GamePassOwnershipMap)
		gamePassIds             = gamePassIds or {}
		gamePassIds[gamePassId] = true
		
		return gamePassIds
	end)
end



Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
MarketplaceService.ProcessReceipt = onProductPurchaseFinished


type GamePassOwnershipMap = {
	[number]: true,
}

type GamePassOwnershipCache = {
	[Player]: GamePassOwnershipMap,
}

type AssetDataMap = {
	[number]: Types.AssetData,
}

type CategorizedAssets = {
	GamePass : AssetDataMap,
	Product  : AssetDataMap,
}

-- In accordance with https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt (05/11/2024)
type ProductReceipt = {
	PurchaseId            : number,
	PlayerId              : number,
	ProductId             : number,
	PlaceIdWherePurchased : number,
	CurrencySpent         : number,
	CurrencyType          : Enum.CurrencyType,
}


return MonetizationService
