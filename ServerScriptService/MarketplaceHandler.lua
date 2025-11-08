local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataStoreAPI = require(script.Parent:WaitForChild("DataStoreAPI"))
local ItemDatabase = require(script.Parent:WaitForChild("ItemDatabase"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

local IS_STUDIO = RunService:IsStudio()

local MarketplaceDataStore = DataStoreService:GetDataStore("MarketplaceListings_v1")

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
remoteEventsFolder.Name = "RemoteEvents"
remoteEventsFolder.Parent = ReplicatedStorage

local createListingEvent = Instance.new("RemoteEvent")
createListingEvent.Name = "CreateListingEvent"
createListingEvent.Parent = remoteEventsFolder

local purchaseListingEvent = Instance.new("RemoteEvent")
purchaseListingEvent.Name = "PurchaseListingEvent"
purchaseListingEvent.Parent = remoteEventsFolder

local cancelListingEvent = Instance.new("RemoteEvent")
cancelListingEvent.Name = "CancelListingEvent"
cancelListingEvent.Parent = remoteEventsFolder

local getListingsFunction = Instance.new("RemoteFunction")
getListingsFunction.Name = "GetListingsFunction"
getListingsFunction.Parent = remoteEventsFolder

local validateGamepassFunction = Instance.new("RemoteFunction")
validateGamepassFunction.Name = "ValidateGamepassFunction"
validateGamepassFunction.Parent = remoteEventsFolder

local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification")
if not notificationEvent then
        notificationEvent = Instance.new("RemoteEvent")
        notificationEvent.Name = "CreateNotification"
        notificationEvent.Parent = remoteEventsFolder
end

local activeListings = {}
local ROBUX_TAX_RATE = 0.30

local function loadListings()
        local success, result = pcall(function()
                return MarketplaceDataStore:GetAsync("AllListings")
        end)
        
        if success and result then
                activeListings = result
                print("Loaded " .. #activeListings .. " marketplace listings")
        else
                activeListings = {}
                print("No existing listings or failed to load")
        end
end

local function saveListings()
        local success, err = pcall(function()
                MarketplaceDataStore:SetAsync("AllListings", activeListings)
        end)
        
        if not success then
                warn("Failed to save marketplace listings: " .. tostring(err))
        end
end

local function formatNumber(number)
        local formatted = tostring(number)
        local k
        while true do
                formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
                if k == 0 then
                        break
                end
        end
        return formatted
end

local function generateListingId()
        return game:GetService("HttpService"):GenerateGUID(false)
end

local function getPlayerData(player)
        return _G.PlayerData[player.UserId]
end

local function sendOrSaveNotification(userId, notification)
        local player = Players:GetPlayerByUserId(userId)
        
        if player then
                local maxRetries = 10
                local retryDelay = 0.1
                
                for attempt = 1, maxRetries do
                        local playerData = getPlayerData(player)
                        if playerData then
                                notificationEvent:FireClient(player, notification)
                                return true
                        end
                        
                        if attempt < maxRetries then
                                task.wait(retryDelay)
                        end
                end
                
                warn("Player " .. userId .. " is online but data not loaded after retries, saving to pending")
        end
        
        local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
        local HttpService = game:GetService("HttpService")
        
        local success, result = pcall(function()
                PlayerDataStore:UpdateAsync("Player_" .. userId, function(currentJsonData)
                        local playerData
                        
                        if not currentJsonData then
                                playerData = DataStoreManager:GetDefaultData()
                        else
                                playerData = HttpService:JSONDecode(currentJsonData)
                        end
                        
                        if not playerData.PendingNotifications then
                                playerData.PendingNotifications = {}
                        end
                        
                        table.insert(playerData.PendingNotifications, notification)
                        
                        return HttpService:JSONEncode(playerData)
                end)
                
                local onlinePlayer = Players:GetPlayerByUserId(userId)
                if onlinePlayer and _G.PlayerData[userId] then
                        if not _G.PlayerData[userId].PendingNotifications then
                                _G.PlayerData[userId].PendingNotifications = {}
                        end
                        table.insert(_G.PlayerData[userId].PendingNotifications, notification)
                end
                
                print("Saved pending notification for offline user " .. userId)
                return true
        end)
        
        if not success then
                warn("Failed to save pending notification for user " .. userId .. ": " .. tostring(result))
                return false
        end
        
        return result
end

local function findItemInInventory(player, robloxId, serialNumber)
        local data = getPlayerData(player)
        if not data then return nil, nil end
        
        for index, item in ipairs(data.Inventory) do
                if item.RobloxId == robloxId then
                        if serialNumber then
                                if item.SerialNumber == serialNumber then
                                        return item, index
                                end
                        else
                                if not item.SerialNumber then
                                        return item, index
                                end
                        end
                end
        end
        
        return nil, nil
end

createListingEvent.OnServerEvent:Connect(function(player, itemData, listingType, price, gamepassId)
        if not itemData or not listingType or not price then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Listing Failed",
                        Body = "Invalid listing data"
                })
                return
        end
        
        if itemData.Value < 250000 then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Cannot List Item",
                        Body = "Only items worth 250,000+ can be listed"
                })
                return
        end
        
        if listingType == "cash" then
                if price < 1 or price > 1000000000 then
                        notificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Invalid Price",
                                Body = "Cash price must be between $1 and $1,000,000,000"
                        })
                        return
                end
        elseif listingType == "robux" then
                if not gamepassId or gamepassId == "" then
                        notificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Invalid Gamepass",
                                Body = "Please enter a valid gamepass ID"
                        })
                        return
                end
                
                local validGamepass = false
                local productInfo = nil
                local success, result = pcall(function()
                        return MarketplaceService:GetProductInfo(tonumber(gamepassId), Enum.InfoType.GamePass)
                end)
                
                if success and result then
                        validGamepass = true
                        productInfo = result
                        price = productInfo.PriceInRobux or 0
                else
                        notificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Invalid Gamepass",
                                Body = "Could not verify gamepass ID"
                        })
                        return
                end
        else
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Invalid Listing Type",
                        Body = "Please choose cash or robux"
                })
                return
        end
        
        local item, itemIndex = findItemInInventory(player, itemData.RobloxId, itemData.SerialNumber)
        if not item then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Item Not Found",
                        Body = "You don't own this item"
                })
                return
        end
        
        local removeSuccess = false
        if item.Amount and item.Amount > 1 then
                removeSuccess = DataStoreAPI:RemoveItemAmount(player, itemData.RobloxId, 1)
        else
                removeSuccess = DataStoreAPI:RemoveItem(player, itemIndex)
        end
        
        if not removeSuccess then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Listing Failed",
                        Body = "Could not remove item from inventory"
                })
                return
        end
        
        local listing = {
                ListingId = generateListingId(),
                SellerUserId = player.UserId,
                SellerUsername = player.Name,
                ItemData = {
                        RobloxId = item.RobloxId,
                        Name = item.Name,
                        Value = item.Value,
                        Rarity = item.Rarity,
                        SerialNumber = item.SerialNumber,
                        Stock = itemData.Stock,
                        CurrentStock = itemData.CurrentStock
                },
                ListingType = listingType,
                Price = price,
                GamepassId = gamepassId,
                CreatedAt = os.time()
        }
        
        table.insert(activeListings, listing)
        saveListings()
        
        local priceText = ""
        if listingType == "cash" then
                priceText = "$" .. formatNumber(price)
        else
                local sellerReceives = math.floor(price * (1 - ROBUX_TAX_RATE))
                priceText = "R$" .. formatNumber(sellerReceives) .. " (after tax)"
        end
        
        notificationEvent:FireClient(player, {
                Type = "MARKET_LIST",
                Title = "Item Listed!",
                Body = item.Name .. " listed for " .. priceText,
                ImageId = item.RobloxId
        })
        
        local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
        if inventoryUpdatedEvent then
                inventoryUpdatedEvent:FireClient(player)
        end
end)

purchaseListingEvent.OnServerEvent:Connect(function(player, listingId)
        local listing = nil
        local listingIndex = nil
        
        for i, l in ipairs(activeListings) do
                if l.ListingId == listingId then
                        listing = l
                        listingIndex = i
                        break
                end
        end
        
        if not listing then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Purchase Failed",
                        Body = "This listing no longer exists"
                })
                return
        end
        
        local data = getPlayerData(player)
        if not data then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Purchase Failed",
                        Body = "Could not load your data"
                })
                return
        end
        
        if listing.ListingType == "cash" then
                if data.Cash < listing.Price then
                        notificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Insufficient Cash",
                                Body = "You need $" .. formatNumber(listing.Price) .. " to purchase this item"
                        })
                        return
                end
                
                data.Cash = data.Cash - listing.Price
                
                if player:FindFirstChild("leaderstats") then
                        local cash = player.leaderstats:FindFirstChild("Cash")
                        if cash then
                                cash.Value = data.Cash
                        end
                end
                
                local seller = game.Players:GetPlayerByUserId(listing.SellerUserId)
                if seller then
                        local sellerData = getPlayerData(seller)
                        if sellerData then
                                sellerData.Cash = sellerData.Cash + listing.Price
                                
                                if seller:FindFirstChild("leaderstats") then
                                        local sellerCash = seller.leaderstats:FindFirstChild("Cash")
                                        if sellerCash then
                                                sellerCash.Value = sellerData.Cash
                                        end
                                end
                        end
                end
                
                sendOrSaveNotification(listing.SellerUserId, {
                        Type = "MARKET_SOLD",
                        Title = "Item Sold!",
                        Body = listing.ItemData.Name .. " sold for $" .. formatNumber(listing.Price),
                        ImageId = listing.ItemData.RobloxId
                })
        elseif listing.ListingType == "robux" then
                local ownsGamepass = false
                
                if IS_STUDIO then
                        print("⚠️ STUDIO MODE: Bypassing gamepass validation for testing purposes")
                        print("⚠️ In production, gamepass ownership will be properly validated")
                        ownsGamepass = true
                else
                        local success, result = pcall(function()
                                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(listing.GamepassId))
                        end)
                        
                        if success and result then
                                ownsGamepass = true
                        end
                        
                        if not ownsGamepass then
                                notificationEvent:FireClient(player, {
                                        Type = "ERROR",
                                        Title = "Purchase Failed",
                                        Body = "You must own gamepass ID " .. listing.GamepassId .. " to complete this purchase"
                                })
                                return
                        end
                end
                
                local sellerReceives = math.floor(listing.Price * (1 - ROBUX_TAX_RATE))
                sendOrSaveNotification(listing.SellerUserId, {
                        Type = "MARKET_SOLD",
                        Title = "Item Sold!",
                        Body = listing.ItemData.Name .. " sold for R$" .. formatNumber(sellerReceives) .. " (after tax)",
                        ImageId = listing.ItemData.RobloxId
                })
        end
        
        local itemToAdd = {
                RobloxId = listing.ItemData.RobloxId,
                Name = listing.ItemData.Name,
                Value = listing.ItemData.Value,
                Rarity = listing.ItemData.Rarity,
                SerialNumber = listing.ItemData.SerialNumber,
                Amount = 1
        }
        
        DataStoreAPI:AddItem(player, itemToAdd, true)
        
        table.remove(activeListings, listingIndex)
        saveListings()
        
        local priceText = ""
        if listing.ListingType == "cash" then
                priceText = "$" .. formatNumber(listing.Price)
        else
                priceText = "R$" .. formatNumber(listing.Price)
        end
        
        notificationEvent:FireClient(player, {
                Type = "MARKET_PURCHASE",
                Title = "Purchase Complete!",
                Body = "You bought " .. listing.ItemData.Name .. " for " .. priceText,
                ImageId = listing.ItemData.RobloxId
        })
        
        local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
        if inventoryUpdatedEvent then
                inventoryUpdatedEvent:FireClient(player)
        end
end)

cancelListingEvent.OnServerEvent:Connect(function(player, listingId)
        local listing = nil
        local listingIndex = nil
        
        for i, l in ipairs(activeListings) do
                if l.ListingId == listingId then
                        listing = l
                        listingIndex = i
                        break
                end
        end
        
        if not listing then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Cancellation Failed",
                        Body = "This listing no longer exists"
                })
                return
        end
        
        if listing.SellerUserId ~= player.UserId then
                notificationEvent:FireClient(player, {
                        Type = "ERROR",
                        Title = "Cancellation Failed",
                        Body = "You can only cancel your own listings"
                })
                return
        end
        
        local itemToReturn = {
                RobloxId = listing.ItemData.RobloxId,
                Name = listing.ItemData.Name,
                Value = listing.ItemData.Value,
                Rarity = listing.ItemData.Rarity,
                SerialNumber = listing.ItemData.SerialNumber,
                Amount = 1
        }
        
        DataStoreAPI:AddItem(player, itemToReturn, true)
        
        table.remove(activeListings, listingIndex)
        saveListings()
        
        notificationEvent:FireClient(player, {
                Type = "VICTORY",
                Title = "Listing Cancelled",
                Body = listing.ItemData.Name .. " returned to your inventory"
        })
        
        local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
        if inventoryUpdatedEvent then
                inventoryUpdatedEvent:FireClient(player)
        end
end)

getListingsFunction.OnServerInvoke = function(player)
        local listingsWithOwnership = {}
        
        for _, listing in ipairs(activeListings) do
                local listingCopy = {}
                for k, v in pairs(listing) do
                        listingCopy[k] = v
                end
                listingCopy.IsOwnListing = (listing.SellerUserId == player.UserId)
                table.insert(listingsWithOwnership, listingCopy)
        end
        
        return listingsWithOwnership
end

validateGamepassFunction.OnServerInvoke = function(player, gamepassId)
        if not gamepassId or gamepassId == "" then
                return false, 0
        end
        
        local success, productInfo = pcall(function()
                return MarketplaceService:GetProductInfo(tonumber(gamepassId), Enum.InfoType.GamePass)
        end)
        
        if success and productInfo then
                return true, productInfo.PriceInRobux or 0
        else
                return false, 0
        end
end

loadListings()

print("MarketplaceHandler loaded successfully")
