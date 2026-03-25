--[[
Author     Ziffixture (74087102)
Date       03/25/2026 (MM/DD/YYYY)
Version    2.2.8
]]



--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")


local UnofficialGamePassOwners = DataStoreService:GetDataStore("UnofficialGamePassOwners", "Production")

local Vendor = ReplicatedStorage.Vendor
local Signal = require(Vendor.Signal)

local Feature       = script.Parent
local Types         = require(Feature.Types)
local Configuration = Feature.Configuration

local SharedFeature = ReplicatedStorage.Monetization
local SharedTypes   = require(SharedFeature.Types)

local MonetizationService = {}
MonetizationService.GamePassRegistered = Signal.new() :: Types.AssetRegisteredSignal
MonetizationService.ProductRegistered  = Signal.new() :: Types.AssetRegisteredSignal
MonetizationService.AssetRegistered    = Signal.new() :: Types.AssetRegisteredSignal
MonetizationService.GamePassOwned      = Signal.new() :: Types.GamePassOwnedSignal


local NOT_PROCESSED_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local PURCHASE_GRANTED  = Enum.ProductPurchaseDecision.PurchaseGranted

local ASSET_CATEGORY = {
	PRODUCT   = 1,
	GAME_PASS = 2,
}


local categorizedAssets = {} :: CategorizedAssets
categorizedAssets.Product  = {}
categorizedAssets.GamePass = {}

local categorizedPromptThreads = {}
categorizedPromptThreads.Product  = {}
categorizedPromptThreads.GamePass = {}

local gamePassOwnershipCache = {} :: GamePassOwnershipCache
local assetRegisteredSignals = {} :: {Signal.Signal<Types.Asset>}



--[[
@param     Player    player    | The player to query.
@return    void

Returns the cache associated with the player. If one doesn't exist, one is created.
]]
local function getCache(player: Player)
	if not gamePassOwnershipCache[player] then
		gamePassOwnershipCache[player] = {}
	end

	return gamePassOwnershipCache[player]
end


--[[
@param     Player    player    | The player who's leaving the game.
@return    void

Invalidates the cache associated with the player.
]]
local function deleteCache(player: Player)
	gamePassOwnershipCache[player] = nil
end


--[[
@param     Player     player        | The player whose cache to edit.
@param     number     gamePassId    | The asset ID of the game-pass.
@param     boolean    owned         | The state of ownership.
@return    void

If present, runs the asset's handler function.
]]
local function setGamePassOwned(player: Player, gamePassId: number, owned: boolean)
	getCache(player)[gamePassId] = owned

	if owned then
		MonetizationService.GamePassOwned:Fire(player, MonetizationService.getGamePass(gamePassId))
	end
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean

Returns whether or not the game-pass is owned in-cache.
]]
local function ownsGamePassInCache(userId: number, gamePassId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return false
	end

	return getCache(player)[gamePassId]
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean
@throws
@yields

Returns whether or not the game-pass is owned unofficially.
]]
local function ownsGamePassUnofficiallyAsync(userId: number, gamePassId: number): boolean
	local gamePassIds = UnofficialGamePassOwners:GetAsync(userId) :: SharedTypes.GamePassOwnershipMap
	if not gamePassIds then
		return false
	end

	-- JSON encodes numerical keys to strings.
	return gamePassIds[tostring(gamePassId)] ~= nil
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean
@throws
@yields

Returns whether or not the game-pass is owned Roblox Studio.
]]
local function ownsGamePassInStudio(userId: number, gamePassId: number): boolean
	return RunService:IsStudio() 
		and Players:GetPlayerByUserId(userId)
		and Configuration.OwnGamePassesInStudio.Value 
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean
@throws
@yields

Returns whether or not the game-pass is owned.
]]
local function ownsGamePassAsync(userId: number, gamePassId: number): boolean
	return ownsGamePassInStudio(userId, gamePassId)
		or ownsGamePassInCache(userId, gamePassId)
		or MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) 
		or ownsGamePassUnofficiallyAsync(userId, gamePassId)
end


--[[
@param     Asset    asset    | The asset whose handler to run.
@param     ...
@return    void

If present, runs the asset's handler function.
]]
local function tryRunHandler(asset: Types.Asset, ...)
	if asset.Handler then
		asset.Handler(...)
	end
end


--[[
@param     Asset     asset       | The asset to register.
@param     string    category    | The asset category.
@return    void
@throws

Attempts to register the asset to MonetizationService.
]]
local function tryResumeAssetPromptThreads(category: SharedTypes.AssetCategory, assetId: number, wasPurchased: boolean)
	local threads = categorizedPromptThreads[category][assetId]
	if not threads then
		return
	end

	for _, thread in threads do
		coroutine.resume(thread, wasPurchased)
	end
end


--[[
@param     Player     player          | The player who observed the game-pass.
@param     number     gamePassId      | The asset ID of the game-pass.
@param     boolean    wasPurchased    | Whether or not the game-pass was purchased.
@return    void

If purchased, invokes the game-pass' handler function with the player who purchased the game-pass.
]]
local function onGamePassPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	local gamePass = categorizedAssets.GamePass[gamePassId]
	if not gamePass then
		warn(`Unregistered game-pass {gamePassId}.`)

		return
	end

	if wasPurchased then
		setGamePassOwned(player, gamePassId, true)
		tryRunHandler(gamePass, player)
	end

	tryResumeAssetPromptThreads(
		ASSET_CATEGORY.GAME_PASS, 
		gamePassId, 
		wasPurchased
	)
end


--[[
@param     ProductReceipt                  receipt    | The details about the product purchase.
@return    Enum.ProductPurchaseDecision

Invokes the product's handler function with the player who purchased the product.
]]
local function onProductPurchaseFinished(receipt: Types.ProductReceipt): Enum.ProductPurchaseDecision
	local product = categorizedAssets.Product[receipt.ProductId]
	if not product then
		warn(`Unregistered product {receipt.ProductId}.`)

		return NOT_PROCESSED_YET
	end

	local player       = Players:GetPlayerByUserId(receipt.PlayerId)
	local wasPurchased = player ~= nil

	if wasPurchased then
		tryRunHandler(product, player, receipt)
	end

	tryResumeAssetPromptThreads(
		ASSET_CATEGORY.PRODUCT, 
		receipt.ProductId, 
		wasPurchased
	)

	return wasPurchased and PURCHASE_GRANTED or NOT_PROCESSED_YET
end


--[[
@param     number           assetId     | The Id of the asset whose price to query.
@param     Enum.InfoType    infoType    | The InfoType of the asset being queried.
@return    number?
@throws
@yields

Attempts to retrieve the price of the given asset in Robux.
]]
local function getPriceInRobuxAsync(assetId: number, infoType: Enum.InfoType): number?
	local success, response = pcall(function()
		return MarketplaceService:GetProductInfoAsync(assetId, infoType)
	end)

	if not success then
		warn(`Price retrieval failure for {infoType.Name} {assetId}; {response}`)

		return
	end

	return response.PriceInRobux
end


--[[
@param     Asset     asset       | The asset to register.
@param     number    category    | The asset category.
@return    void
@throws
@yields

Attempts to register the asset to MonetizationService.
]]
local function tryRegisterAssetAsync(category: number, asset: Types.Asset)
	local assets = categorizedAssets[category]
	if assets[asset.Id] then
		error(`{category} {asset.Id} has already been implemented.`)
	end

	asset.Price      = getPriceInRobuxAsync(asset.Id, Enum.InfoType[category])
	asset.Category   = category
	assets[asset.Id] = table.clone(asset)

	MonetizationService.AssetRegistered:Fire(table.clone(asset))
	MonetizationService[`{category}Registered`]:Fire(table.clone(asset))

	local assetRegisteredSignal = assetRegisteredSignals[asset.Id]
	if not assetRegisteredSignal then
		return
	end

	assetRegisteredSignal:Fire(table.clone(asset))
	assetRegisteredSignal:Destroy()

	assetRegisteredSignal[asset.Id] = nil
end


--[[
@param     Asset     asset       | The asset to register.
@param     string    category    | The asset category.
@return    void
@throws
@yields

Attempts to register the asset to MonetizationService.
]]
local function promptAssetPurchaseAsync(category: SharedTypes.AssetCategory, player: Player, assetId: number): boolean
	local thread  = coroutine.running()
	local threads = categorizedPromptThreads[category]

	if not threads[assetId] then
		threads[assetId] = { thread }
	else
		table.insert(threads[assetId], thread)
	end

	local prompt

	if category == ASSET_CATEGORY.PRODUCT then
		prompt = MarketplaceService.PromptProductPurchase
	elseif category == ASSET_CATEGORY.GAME_PASS then
		prompt = MarketplaceService.PromptGamePassPurchase
	end

	prompt(MarketplaceService, player, assetId)

	return coroutine.yield()
end


--[[
@param     number                 assetId    | The asset ID.
@return    Signal.Connection<>    
@throws

Schedules a callback for the registration of a particular asset.
]]
function MonetizationService.listenForAssetRegistered(assetId: number, callback: (asset: Types.Asset) -> ()): Signal.Connection<>
	if MonetizationService.isAsset(assetId) then
		error(`Asset {assetId} is already registered.`)
	end

	if not assetRegisteredSignals[assetId] then
		assetRegisteredSignals[assetId] = Signal.new()
	end

	return assetRegisteredSignals[assetId]:Once(callback)
end


--[[
@param      {number}    assetIds    | A list of asset IDs to await.
@returns    void
@yields

Awaits the registration of a series of asset IDs.
]]
function MonetizationService.awaitAssets(assetIds: {number})
	local thread = coroutine.running()
	local tasks  = 0

	local function try_resume()
		tasks -= 1
		if tasks == 0 then
			coroutine.resume(thread)
		end
	end

	for _, assetId in assetIds do
		if MonetizationService.isAsset(assetId) then
			MonetizationService.listenForAssetRegistered(assetId, try_resume)

			tasks += 1
		end
	end

	if tasks > 0 then
		coroutine.yield()
	end
end


--[[
@param     Player    player      | The owner of the game-pass.
@param     Asset     gamePass    | The game-pass to load.
@return    void
@throws
@yields

Attempts to run the game-pass' handler function on the given player.
]]
function MonetizationService.tryLoadGamePassAsync(player: Player, gamePass: Types.Asset)
	if MonetizationService.userOwnsGamePassAsync(player.UserId, gamePass.Id) then
		task.spawn(tryRunHandler, gamePass, player)
	end
end


--[[
@param     Asset    gamePass    | The game-pass to load.
@return    void
@throws
@yields

Attempts to run the game-pass' handler function on all players.
]]
function MonetizationService.tryLoadGamePassForAllAsync(gamePass: Types.Asset)
	for _, player in Players:GetPlayers() do
		MonetizationService.tryLoadGamePassAsync(player, gamePass)
	end
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean    
@throws
@yields

Acts as a wrapper function to MarketplaceService:UserOwnsGamePassAsync, where Roblox's static cache is
replaced with a dynamic cache.
]]
function MonetizationService.userOwnsGamePassAsync(userId: number, gamePassId: number): boolean
	local owned = ownsGamePassAsync(userId, gamePassId)

	local player = Players:GetPlayerByUserId(userId)
	if player then
		setGamePassOwned(player, gamePassId, owned)
	end

	return owned
end


--[[
@param     Player     player       | The player to prompt.
@param     number     productId    | The asset ID of the product.
@return    boolean    
@throws
@yields

Prompts the player to buy a product. Returns whether or not the product was purchased.
]]
function MonetizationService.promptProductPurchaseAsync(player: Player, productId: number): boolean
	return promptAssetPurchaseAsync(ASSET_CATEGORY.PRODUCT, player, productId)
end


--[[
@param     Player     player        | The player to prompt.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean    
@throws
@yields

Prompts the player to buy a game-pass. Returns whether or not the game-pass was purchased.
]]
function MonetizationService.promptGamePassPurchaseAsync(player: Player, gamePassId: number): boolean
	return promptAssetPurchaseAsync(ASSET_CATEGORY.GAME_PASS, player, gamePassId)
end


--[[
@param     Asset    gamePass    | The game-pass to register.
@return    void    
@throws
@yields

Attempts to register the game-pass to MonetizationService. If successful, attempts to
load the game-pass for all players.
]]
function MonetizationService.registerGamePassAsync(gamePass: Types.Asset)
	tryRegisterAssetAsync(ASSET_CATEGORY.GAME_PASS, gamePass)
end


--[[
@param     Asset    product    | The product to register.
@return    void    
@throws
@yields

Attempts to register the product to MonetizationService.
]]
function MonetizationService.registerProductAsync(product: Types.Asset)
	tryRegisterAssetAsync(ASSET_CATEGORY.PRODUCT, product)
end


--[[
@return    {Asset}    

Returns a copy of the game-pass assets. 
]]
function MonetizationService.getGamePasses(): {Types.Asset}
	return table.clone(categorizedAssets.GamePass)
end


--[[
@return    {Asset}    

Returns a copy of the product. 
]]
function MonetizationService.getProducts(): {Types.Asset}
	return table.clone(categorizedAssets.Product)
end


--[[
@param     number        gamePassId    | The game-pass ID to query.
@return    Asset?    

Returns a copy of the game-pass.
]]
function MonetizationService.getGamePass(gamePassId: number): Types.Asset?
	local gamePass = categorizedAssets.GamePass[gamePassId]
	if not gamePass then
		return
	end

	return table.clone(gamePass)
end


--[[
@param     number        productId    | The product ID to query.
@return    Asset?    

Returns a copy of the product.
]]
function MonetizationService.getProduct(productId: number): Types.Asset?
	local product = categorizedAssets.Product[productId]
	if not product then
		return
	end

	return table.clone(product)
end


--[[
@param     number         assetId    | The asset ID to query.
@return    {Asset}    

Returns a copy of the asset. 
]]
function MonetizationService.getAsset(assetId: number): Types.Asset?
	local asset = MonetizationService.getGamePass(assetId) or MonetizationService.getProduct(assetId)
	if not asset then
		return
	end

	return asset
end


--[[
@param     number     assetId    | The game-pass ID to query.
@return    boolean 

Returns whether or not the asset ID is recognized as a game-pass.
]]
function MonetizationService.isGamePass(assetId: number): boolean
	return categorizedAssets.GamePass[assetId] ~= nil
end


--[[
@param     number     assetId    | The product ID to query.
@return    boolean 

Returns whether or not the asset ID is recognized as a game-pass.
]]
function MonetizationService.isProduct(assetId: number): boolean
	return categorizedAssets.Product[assetId] ~= nil
end


--[[
@param     number     assetId    | The asset ID to query.
@return    boolean 

Returns whether or not the asset ID is recognized as an asset.
]]
function MonetizationService.isAsset(assetId: number): boolean
	return MonetizationService.isGamePass(assetId) or MonetizationService.isProduct(assetId)
end


--[[
@param     number    userId        | The user ID of the player.
@param     number    gamePassId    | The asset ID of the game-pass.
@return    void    
@throws
@yields

Attempts to give the player the game-pass.
]]
function MonetizationService.tryGiveGamePassAsync(userId: number, gamePassId: number)
	if MonetizationService.userOwnsGamePassAsync(userId, gamePassId) then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		onGamePassPurchaseFinished(player, gamePassId, true)
	end

	UnofficialGamePassOwners:UpdateAsync(userId, function(gamePassIds: SharedTypes.GamePassOwnershipMap)
		gamePassIds             = gamePassIds or {}
		gamePassIds[gamePassId] = true

		return gamePassIds
	end)
end


--[[
@param     Player    player       | The player to give the product.
@param     number    productId    | The asset ID of the product.
@return    void    
@throws

Attempts to give the player the product.
]]
function MonetizationService.tryGiveProduct(player: Player, productId: number)
	onProductPurchaseFinished({
		PlayerId  = player.UserId,
		ProductId = productId,
	})
end



Players.PlayerRemoving:Connect(deleteCache)

MarketplaceService.ProcessReceipt = onProductPurchaseFinished
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)


type GamePassOwnershipCache = {
	[Player]: SharedTypes.GamePassOwnershipMap,
}

type AssetMap = {
	[number]: Types.Asset,
}

type CategorizedAssets = {
	Product  : AssetMap,
	GamePass : AssetMap,
}



return table.freeze(MonetizationService)
