--[[
Author     Ziffix (74087102)
Date       23/10/20
Version    1.2.0
]]



--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")


local ASSETS       = script:WaitForChild("Assets")
local ASSET_LOOKUP = {} :: AssetLookup -- Initialized by the "boostrapAssets" function.

local NOT_PROCESSED_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local PURCHASE_GRANTED  = Enum.ProductPurchaseDecision.PurchaseGranted


local MarketplaceManager = {}


local gamePassOwnerCache = {}



--[[
@return    void
@throws

Processes the GamePasses and DeveloperProducts child folders into a lookup table.
]]
local function boostrapAssets()
	assert(ASSETS:FindFirstChild("GamePass"), "Could not find GamePass directory.")
	assert(ASSETS:FindFirstChild("DeveloperProduct"), "Could not find DeveloperProduct directory.")

	for _, directory in ASSETS:GetChildren() do
		local directoryData = {}

		for _, module in directory:GetChildren() do
			local assetData = require(module) :: AssetData
			
			directoryData[assetData.Id] = assetData
		end

		ASSET_LOOKUP[directory.Name] = directoryData
	end
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

	local gamePass = ASSET_LOOKUP.GamePass[gamePassId]
	if not gamePass then
		warn(`Unregistered game-pass {gamePassId}.`)

		return
	end

	gamePassOwnerCache[player.UserId] = true
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

	local developerProduct = ASSET_LOOKUP.DeveloperProduct[receipt.ProductId]
	if not developerProduct then
		warn(`Unregistered developer product {receipt.ProductId}.)

		return NOT_PROCESSED_YET
	end

	task.spawn(developerProduct.Handler, player)

	return PURCHASE_GRANTED
end


--[[
@param     Player    player    | The player who entered the server.
@return    void
@throws

Calls the game-pass handler function of all game-passes owned by the given player.
]]
local function onPlayerAdded(player: Player)
	local userId = player.UserId

	for _, gamePass in ASSET_LOOKUP.GamePass do
		if MarketplaceManager.userOwnsGamePass(userId, gamePass.Id) then
			task.spawn(gamePass.Handler, player)
		end
	end
end


--[[
@param     Player    player    | The player who is leaving the server.
@return    void

Clears the given player from the "gamePassOwnerCache".
]]
local function onPlayerRemoving(player: Player)
	gamePassOwnerCache[player.UserId] = nil
end


--[[
@param     number     userId        | The user ID of the player.
@param     number     gamePassId    | The asset ID of the game-pass.
@return    boolean    
@throws

Acts as a wrapper function to MarketplaceService:UserOwnsGamePassAsync, where Roblox's static cache is
replaced with a dynamic cache.
]]
function MarketplaceManager.userOwnsGamePassAsync(userId: number, gamePassId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end

	if not gamePassOwnerCache[userId] then
		gamePassOwnerCache[userId] = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end

	return gamePassOwnerCache[userId]
end



type AssetData = {
	Id      : number,
	Name    : string,
	Handler : (Player) -> (),
}

type AssetLookup = {
	GamePass         : {AssetData},
	DeveloperProduct : {AssetData},
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


boostrapAssets()

MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
MarketplaceService.ProcessReceipt = onDeveloperProductPurchaseFinished

if RunService:IsStudio() then
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)


return table.freeze(MarketplaceManager)
