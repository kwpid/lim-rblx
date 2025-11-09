local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TixShopDatabase = require(ReplicatedStorage:WaitForChild("TixShopDatabase"))
local DataStoreAPI = require(script.Parent:WaitForChild("DataStoreAPI"))
local ItemDatabase = require(script.Parent:WaitForChild("ItemDatabase"))

local ROTATION_INTERVAL = 3600
local MIN_ITEMS = 3
local MAX_ITEMS = 6

local CurrentRotation = {}
local NextRotationTime = 0

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local GetCurrentRotationFunction = Instance.new("RemoteFunction")
GetCurrentRotationFunction.Name = "GetCurrentRotationFunction"
GetCurrentRotationFunction.Parent = RemoteEvents

local PurchaseTixItemEvent = Instance.new("RemoteEvent")
PurchaseTixItemEvent.Name = "PurchaseTixItemEvent"
PurchaseTixItemEvent.Parent = RemoteEvents

local ShopRotationEvent = Instance.new("RemoteEvent")
ShopRotationEvent.Name = "ShopRotationEvent"
ShopRotationEvent.Parent = RemoteEvents

local OpenTixShopEvent = Instance.new("RemoteEvent")
OpenTixShopEvent.Name = "OpenTixShopEvent"
OpenTixShopEvent.Parent = RemoteEvents

local ForceRefreshEvent = Instance.new("RemoteEvent")
ForceRefreshEvent.Name = "ForceRefreshTixShopEvent"
ForceRefreshEvent.Parent = RemoteEvents

local RefreshTixShopEvent = Instance.new("RemoteEvent")
RefreshTixShopEvent.Name = "RefreshTixShopEvent"
RefreshTixShopEvent.Parent = RemoteEvents

local function FormatCash(amount)
        if amount >= 1000000000 then
                return "$" .. string.format("%.2f", amount / 1000000000) .. "B"
        elseif amount >= 1000000 then
                return "$" .. string.format("%.2f", amount / 1000000) .. "M"
        elseif amount >= 1000 then
                return "$" .. string.format("%.2f", amount / 1000) .. "K"
        else
                return "$" .. tostring(amount)
        end
end

local function SelectRotationItems()
        local availableItems = TixShopDatabase.VanityItems
        if #availableItems == 0 then
                return {}
        end
        
        local numItems = math.random(MIN_ITEMS, math.min(MAX_ITEMS, #availableItems))
        
        local itemPool = {}
        for i, item in ipairs(availableItems) do
                table.insert(itemPool, {index = i, item = item})
        end
        
        local selectedItems = {}
        
        for i = 1, numItems do
                if #itemPool == 0 then break end
                
                local totalWeight = 0
                for _, entry in ipairs(itemPool) do
                        local weight = 1 / (entry.item.Price ^ 0.75)
                        totalWeight = totalWeight + weight
                end
                
                local randomValue = math.random() * totalWeight
                local cumulativeWeight = 0
                local selectedEntry = nil
                local selectedPoolIndex = nil
                
                for poolIndex, entry in ipairs(itemPool) do
                        local weight = 1 / (entry.item.Price ^ 0.75)
                        cumulativeWeight = cumulativeWeight + weight
                        
                        if randomValue <= cumulativeWeight then
                                selectedEntry = entry
                                selectedPoolIndex = poolIndex
                                break
                        end
                end
                
                if selectedEntry then
                        local shopItem = {
                                Name = selectedEntry.item.Name,
                                Price = selectedEntry.item.Price,
                                Rarity = "Vanity"
                        }
                        
                        if selectedEntry.item.IsBundle then
                                shopItem.IsBundle = true
                                shopItem.ImageId = selectedEntry.item.ImageId
                                shopItem.BundleItems = selectedEntry.item.BundleItems
                                shopItem.RobloxId = selectedEntry.item.ImageId
                        else
                                shopItem.RobloxId = selectedEntry.item.RobloxId
                        end
                        
                        table.insert(selectedItems, shopItem)
                        table.remove(itemPool, selectedPoolIndex)
                end
        end
        
        return selectedItems
end

local function RotateShop()
        CurrentRotation = SelectRotationItems()
        NextRotationTime = os.time() + ROTATION_INTERVAL
        
        ShopRotationEvent:FireAllClients(CurrentRotation, NextRotationTime)
        
        local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
        if NotificationEvent then
                for _, player in ipairs(Players:GetPlayers()) do
                        NotificationEvent:FireClient(player, "EVENT_START", "Tix Shop has rotated! Check out the new items!")
                end
        end
        
        print("[TixShop] Rotated shop with " .. #CurrentRotation .. " items. Next rotation at: " .. os.date("%X", NextRotationTime))
end

GetCurrentRotationFunction.OnServerInvoke = function(player)
        local playerData = _G.PlayerData[player.UserId]
        if not playerData then
                return CurrentRotation, NextRotationTime
        end
        
        local rotationWithOwnership = {}
        for _, item in ipairs(CurrentRotation) do
                local itemCopy = table.clone(item)
                
                if item.IsBundle and item.BundleItems then
                        local allOwned = true
                        for _, bundleItem in ipairs(item.BundleItems) do
                                local itemId = type(bundleItem) == "table" and bundleItem.RobloxId or bundleItem
                                local owns = false
                                for _, invItem in ipairs(playerData.Inventory) do
                                        if invItem.RobloxId == itemId then
                                                owns = true
                                                break
                                        end
                                end
                                if not owns then
                                        allOwned = false
                                        break
                                end
                        end
                        itemCopy.IsOwned = allOwned
                else
                        local owns = false
                        for _, invItem in ipairs(playerData.Inventory) do
                                if invItem.RobloxId == item.RobloxId then
                                        owns = true
                                        break
                                end
                        end
                        itemCopy.IsOwned = owns
                end
                
                table.insert(rotationWithOwnership, itemCopy)
        end
        
        return rotationWithOwnership, NextRotationTime
end

PurchaseTixItemEvent.OnServerEvent:Connect(function(player, itemIdentifier)
        if not itemIdentifier then return end
        
        local itemData = nil
        for _, item in ipairs(CurrentRotation) do
                local matchesItem = (item.RobloxId and item.RobloxId == itemIdentifier) or 
                                   (item.ImageId and item.ImageId == itemIdentifier)
                if matchesItem then
                        itemData = item
                        break
                end
        end
        
        if not itemData then
                warn("[TixShop] Player " .. player.Name .. " tried to purchase item not in rotation: " .. tostring(itemIdentifier))
                return
        end
        
        local playerData = _G.PlayerData[player.UserId]
        if not playerData then
                warn("[TixShop] No player data found for " .. player.Name)
                return
        end
        
        if playerData.Cash < itemData.Price then
                local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
                if NotificationEvent then
                        NotificationEvent:FireClient(player, "ERROR", "Not enough cash! You need " .. FormatCash(itemData.Price))
                end
                return
        end
        
        if itemData.IsBundle and itemData.BundleItems then
                if not itemData.BundleItems or #itemData.BundleItems == 0 then
                        local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
                        if NotificationEvent then
                                NotificationEvent:FireClient(player, "ERROR", "Bundle has no items configured!")
                        end
                        return
                end
                
                local alreadyOwnsAll = true
                for _, bundleItem in ipairs(itemData.BundleItems) do
                        local itemId = type(bundleItem) == "table" and bundleItem.RobloxId or bundleItem
                        local owns = false
                        for _, invItem in ipairs(playerData.Inventory) do
                                if invItem.RobloxId == itemId then
                                        owns = true
                                        break
                                end
                        end
                        if not owns then
                                alreadyOwnsAll = false
                                break
                        end
                end
                
                if alreadyOwnsAll then
                        local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
                        if NotificationEvent then
                                NotificationEvent:FireClient(player, "ERROR", "You already own all items in this bundle!")
                        end
                        return
                end
                
                playerData.Cash = playerData.Cash - itemData.Price
                
                for _, bundleItem in ipairs(itemData.BundleItems) do
                        local itemId = type(bundleItem) == "table" and bundleItem.RobloxId or bundleItem
                        local bodyPartType = type(bundleItem) == "table" and bundleItem.BodyPartType or nil
                        
                        local alreadyOwnsItem = false
                        for _, invItem in ipairs(playerData.Inventory) do
                                if invItem.RobloxId == itemId then
                                        alreadyOwnsItem = true
                                        break
                                end
                        end
                        
                        if not alreadyOwnsItem then
                                local itemName = itemData.Name
                                
                                if bodyPartType then
                                        itemName = itemData.Name .. " " .. bodyPartType
                                else
                                        local productInfo = nil
                                        local success = pcall(function()
                                                productInfo = game:GetService("MarketplaceService"):GetProductInfo(itemId, Enum.InfoType.Asset)
                                        end)
                                        
                                        if success and productInfo and productInfo.Name then
                                                itemName = productInfo.Name
                                        else
                                                itemName = itemData.Name .. " Accessory"
                                        end
                                end
                                
                                -- Register the item in ItemDatabase before adding to inventory
                                ItemDatabase:EnsureVanityItem(itemId, itemName, 0)
                                
                                local newItem = {
                                        RobloxId = itemId,
                                        Name = itemName,
                                        Value = 0,
                                        Rarity = "Vanity"
                                }
                                
                                if bodyPartType then
                                        newItem.BodyPartType = bodyPartType
                                end
                                
                                DataStoreAPI:AddItem(player, newItem)
                        end
                end
                
                local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
                if NotificationEvent then
                        NotificationEvent:FireClient(player, "VICTORY", "Purchased " .. itemData.Name .. " bundle (" .. #itemData.BundleItems .. " items) for " .. FormatCash(itemData.Price) .. "!")
                end
                
                print("[TixShop] Player " .. player.Name .. " purchased bundle " .. itemData.Name .. " for $" .. itemData.Price)
        else
                local alreadyOwns = false
                for _, invItem in ipairs(playerData.Inventory) do
                        if invItem.RobloxId == itemData.RobloxId then
                                alreadyOwns = true
                                break
                        end
                end
                
                if alreadyOwns then
                        local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
                        if NotificationEvent then
                                NotificationEvent:FireClient(player, "ERROR", "You already own this item!")
                        end
                        return
                end
                
                playerData.Cash = playerData.Cash - itemData.Price
                
                DataStoreAPI:AddItem(player, {
                        RobloxId = itemData.RobloxId,
                        Name = itemData.Name,
                        Value = itemData.Price,
                        Rarity = "Vanity"
                })
                
                local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
                if NotificationEvent then
                        NotificationEvent:FireClient(player, "VICTORY", "Purchased " .. itemData.Name .. " for " .. FormatCash(itemData.Price) .. "!", itemData.RobloxId)
                end
                
                print("[TixShop] Player " .. player.Name .. " purchased " .. itemData.Name .. " for $" .. itemData.Price)
        end
        
        local RefreshTixShopEvent = RemoteEvents:FindFirstChild("RefreshTixShopEvent")
        if RefreshTixShopEvent then
                RefreshTixShopEvent:FireClient(player)
        end
end)

local function SetupProximityPrompt()
        local shopPart = game.Workspace:FindFirstChild("Shop_Open")
        if not shopPart then
                warn("[TixShop] Shop_Open part not found in Workspace!")
                return
        end
        
        local proximityPrompt = shopPart:FindFirstChildOfClass("ProximityPrompt")
        if not proximityPrompt then
                warn("[TixShop] ProximityPrompt not found on Shop_Open part!")
                return
        end
        
        proximityPrompt.Triggered:Connect(function(player)
                OpenTixShopEvent:FireClient(player)
        end)
        
        print("[TixShop] Proximity prompt setup complete")
end

local function StartRotationLoop()
        RotateShop()
        
        while true do
                task.wait(ROTATION_INTERVAL)
                RotateShop()
        end
end

ForceRefreshEvent.OnServerEvent:Connect(function(player)
        local AdminConfig = ServerScriptService:FindFirstChild("AdminConfig")
        if not AdminConfig then
                warn("[TixShop] AdminConfig not found, denying force refresh from " .. player.Name)
                return
        end
        
        local success, adminModule = pcall(function()
                return require(AdminConfig)
        end)
        
        if not success or not adminModule then
                warn("[TixShop] Failed to load AdminConfig, denying force refresh from " .. player.Name)
                return
        end
        
        if not adminModule:IsAdmin(player) then
                warn("[TixShop] Non-admin " .. player.Name .. " tried to force refresh shop")
                return
        end
        
        print("[TixShop] Admin " .. player.Name .. " forced shop refresh")
        RotateShop()
end)

local function RegisterVanityItems()
        ItemDatabase:WaitForReady()
        
        local count = 0
        for _, vanityItem in ipairs(TixShopDatabase.VanityItems) do
                local result = ItemDatabase:EnsureVanityItem(vanityItem.RobloxId, vanityItem.Name, vanityItem.Price)
                if result then
                        count = count + 1
                end
        end
        print("[TixShop] Registered " .. count .. " Vanity items in database")
        return true
end

local function InitializeTixShop()
        local regSuccess = RegisterVanityItems()
        if regSuccess then
                task.spawn(SetupProximityPrompt)
                task.spawn(StartRotationLoop)
        else
                warn("[TixShop] Failed to register Vanity items, shop will not start")
        end
end

task.spawn(InitializeTixShop)
