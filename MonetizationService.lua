--[[
Author     Ziffixture (74087102)
Date       02/01/2025 (MM/DD/YYYY)
Version    2.2.4
]]



--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")


local NOT_PROCESSED_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local PURCHASE_GRANTED  = Enum.ProductPurchaseDecision.PurchaseGranted


local UnofficialGamePassOwners = DataStoreService:GetDataStore("UnofficialGamePassOwners", "Test1") 

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

local categorizedAssets = {} :: CategorizedAssets
categorizedAssets.GamePass = {}
categorizedAssets.Product  = {}

local gamePassOwnershipCache = {} :: GamePassOwnershipCache
local assetRegisteredSignals = {} :: {Signal.Signal<Types.AssetData>}



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
@throws
@yields

Returns whether or not the game-pass is owned unofficially.
]]
local function ownsGamePassUnofficiallyAsync(userId: number, gamePassId: number): boolean
	local gamePassIds = UnofficialGamePassOwners:GetAsync(userId) :: SharedTypes.GamePassOwnershipMap
	if not gamePassIds then
		return false
	end

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
	if RunService:IsStudio() 
		and Players:GetPlayerByUserId(userId)
		and Configuration.OwnGamePassesInStudio.Value 
	then
		return true
	end

	return false
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
		or MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) 
		or ownsGamePassUnofficiallyAsync(userId, gamePassId)
end




--[[
@param     AssetData    asset    | The asset whose handler to run.
@param     ...
@return    void

If present, runs the asset's handler function.
]]
local function tryRunHandler(asset: Types.AssetData, ...)
	if asset.Handler then
		asset.Handler(...)
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
	if not wasPurchased then
		return
	end

	local gamePass = categorizedAssets.GamePass[gamePassId]
	if not gamePass then
		warn(`Unregistered game-pass {gamePassId}.`)

		return
	end

	setGamePassOwned(player, gamePassId, true)
	tryRunHandler(gamePass, player)
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
		warn(`Unregistered product {receipt.ProductId}.`)

		return NOT_PROCESSED_YET
	end

	tryRunHandler(product, player)

	return PURCHASE_GRANTED
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
@throws
@yields

Attempts to register the asset to MonetizationService.
]]
local function tryRegisterAssetAsync(asset: Types.AssetData, category: keyof<CategorizedAssets>)
	local assets = categorizedAssets[category]
	if assets[asset.Id] then
		error(`{category} {asset.Id} has already been implemented.`)
	end

	asset.Price      = getPriceInRobuxAsync(asset.Id, Enum.InfoType[category])
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
@param     number                 assetId    | The asset ID.
@return    Signal.Connection<>    
@throws

Schedules a callback for the registration of a particular asset.
]]
function MonetizationService.listenForAssetRegistered(assetId: number, callback: (asset: Types.AssetData) -> ()): Signal.Connection<>
	if MonetizationService.isAsset(assetId) then
		error(`Asset {assetId} is already registered.`)
	end
	
	if not assetRegisteredSignals[assetId] then
		assetRegisteredSignals[assetId] = Signal.new()
	end

	return assetRegisteredSignals[assetId]:Connect(callback)
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

	for _, assetId in assetIds do
		if MonetizationService.isAsset(assetId) then
			continue
		end

		MonetizationService.listenForAssetRegistered(assetId, function()
			tasks -= 1
			if tasks == 0 then
				coroutine.resume(thread)
			end
		end)

		tasks += 1
	end

	if tasks > 0 then
		coroutine.yield()
	end
end


--[[
@param     Player       player      | The owner of the game-pass.
@param     AssetData    gamePass    | The game-pass to load.
@return    void
@throws
@yields

Attempts to run the game-pass' handler function on the given player.
]]
function MonetizationService.tryLoadGamePassAsync(player: Player, gamePass: Types.AssetData)
	if MonetizationService.userOwnsGamePassAsync(player.UserId, gamePass.Id) then
		task.defer(tryRunHandler, gamePass, player)
	end
end


--[[
@param     AssetData    gamePass    | The game-pass to load.
@return    void
@throws
@yields

Attempts to run the game-pass' handler function on all players.
]]
function MonetizationService.tryLoadGamePassForAllAsync(gamePass: Types.AssetData)
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

Prompts the player to buy a product. Returns whether or not the product was purchased
]]
function MonetizationService.promptProductPurchaseAsync(player: Player, productId: number): boolean
	local connection: RBXScriptConnection
	local finished = Signal.new()
	
	connection = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, wasPurchased: boolean)
		if userId ~= player.UserId then
			return
		end
		
		if productId ~= productId then
			return
		end

		connection:Disconnect()
		finished:Fire(wasPurchased)
	end)
	
	MarketplaceService:PromptProductPurchase(player, productId)
	
	return finished:Wait()
end


--[[
@param     AssetData    gamePass    | The game-pass to register.
@return    void    
@throws
@yields

Attempts to register the game-pass to MonetizationService. If successful, attempts to
load the game-pass for all players.
]]
function MonetizationService.registerGamePassAsync(gamePass: Types.AssetData)
	tryRegisterAssetAsync(gamePass, "GamePass")
end


--[[
@param     AssetData    product    | The product to register.
@return    void    
@throws
@yields

Attempts to register the product to MonetizationService.
]]
function MonetizationService.registerProductAsync(product: Types.AssetData)
	tryRegisterAssetAsync(product, "Product")
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

Returns a copy of the product. 
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
@param     number         assetId    | The asset ID to query.
@return    {AssetData}    

Returns a copy of the asset. 
]]
function MonetizationService.getAsset(assetId: number): Types.AssetData?
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
	local gamePass = categorizedAssets.GamePass[gamePassId]
	if not gamePass then
		error(`Unregistered game-pass {gamePassId}`)
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		setGamePassOwned(player, gamePassId, true)

		MonetizationService.tryLoadGamePassAsync(player, gamePass)
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

Attempts to give the player the game-pass.
]]
function MonetizationService.tryGiveProduct(player: Player, productId: number)
	local product = categorizedAssets.Product[productId]
	if not product then
		error(`Unregistered product {product}`)
	end

	task.defer(tryRunHandler, product, player)
end



Players.PlayerRemoving:Connect(deleteCache)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
MarketplaceService.ProcessReceipt = onProductPurchaseFinished


type GamePassOwnershipCache = {
	[Player]: SharedTypes.GamePassOwnershipMap,
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


return table.freeze(MonetizationService)
