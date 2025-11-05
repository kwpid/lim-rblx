local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")

local ItemDatabase = require(script.Parent.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.Parent.DataStoreAPI)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

local BarrelEvent = {}

local PULL_COST = 5000
local CHROMA_VALK_ID = 88275556285191
local CHROMA_VALK_CHANCE = 0.005

local RARITY_WEIGHTS = {
        ["Common"] = 100,
        ["Uncommon"] = 50,
        ["Rare"] = 20,
        ["Ultra Rare"] = 5,
        ["Epic"] = 2,
        ["Ultra Epic"] = 0.5,
        ["Mythic"] = 0.1,
        ["Insane"] = 0.05
}

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local createNotificationEvent = remoteEvents:FindFirstChild("CreateNotification")

local activePulls = {}

local function getRarityColor(rarity)
        if rarity == "Limited" then
                return Color3.fromRGB(255, 215, 0)
        end
        return ItemRarityModule.GetRarityColor(rarity)
end

local function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

local function getHatItems()
        local hatItems = {}
        for _, item in ipairs(ItemDatabase.Items) do
                local success, assetInfo = pcall(function()
                        return game:GetService("MarketplaceService"):GetProductInfo(item.RobloxId, Enum.InfoType.Asset)
                end)
                
                if success and assetInfo then
                        local assetType = assetInfo.AssetTypeId
                        if assetType == 8 or assetType == 41 or assetType == 42 or assetType == 43 or assetType == 44 or assetType == 45 or assetType == 46 or assetType == 47 or assetType == 48 or assetType == 61 then
                                table.insert(hatItems, item)
                        end
                end
        end
        return hatItems
end

local function pickWeightedItem(items, includeChromaValk)
        if #items == 0 then return nil end
        
        if includeChromaValk and math.random() < CHROMA_VALK_CHANCE then
                local chromaValk = ItemDatabase:GetItemByRobloxId(CHROMA_VALK_ID)
                if chromaValk then
                        return chromaValk
                end
        end
        
        local totalWeight = 0
        local weights = {}
        
        for _, item in ipairs(items) do
                local rarity = item.Rarity or ItemRarityModule.GetRarity(item.Value)
                local weight = RARITY_WEIGHTS[rarity] or 1
                
                table.insert(weights, weight)
                totalWeight = totalWeight + weight
        end
        
        local randomValue = math.random() * totalWeight
        local cumulative = 0
        for i, item in ipairs(items) do
                cumulative = cumulative + weights[i]
                if randomValue <= cumulative then
                        return item
                end
        end
        
        return items[#items]
end

local function handleBarrelPull(player, barrel)
        if activePulls[player.UserId] then
                if createNotificationEvent then
                        createNotificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Slow Down!",
                                Body = "You're already pulling from a barrel!"
                        })
                end
                return
        end
        
        local playerData = DataStoreAPI:GetPlayerData(player)
        if not playerData then
                if createNotificationEvent then
                        createNotificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Error",
                                Body = "Failed to load player data"
                        })
                end
                return
        end
        
        if playerData.Cash < PULL_COST then
                if createNotificationEvent then
                        createNotificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Not Enough Cash!",
                                Body = "You need " .. formatNumber(PULL_COST) .. " Cash to pull from the barrel"
                        })
                end
                return
        end
        
        activePulls[player.UserId] = true
        
        local hatItems = getHatItems()
        if #hatItems == 0 then
                warn("No hat items available for barrel pull")
                activePulls[player.UserId] = nil
                return
        end
        
        local chromaValkExists = ItemDatabase:GetItemByRobloxId(CHROMA_VALK_ID) ~= nil
        local selectedItem = pickWeightedItem(hatItems, chromaValkExists)
        
        if not selectedItem then
                warn("Failed to select item from barrel")
                activePulls[player.UserId] = nil
                return
        end
        
        local camPart = barrel:FindFirstChild("cam")
        local spawnPart = barrel:FindFirstChild("spawn")
        local finalPart = barrel:FindFirstChild("final")
        
        if not camPart or not spawnPart or not finalPart then
                warn("Barrel missing required parts (cam, spawn, final)")
                activePulls[player.UserId] = nil
                return
        end
        
        local character = player.Character
        if not character then
                activePulls[player.UserId] = nil
                return
        end
        
        local playerCameraEvent = remoteEvents:FindFirstChild("SetPlayerCamera")
        if playerCameraEvent then
                playerCameraEvent:FireClient(player, camPart)
        end
        
        local itemModel = nil
        local loadSuccess = false
        
        local success, assetContainer = pcall(function()
                return InsertService:LoadAsset(selectedItem.RobloxId)
        end)
        
        if success and assetContainer then
                for _, child in ipairs(assetContainer:GetChildren()) do
                        if child:IsA("Accoutrement") or child:IsA("Hat") then
                                itemModel = child:Clone()
                                itemModel.Name = "BarrelItem_" .. selectedItem.Name
                                loadSuccess = true
                                break
                        end
                end
                assetContainer:Destroy()
        end
        
        if not loadSuccess then
                itemModel = Instance.new("Part")
                itemModel.Name = "BarrelItem_" .. selectedItem.Name
                itemModel.Size = Vector3.new(2, 2, 2)
                itemModel.Anchored = true
                itemModel.CanCollide = false
                itemModel.Color = getRarityColor(selectedItem.Rarity)
                itemModel.Material = Enum.Material.Neon
        end
        
        if itemModel:IsA("Accoutrement") or itemModel:IsA("Hat") then
                local handle = itemModel:FindFirstChild("Handle")
                if handle then
                        handle.Anchored = true
                        handle.CanCollide = false
                end
        end
        
        itemModel.Parent = workspace
        itemModel:PivotTo(spawnPart.CFrame)
        
        local floatTween = TweenService:Create(
                itemModel:IsA("BasePart") and itemModel or itemModel:FindFirstChild("Handle"),
                TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {CFrame = finalPart.CFrame}
        )
        floatTween:Play()
        
        task.spawn(function()
                local targetPart = itemModel:IsA("BasePart") and itemModel or itemModel:FindFirstChild("Handle")
                if targetPart then
                        for i = 1, 60 do
                                targetPart.CFrame = targetPart.CFrame * CFrame.Angles(0, math.rad(6), 0)
                                task.wait(0.05)
                        end
                end
        end)
        
        task.wait(3)
        
        itemModel:Destroy()
        
        if playerCameraEvent then
                playerCameraEvent:FireClient(player, nil)
        end
        
        local cashDeducted = DataStoreAPI:AddCash(player, -PULL_COST)
        if not cashDeducted then
                warn("❌ Failed to deduct cash from " .. player.Name)
                if createNotificationEvent then
                        createNotificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Payment Failed",
                                Body = "Failed to process payment. Please try again."
                        })
                end
                activePulls[player.UserId] = nil
                return
        end
        
        local itemToAdd = {
                RobloxId = selectedItem.RobloxId,
                Name = selectedItem.Name,
                Value = selectedItem.Value,
                Rarity = selectedItem.Rarity,
                Amount = 1
        }
        
        local stockIncremented = false
        local serialNumber = nil
        
        if selectedItem.Stock and selectedItem.Stock > 0 then
                local item = ItemDatabase:GetItemByRobloxId(selectedItem.RobloxId)
                if item then
                        serialNumber = ItemDatabase:IncrementStock(item)
                        if serialNumber then
                                itemToAdd.SerialNumber = serialNumber
                                stockIncremented = true
                        else
                                warn("❌ Stock sold out for " .. selectedItem.Name .. " - refunding " .. player.Name)
                                local refundSuccess = DataStoreAPI:AddCash(player, PULL_COST)
                                if createNotificationEvent then
                                        if refundSuccess then
                                                createNotificationEvent:FireClient(player, {
                                                        Type = "ERROR",
                                                        Title = "Item Sold Out",
                                                        Body = selectedItem.Name .. " is sold out! Your cash has been refunded."
                                                })
                                        else
                                                createNotificationEvent:FireClient(player, {
                                                        Type = "ERROR",
                                                        Title = "Critical Error",
                                                        Body = selectedItem.Name .. " is sold out and refund failed! Contact support. (UserId: " .. player.UserId .. ")"
                                                })
                                                warn("⚠️ CRITICAL: Failed to refund " .. formatNumber(PULL_COST) .. " Cash to " .. player.Name .. " (UserId: " .. player.UserId .. ") after stock sold out")
                                        end
                                end
                                activePulls[player.UserId] = nil
                                return
                        end
                end
        end
        
        local addSuccess = DataStoreAPI:AddItem(player, itemToAdd)
        
        if addSuccess then
                local notificationBody = selectedItem.Name
                if itemToAdd.SerialNumber then
                        notificationBody = notificationBody .. " #" .. itemToAdd.SerialNumber
                end
                notificationBody = notificationBody .. "\n" .. formatNumber(selectedItem.Value) .. " Robux (" .. selectedItem.Rarity .. ")"
                
                if createNotificationEvent then
                        createNotificationEvent:FireClient(player, {
                                Type = "BARREL_PULL",
                                Title = "Barrel Pull!",
                                Body = notificationBody,
                                ImageId = "rbxassetid://" .. selectedItem.RobloxId,
                                Color = getRarityColor(selectedItem.Rarity)
                        })
                end
                
                print("✅ " .. player.Name .. " pulled " .. selectedItem.Name .. " from barrel (charged " .. formatNumber(PULL_COST) .. " Cash)")
        else
                warn("❌ Failed to add item to " .. player.Name .. "'s inventory")
                
                if stockIncremented and serialNumber then
                        local item = ItemDatabase:GetItemByRobloxId(selectedItem.RobloxId)
                        if item and item.CurrentStock then
                                item.CurrentStock = item.CurrentStock - 1
                                ItemDatabase:QueueSave()
                                print("↩️ Rolled back stock for " .. selectedItem.Name .. " (was serial #" .. serialNumber .. ")")
                        end
                end
                
                local refundSuccess = DataStoreAPI:AddCash(player, PULL_COST)
                
                if createNotificationEvent then
                        if refundSuccess then
                                createNotificationEvent:FireClient(player, {
                                        Type = "ERROR",
                                        Title = "Error",
                                        Body = "Failed to add item. Your cash has been refunded."
                                })
                        else
                                createNotificationEvent:FireClient(player, {
                                        Type = "ERROR",
                                        Title = "Critical Error",
                                        Body = "Failed to add item and refund failed! Contact support. (UserId: " .. player.UserId .. ")"
                                })
                                warn("⚠️ CRITICAL: Failed to refund " .. formatNumber(PULL_COST) .. " Cash to " .. player.Name .. " (UserId: " .. player.UserId .. ") after item add failed")
                        end
                end
        end
        
        activePulls[player.UserId] = nil
end

function BarrelEvent:Initialize()
        local workspace = game:GetService("Workspace")
        local barrelsFolder = workspace:FindFirstChild("Barrels")
        
        if not barrelsFolder then
                warn("⚠️ Barrels folder not found in Workspace")
                return
        end
        
        for _, barrel in ipairs(barrelsFolder:GetChildren()) do
                if barrel:IsA("Model") then
                        local body = barrel:FindFirstChild("Body")
                        
                        if body then
                                local proximityPrompt = Instance.new("ProximityPrompt")
                                proximityPrompt.ActionText = "Pull Item"
                                proximityPrompt.ObjectText = "Barrel (" .. formatNumber(PULL_COST) .. " Cash)"
                                proximityPrompt.HoldDuration = 0.5
                                proximityPrompt.MaxActivationDistance = 10
                                proximityPrompt.Parent = body
                                
                                local highlight = Instance.new("Highlight")
                                highlight.FillColor = Color3.fromRGB(139, 69, 19)
                                highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
                                highlight.FillTransparency = 0.5
                                highlight.OutlineTransparency = 0
                                highlight.Enabled = false
                                highlight.Parent = barrel
                                
                                proximityPrompt.PromptShown:Connect(function()
                                        highlight.Enabled = true
                                end)
                                
                                proximityPrompt.PromptHidden:Connect(function()
                                        highlight.Enabled = false
                                end)
                                
                                proximityPrompt.Triggered:Connect(function(player)
                                        handleBarrelPull(player, barrel)
                                end)
                                
                                print("✅ Barrel event initialized for: " .. barrel.Name)
                        else
                                warn("⚠️ Barrel model missing 'Body' part: " .. barrel.Name)
                        end
                end
        end
        
        local setPlayerCameraEvent = Instance.new("RemoteEvent")
        setPlayerCameraEvent.Name = "SetPlayerCamera"
        setPlayerCameraEvent.Parent = remoteEvents
        
        print("✅ Barrel Event system initialized")
end

BarrelEvent:Initialize()

return BarrelEvent
