--[[
Author     Ziffixture (74087102)
Date       04/14/2025 (MM/DD/YYYY)
Version    2.1.7
]]



--!strict
type ButtonContainer = ImageLabel & {
	Button : GuiButton,
}



local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local SoundService       = game:GetService("SoundService")
local Players            = game:GetService("Players")


local GREYED_OUT_COLOR = Color3.fromRGB(165, 165, 165)
local FULL_COLOR       = Color3.fromRGB(255, 255, 255)
local RBX_PREFIX       = "rbxassetid://"


local Vendor  = ReplicatedStorage:WaitForChild("Vendor")
local Connect = require(Vendor:WaitForChild("Connect")) 

local Player = Players.LocalPlayer

local SoundEffects = SoundService:WaitForChild("SFX")

local MonetizationFeature    = ReplicatedStorage:WaitForChild("Monetization")
local MonetizationController = require(MonetizationFeature:WaitForChild("Controller"))
local MonetizationTypes      = require(MonetizationFeature:WaitForChild("Types"))
local MonetizationRemotes    = MonetizationFeature:WaitForChild("Remotes")

local GiftFeature = MonetizationFeature:WaitForChild("Gifting")
local GiftTypes   = require(GiftFeature:WaitForChild("Types"))

local GiftFeature = MonetizationFeature:WaitForChild("Gifting")
local GiftRemotes = GiftFeature:WaitForChild("Remotes")

local GamePassFrame     = script.Parent
local GamePassTemplate  = script:WaitForChild("GamePass")

local PurchaseFrame      = GamePassFrame:WaitForChild("PurchaseFrame")
local GiftFrame          = GamePassFrame:WaitForChild("GiftFrame")
local GiftOptionTemplate = script:WaitForChild("GiftOption")

local PlayerGui      = Player:WaitForChild("PlayerGui")
local DiamondCounter = PlayerGui:WaitForChild("DiamondCounter")
local DiamondFrame   = DiamondCounter:WaitForChild("ShopFrame")

local Types = require(script:WaitForChild("Types"))


local assetId

local connections = {} :: any
connections.Purchase = {}
connections.Gift     = {}



local function onButtonActivated(buttonContainer: ButtonContainer, callback: () -> ()): RBXScriptConnection
	return buttonContainer.Button.Activated:Connect(function()
		SoundEffects.ClickSound:Play()

		callback()
	end)
end

local function setButtonEnabled(buttonContainer: ButtonContainer, enabled: boolean)
	buttonContainer.Button.Interactable = enabled
	buttonContainer.ImageColor3         = enabled and FULL_COLOR or GREYED_OUT_COLOR
end

local function getUserHeashotAsync(userId: number): string?
	local image, isReady = Players:GetUserThumbnailAsync(
		userId, 
		Enum.ThumbnailType.HeadShot, 
		Enum.ThumbnailSize.Size420x420
	)

	return isReady and image
end

local function getUserIdFromNameAsync(name: string): number?
	local success, userId = pcall(Players.GetUserIdFromNameAsync, Players, name)
	
	return success and userId
end

local function promptGiftRecipient(giftOption: Types.GiftOptionGui, userId: number)
	local scrollingContainer = GiftFrame.ScrollingContainer
	local scrollingFrame     = scrollingContainer.ScrollingFrame
	
	local wasGifted, shouldDestroy = GiftRemotes.BeginGift:InvokeServer(userId, assetId)
	if not (wasGifted and shouldDestroy) then
		setButtonEnabled(giftOption.GiftContainer, true)
		
		return
	end
	
	if shouldDestroy then
		giftOption:Destroy()
	end
end

local function generateGiftOption(recipient: GiftTypes.Recipient): Frame
	local giftOption = GiftOptionTemplate:Clone()
	giftOption.Name = recipient.UserId

	local playerContainer = giftOption.PlayerContainer
	playerContainer.UsernameContainer.Username.Text = recipient.Username 
	playerContainer.DisplayName.Text                = recipient.DisplayName

	task.defer(function()
		local headshot = getUserHeashotAsync(recipient.UserId)
		if headshot then
			giftOption.HeadshotContainer.Headshot.Image = headshot
		end
	end)

	onButtonActivated(giftOption.GiftContainer, function()
		setButtonEnabled(giftOption.GiftContainer, false)
		promptGiftRecipient(giftOption, recipient.UserId)
	end)
	
	return giftOption
end

local function getEligibleGiftOptions(protocol: "Domestic" | "Query", ...): {Types.GiftOptionGui}
	local recipients = GiftRemotes.GetEligibleRecipients:InvokeServer(protocol, assetId, ...)
	local results = {}
	
	for _, recipient in recipients do
		table.insert(results, generateGiftOption(recipient))
	end
	
	return results
end

local function loadGiftOptions(giftOptions: {Types.GiftOptionGui})
	Connect.clean(connections.Gift)
	
	local scrollingContainer = GiftFrame.ScrollingContainer
	local scrollingFrame     = scrollingContainer.ScrollingFrame
	
	for _, child in scrollingFrame:GetChildren() do
		if child.ClassName == "Frame" then
			child:Destroy()
		end
	end

	for _, giftOption in giftOptions do
		giftOption.Parent = scrollingFrame
	end
end

local function onGamePassOwned(gamePass: MonetizationTypes.AssetData)
	local gui = GamePassFrame.GamePassContainer:FindFirstChild(gamePass.Name)
	if not gui then
		return
	end

	gui.Owned.Visible = true

	setButtonEnabled(PurchaseFrame.PurchaseContainer, gamePass.Id ~= assetId)
end

local function viewGamePass(gamePass: MonetizationTypes.AssetData)
	Connect.clean(connections.Purchase)

	assetId = gamePass.Id
	
	PurchaseFrame.CostContainer.TextLabel.Text = gamePass.Price or "N/A"
	PurchaseFrame.Description.Text             = gamePass.Description or "N/A"
	PurchaseFrame.Title.Text                   = gamePass.DisplayName
	
	local owned = MonetizationController.localUserOwnsGamePassAsync(gamePass.Id)
	if not owned then
		connections.Purchase.PurchaseButton = onButtonActivated(PurchaseFrame.PurchaseContainer, function()
			MarketplaceService:PromptGamePassPurchase(Player, assetId)
		end)
	end
	
	local giftId = gamePass.Metadata.GiftId
	if giftId then
		connections.Purchase.GiftButton = onButtonActivated(PurchaseFrame.GiftContainer, function()
			loadGiftOptions(getEligibleGiftOptions("Domestic"))
			
			GiftFrame.Title.Text  = gamePass.DisplayName
			GiftFrame.Image.Image = RBX_PREFIX .. gamePass.Metadata.ImageId
			GiftFrame.Parent      = GamePassFrame
			
			GiftFrame.Visible = true
		end)
	end
	
	setButtonEnabled(PurchaseFrame.PurchaseContainer, not owned)
	setButtonEnabled(PurchaseFrame.GiftContainer, giftId ~= nil)
	
	PurchaseFrame.Visible = true
end

local function loadGamePass(gamePass: MonetizationTypes.AssetData)
	if GamePassFrame.GamePassContainer:FindFirstChild(gamePass.Name) then
		return
	end
	
	if not gamePass.Metadata then
		warn(`Game-pass {gamePass.Id} is lacking metadata field.`)

		return
	end
	
	local owned = MonetizationController.localUserOwnsGamePassAsync(gamePass.Id)
	
	local gui = GamePassTemplate:Clone()
	gui.Name          = gamePass.Name
	gui.LayoutOrder   = gamePass.Metadata.LayoutOrder
	gui.Title.Text    = gamePass.DisplayName
	gui.Owned.Visible = owned
	gui.Button.Image  = RBX_PREFIX .. gamePass.Metadata.ImageId
	gui.Parent        = GamePassFrame.GamePassContainer
	
	onButtonActivated(gui, function()
		viewGamePass(gamePass)
	end)
	
	if owned then
		onGamePassOwned(gamePass)
	end
end

local function handleGamePassLoading()
	GamePassFrame.GamePassContainer.ChildAdded:Once(function()
		GamePassFrame.NoResults.Visible = false
	end)
	
	MonetizationRemotes.GamePassRegistered.OnClientEvent:Connect(loadGamePass)
end

local function handleScrollingContainer()
	local scrollingContainer = GiftFrame.ScrollingContainer
	local scrollingFrame     = scrollingContainer.ScrollingFrame
	
	local function update()
		local absoluteContentSize = scrollingFrame.UIListLayout.AbsoluteContentSize
		local canvasSize          = UDim2.fromOffset(absoluteContentSize.X, absoluteContentSize.Y)

		scrollingFrame.CanvasSize            = canvasSize
		scrollingContainer.NoResults.Visible = #scrollingFrame:GetChildren() - 1 == 0
	end
	
	update()
	
	scrollingFrame.ChildRemoved:Connect(update)
	scrollingFrame.ChildAdded:Connect(update)
end

local function handleUserSearching()
	local searchContainer = GiftFrame.SearchContainer
	local textBox         = searchContainer.TextBox
	
	local function search()
		local giftOptions = {}

		local username = textBox.Text
		local userId   = getUserIdFromNameAsync(username)

		if not userId then
			return
		end

		textBox.Text = ""

		loadGiftOptions(getEligibleGiftOptions("Query", userId))
	end

	textBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			SoundEffects.ClickSound:Play()
			
			search()
		end
	end)
	
	onButtonActivated(searchContainer, search)
end

local function handleDiamonds()
	for _, product in DiamondFrame.ScrollingFrame:GetChildren() do
		if product.ClassName == "UIGridLayout" then
			continue
		end
		
		local productId = product.ProductId.Value
		
		onButtonActivated(product.Gift, function()
			assetId = productId
			
			loadGiftOptions(getEligibleGiftOptions("Domestic"))
			
			GiftFrame.Title.Text  = product.Name
			GiftFrame.Image.Image = product.diamondgain.diamondimg.Image
			GiftFrame.Parent      = DiamondFrame

			GiftFrame.Visible = true
		end)
		
		onButtonActivated(product.Purchase, function()
			MarketplaceService:PromptProductPurchase(Player, productId)
		end)
	end
end



handleScrollingContainer()
handleUserSearching()
handleGamePassLoading()
handleDiamonds()


MonetizationRemotes.GamePassOwned.OnClientEvent:Connect(onGamePassOwned)
