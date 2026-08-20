--[[
Author     Ziffix (74087102)
Date       08/18/2026 (MM/DD/YYYY)
Version    2.3.1
]]



--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")


local Vendor = ReplicatedStorage.Vendor
local Signal = require(Vendor.Signal)


const NOT_PROCESSED_YET = Enum.ProductPurchaseDecision.NotProcessedYet
const PURCHASE_GRANTED  = Enum.ProductPurchaseDecision.PurchaseGranted

const PRODUCT   = Enum.InfoType.Product
const GAME_PASS = Enum.InfoType.GamePass


local Feature       = script.Parent
local Types         = require(Feature.Types)
local Configuration = require(Feature.Configuration)

local MonetizationService = {}
MonetizationService.AssetRegistered    = Signal.new() :: Types.AssetRegisteredSignal
MonetizationService.ProductRegistered  = Signal.new() :: Types.AssetRegisteredSignal
MonetizationService.GamePassRegistered = Signal.new() :: Types.AssetRegisteredSignal
MonetizationService.GamePassOwned      = Signal.new() :: Types.GamePassOwnedSignal


local unofficialGamePassOwners = DataStoreService:GetDataStore("unofficialGamePassOwners", "Production")

local categorizedAssets = {} :: CategorizedAssets
categorizedAssets[PRODUCT]   = {}
categorizedAssets[GAME_PASS] = {}

local categorizedPromptThreads = {} :: CategorizedPromptThreads
categorizedPromptThreads[PRODUCT]   = {}
categorizedPromptThreads[GAME_PASS] = {}

local gamePassOwnershipCache = {} :: GamePassOwnershipCache
local assetRegisteredSignals = {} :: {Signal.Signal<Types.Asset>}



local function getCache(player: Player)
	if not gamePassOwnershipCache[player] then
		gamePassOwnershipCache[player] = {}
	end

	return gamePassOwnershipCache[player]
end

local function deleteCache(player: Player)
	gamePassOwnershipCache[player] = nil
end

local function setGamePassOwned(player: Player, gamePassId: number, owned: boolean)
	getCache(player)[gamePassId] = owned

	if owned then
		MonetizationService.GamePassOwned:Fire(player, MonetizationService.getGamePass(gamePassId))
	end
end

local function ownsGamePassInCache(userId: number, gamePassId: number): boolean
	local player = Players:GetPlayerByUserId(userId :: any)
	if not player then
		return false
	end

	return getCache(player)[gamePassId]
end

local function ownsGamePassUnofficiallyAsync(userId: number, gamePassId: number): boolean
	local gamePassIds = unofficialGamePassOwners:GetAsync(tostring(userId)) :: Types.GamePassOwnershipMap
	if not gamePassIds then
		return false
	end

	-- JSON encodes numerical keys to strings.
	return gamePassIds[tostring(gamePassId)] ~= nil
end

local function ownsGamePassInStudio(userId: number, gamePassId: number): boolean
	return RunService:IsStudio() 
		and Players:GetPlayerByUserId(userId :: any)
		and Configuration.OWNS_GAME_PASSES_IN_STUDIO
end

local function ownsGamePassAsync(userId: number, gamePassId: number): boolean
	return ownsGamePassInStudio(userId, gamePassId)
		or ownsGamePassInCache(userId, gamePassId)
		or MarketplaceService:UserOwnsGamePassAsync(userId :: any, gamePassId) 
		or ownsGamePassUnofficiallyAsync(userId, gamePassId)
end

local function tryRunHandler(asset: Types.Asset, ...)
	if asset.Handler then
		asset.Handler(...)
	end
end

local function tryResumeAssetPromptThreads(category: Enum.InfoType, assetId: number, wasPurchased: boolean)
	local threads = categorizedPromptThreads[category][assetId]
	if not threads then
		return
	end

	for _, thread in threads do
		coroutine.resume(thread, wasPurchased)
	end
end

local function onGamePassPurchaseFinished(player: Instance, gamePassId: number, wasPurchased: boolean)
	local gamePass = categorizedAssets[GAME_PASS][gamePassId]
	if not gamePass then
		warn(`Unregistered game-pass {gamePassId}.`)

		return
	end

	if wasPurchased then
		setGamePassOwned(player :: Player, gamePassId, true)
		tryRunHandler(gamePass, player)
	end

	tryResumeAssetPromptThreads(
		GAME_PASS, 
		gamePassId, 
		wasPurchased
	)
end

local function onProductPurchaseFinished(receipt: Types.ProductReceipt): Enum.ProductPurchaseDecision
	local product = categorizedAssets[PRODUCT][receipt.ProductId]
	if not product then
		warn(`Unregistered product {receipt.ProductId}.`)

		return NOT_PROCESSED_YET
	end

	local player       = Players:GetPlayerByUserId(receipt.PlayerId :: any)
	local wasPurchased = player ~= nil

	if wasPurchased then
		tryRunHandler(product, player, receipt)
	end

	tryResumeAssetPromptThreads(
		PRODUCT, 
		receipt.ProductId, 
		wasPurchased
	)

	return wasPurchased and PURCHASE_GRANTED or NOT_PROCESSED_YET
end

local function getPriceInRobuxAsync(assetId: number, infoType: Enum.InfoType): number?
	local success, response = pcall(function()
		return MarketplaceService:GetProductInfoAsync(assetId, infoType)
	end)

	if not success then
		warn(`Price retrieval failure for {infoType.Name} {assetId}; {response}`)

		return nil
	end

	return response.PriceInRobux
end

local function tryRegisterAssetAsync(category: Enum.InfoType, asset: Types.Asset)
	local assetId = asset.Id
	
	do
		local assets = categorizedAssets[category]
		if assets[assetId] then
			error(`{category.Name} {assetId} has already been implemented.`)
		end

		asset.Price     = getPriceInRobuxAsync(assetId, category)
		asset.Category  = category
		assets[assetId] = table.clone(asset)
	end

	do
		local registration: Types.AssetRegisteredSignal
		
		if category == PRODUCT then
			registration = MonetizationService.ProductRegistered
		elseif category == GAME_PASS then
			registration = MonetizationService.GamePassRegistered
		end
		
		registration:Fire(table.clone(asset))

		MonetizationService.AssetRegistered:Fire(table.clone(asset))
	end

	do
		local assetRegisteredSignal = assetRegisteredSignals[assetId]
		if not assetRegisteredSignal then
			return
		end

		assetRegisteredSignal:Fire(table.clone(asset))
		assetRegisteredSignal:Destroy()

		assetRegisteredSignals[assetId] = nil
	end
end

local function promptAssetPurchaseAsync(category: Enum.InfoType, player: Player, assetId: number): boolean
	local thread  = coroutine.running()
	local threads = categorizedPromptThreads[category]

	if not threads[assetId] then
		threads[assetId] = { thread }
	else
		table.insert(threads[assetId], thread)
	end

	local prompt: any

	if category == PRODUCT then
		prompt = MarketplaceService.PromptProductPurchase
	elseif category == GAME_PASS then
		prompt = MarketplaceService.PromptGamePassPurchase
	end

	prompt(MarketplaceService, player, assetId)

	return coroutine.yield()
end

function MonetizationService.listenForAssetRegistered(assetId: number, callback: (asset: Types.Asset) -> ()): Signal.Connection<>
	if MonetizationService.isAsset(assetId) then
		error(`Asset {assetId} is already registered.`)
	end

	if not assetRegisteredSignals[assetId] then
		assetRegisteredSignals[assetId] = Signal.new()
	end

	return assetRegisteredSignals[assetId]:Once(callback)
end

function MonetizationService.awaitAssetsAsync(assetIds: {number})
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

function MonetizationService.tryLoadGamePassAsync(player: Player, gamePass: Types.Asset)
	if MonetizationService.userOwnsGamePassAsync(player.UserId, gamePass.Id) then
		task.spawn(tryRunHandler, gamePass, player)
	end
end

function MonetizationService.tryLoadGamePassForAllAsync(gamePass: Types.Asset)
	for _, player in Players:GetPlayers() do
		MonetizationService.tryLoadGamePassAsync(player, gamePass)
	end
end

function MonetizationService.userOwnsGamePassAsync(userId: number, gamePassId: number): boolean
	local owned = ownsGamePassAsync(userId, gamePassId)

	local player = Players:GetPlayerByUserId(userId :: any)
	if player then
		setGamePassOwned(player, gamePassId, owned)
	end

	return owned
end

function MonetizationService.promptProductPurchaseAsync(player: Player, productId: number): boolean
	return promptAssetPurchaseAsync(PRODUCT, player, productId)
end

function MonetizationService.promptGamePassPurchaseAsync(player: Player, gamePassId: number): boolean
	return promptAssetPurchaseAsync(GAME_PASS, player, gamePassId)
end

function MonetizationService.registerGamePassAsync(gamePass: Types.Asset)
	tryRegisterAssetAsync(GAME_PASS, gamePass)
end

function MonetizationService.registerProductAsync(product: Types.Asset)
	tryRegisterAssetAsync(PRODUCT, product)
end

function MonetizationService.getGamePasses(): {Types.Asset}
	return table.clone(categorizedAssets[GAME_PASS])
end

function MonetizationService.getProducts(): {Types.Asset}
	return table.clone(categorizedAssets[PRODUCT])
end

function MonetizationService.getGamePass(gamePassId: number): Types.Asset?
	local gamePass = categorizedAssets[GAME_PASS][gamePassId]
	if not gamePass then
		return nil
	end

	return table.clone(gamePass)
end

function MonetizationService.getProduct(productId: number): Types.Asset?
	local product = categorizedAssets[PRODUCT][productId]
	if not product then
		return nil
	end

	return table.clone(product)
end

function MonetizationService.getAsset(assetId: number): Types.Asset?
	local asset = MonetizationService.getGamePass(assetId) or MonetizationService.getProduct(assetId)
	if not asset then
		return nil
	end

	return asset
end

function MonetizationService.isGamePass(assetId: number): boolean
	return categorizedAssets[GAME_PASS][assetId] ~= nil
end

function MonetizationService.isProduct(assetId: number): boolean
	return categorizedAssets[PRODUCT][assetId] ~= nil
end

function MonetizationService.isAsset(assetId: number): boolean
	return MonetizationService.isGamePass(assetId) or MonetizationService.isProduct(assetId)
end

function MonetizationService.tryGiveGamePassAsync(userId: number, gamePassId: number)
	if MonetizationService.userOwnsGamePassAsync(userId, gamePassId) then
		return
	end

	local player = Players:GetPlayerByUserId(userId :: any)
	if player then
		onGamePassPurchaseFinished(player, gamePassId, true)
	end

	unofficialGamePassOwners:UpdateAsync(tostring(userId), function(gamePassIds: Types.GamePassOwnershipMap)
		gamePassIds             = gamePassIds or {}
		gamePassIds[gamePassId] = true

		return gamePassIds
	end)
end

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
	[Player]: Types.GamePassOwnershipMap,
}

type AssetMap = {
	[number]: Types.Asset,
}

type PromptThreadMap = {
	[number]: {thread},
}

type CategorizedAssets = {
	[Enum.InfoType]: AssetMap,
}

type CategorizedPromptThreads = {
	[Enum.InfoType]: PromptThreadMap,
}



return MonetizationService
