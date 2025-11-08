local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TixShopDatabase = require(ReplicatedStorage:WaitForChild("TixShopDatabase"))
local DataStoreAPI = require(script.Parent:WaitForChild("DataStoreAPI"))

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

local function SelectRotationItems()
        local availableItems = TixShopDatabase.VanityItems
        if #availableItems == 0 then
                return {}
        end
        
        local numItems = math.random(MIN_ITEMS, math.min(MAX_ITEMS, #availableItems))
        
        local totalWeight = 0
        for _, item in ipairs(availableItems) do
                local weight = 1 / (item.Price ^ 0.75)
                totalWeight = totalWeight + weight
        end
        
        local selectedItems = {}
        local selectedIndices = {}
        
        for i = 1, numItems do
                local attempts = 0
                local maxAttempts = 100
                
                repeat
                        attempts = attempts + 1
                        local randomValue = math.random() * totalWeight
                        local cumulativeWeight = 0
                        local selectedIndex = nil
                        
                        for index, item in ipairs(availableItems) do
                                if not selectedIndices[index] then
                                        local weight = 1 / (item.Price ^ 0.75)
                                        cumulativeWeight = cumulativeWeight + weight
                                        
                                        if randomValue <= cumulativeWeight then
                                                selectedIndex = index
                                                break
                                        end
                                end
                        end
                        
                        if selectedIndex and not selectedIndices[selectedIndex] then
                                selectedIndices[selectedIndex] = true
                                table.insert(selectedItems, {
                                        Name = availableItems[selectedIndex].Name,
                                        RobloxId = availableItems[selectedIndex].RobloxId,
                                        Price = availableItems[selectedIndex].Price,
                                        Rarity = "Vanity"
                                })
                                break
                        end
                until attempts >= maxAttempts
                
                if attempts >= maxAttempts then
                        for index, item in ipairs(availableItems) do
                                if not selectedIndices[index] then
                                        selectedIndices[index] = true
                                        table.insert(selectedItems, {
                                                Name = item.Name,
                                                RobloxId = item.RobloxId,
                                                Price = item.Price,
                                                Rarity = "Vanity"
                                        })
                                        break
                                end
                        end
                end
        end
        
        return selectedItems
end

local function RotateShop()
        CurrentRotation = SelectRotationItems()
        NextRotationTime = os.time() + ROTATION_INTERVAL
        
        ShopRotationEvent:FireAllClients(CurrentRotation, NextRotationTime)
        
        print("[TixShop] Rotated shop with " .. #CurrentRotation .. " items. Next rotation at: " .. os.date("%X", NextRotationTime))
end

GetCurrentRotationFunction.OnServerInvoke = function(player)
        return CurrentRotation, NextRotationTime
end

PurchaseTixItemEvent.OnServerEvent:Connect(function(player, itemRobloxId)
        if not itemRobloxId then return end
        
        local itemData = nil
        for _, item in ipairs(CurrentRotation) do
                if item.RobloxId == itemRobloxId then
                        itemData = item
                        break
                end
        end
        
        if not itemData then
                warn("[TixShop] Player " .. player.Name .. " tried to purchase item not in rotation: " .. tostring(itemRobloxId))
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
                        NotificationEvent:FireClient(player, "ERROR", "Not enough cash! You need $" .. itemData.Price)
                end
                return
        end
        
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
        
        DataStoreAPI.AddItem(player, {
                RobloxId = itemData.RobloxId,
                Name = itemData.Name,
                Value = itemData.Price,
                Rarity = "Vanity"
        })
        
        local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
        if NotificationEvent then
                NotificationEvent:FireClient(player, "VICTORY", "Purchased " .. itemData.Name .. " for $" .. itemData.Price .. "!", itemData.RobloxId)
        end
        
        print("[TixShop] Player " .. player.Name .. " purchased " .. itemData.Name .. " for $" .. itemData.Price)
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

task.spawn(SetupProximityPrompt)
task.spawn(StartRotationLoop)
