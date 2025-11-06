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
local EVENT_DURATION = 10 * 60
local EVENT_POOL_SIZE = 25

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
local activeProximityPrompts = {}
local activeHighlights = {}
local setPlayerCameraEvent = nil
local eventItemPool = {}

local function getRarityColor(rarity)
        if rarity == "Limited" then
                return Color3.fromRGB(255, 215, 0)
        end
        return ItemRarityModule:GetRarityColor(rarity)
end

local function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

local function getAllRollableItems()
        local rollableItems = {}
        for _, item in ipairs(ItemDatabase.Items) do
                if item.Rarity ~= "Limited" then
                        table.insert(rollableItems, item)
                end
        end
        return rollableItems
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

local function createEventPool(allItems)
        local pool = {}
        
        local chromaValk = ItemDatabase:GetItemByRobloxId(CHROMA_VALK_ID)
        if chromaValk then
                table.insert(pool, chromaValk)
        end
        
        local itemsToSelect = EVENT_POOL_SIZE - #pool
        local availableItems = {}
        for _, item in ipairs(allItems) do
                table.insert(availableItems, item)
        end
        
        for i = 1, itemsToSelect do
                if #availableItems == 0 then break end
                local selectedItem = pickWeightedItem(availableItems, false)
                if selectedItem then
                        table.insert(pool, selectedItem)
                end
        end
        
        return pool
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
        
        if #eventItemPool == 0 then
                warn("Event pool is empty!")
                activePulls[player.UserId] = nil
                if createNotificationEvent then
                        createNotificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "Error",
                                Body = "No items available in event pool"
                        })
                end
                return
        end
        
        local chromaValkExists = ItemDatabase:GetItemByRobloxId(CHROMA_VALK_ID) ~= nil
        local selectedItem = pickWeightedItem(eventItemPool, chromaValkExists)
        
        if not selectedItem then
                warn("Failed to select item from event pool")
                activePulls[player.UserId] = nil
                return
        end
        
        local itemModel = nil
        local primaryPart = nil
        
        local insertSuccess, insertedModel = pcall(function()
                return InsertService:LoadAsset(selectedItem.RobloxId)
        end)
        
        if insertSuccess and insertedModel then
                local actualItem = insertedModel:GetChildren()[1]
                if actualItem then
                        actualItem.Parent = workspace
                        itemModel = actualItem
                        
                        if itemModel:IsA("Accessory") or itemModel:IsA("Hat") then
                                primaryPart = itemModel:FindFirstChild("Handle")
                        elseif itemModel:IsA("Model") then
                                primaryPart = itemModel.PrimaryPart or itemModel:FindFirstChild("Handle") or itemModel:FindFirstChildWhichIsA("BasePart")
                        elseif itemModel:IsA("BasePart") then
                                primaryPart = itemModel
                        end
                        
                        if primaryPart then
                                primaryPart.Anchored = true
                                primaryPart.CanCollide = false
                                primaryPart.CFrame = spawnPart.CFrame
                        end
                        
                        itemModel:SetAttribute("BarrelPullOwner", player.UserId)
                end
                insertedModel:Destroy()
        end
        
        if not itemModel or not primaryPart then
                warn("⚠️ Failed to load item model for " .. selectedItem.Name .. ", using fallback box")
                local fallbackPart = Instance.new("Part")
                fallbackPart.Name = "BarrelItem_" .. selectedItem.Name
                fallbackPart.Size = Vector3.new(2, 2, 2)
                fallbackPart.Anchored = true
                fallbackPart.CanCollide = false
                fallbackPart.Color = getRarityColor(selectedItem.Rarity)
                fallbackPart.Material = Enum.Material.Neon
                fallbackPart.CFrame = spawnPart.CFrame
                fallbackPart.Parent = workspace
                fallbackPart:SetAttribute("BarrelPullOwner", player.UserId)
                itemModel = fallbackPart
                primaryPart = fallbackPart
        end
        
        task.wait(0.1)
        
        for _, prompt in ipairs(activeProximityPrompts) do
                if prompt and prompt.Parent then
                        prompt.Enabled = false
                end
        end
        
        if setPlayerCameraEvent then
                setPlayerCameraEvent:FireClient(player, camPart, spawnPart, finalPart, itemModel, primaryPart, selectedItem.Rarity)
        end
        
        task.spawn(function()
        
                task.wait(6)
                
                for _, prompt in ipairs(activeProximityPrompts) do
                        if prompt and prompt.Parent then
                                prompt.Enabled = true
                        end
                end
                
                if itemModel and itemModel.Parent then
                        itemModel:Destroy()
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
                        local notificationBody = selectedItem.Name .. "\n" .. selectedItem.Rarity
                        if itemToAdd.SerialNumber then
                                notificationBody = notificationBody .. " #" .. itemToAdd.SerialNumber
                        end
                        
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(player, {
                                        Type = "EVENT_COLLECT",
                                        Title = "Barrel Pull!",
                                        Body = notificationBody,
                                        ImageId = "rbxthumb://type=Asset&id=" .. selectedItem.RobloxId .. "&w=150&h=150",
                                        Color = getRarityColor(selectedItem.Rarity)
                                })
                        end
                else
                        warn("❌ Failed to add item to " .. player.Name .. "'s inventory")
                        
                        if stockIncremented and serialNumber then
                                local item = ItemDatabase:GetItemByRobloxId(selectedItem.RobloxId)
                                if item and item.CurrentStock then
                                        item.CurrentStock = item.CurrentStock - 1
                                        ItemDatabase:QueueSave()
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
        end)
end

local function toggleBarrelGUI(eventActive)
        local workspace = game:GetService("Workspace")
        local barrelsFolder = workspace:FindFirstChild("Barrels")
        
        if not barrelsFolder then
                return
        end
        
        for _, barrel in ipairs(barrelsFolder:GetChildren()) do
                if barrel:IsA("Model") then
                        local guiStand = barrel:FindFirstChild("GUI_Stand")
                        
                        if guiStand then
                                local billboardGui = guiStand:FindFirstChild("BillboardGui")
                                if billboardGui and billboardGui:IsA("BillboardGui") then
                                        billboardGui.Enabled = eventActive
                                end
                        end
                end
        end
end

function BarrelEvent.GetEventInfo()
        return {
                Name = "Barrel Event",
                Description = "Barrels have appeared! Pull items for " .. formatNumber(PULL_COST) .. " Cash each!",
                Image = "rbxassetid://8150337440"
        }
end

function BarrelEvent.Start(onEventEnd)
        local workspace = game:GetService("Workspace")
        local barrelsFolder = workspace:FindFirstChild("Barrels")
        
        if not barrelsFolder then
                warn("⚠️ Barrels folder not found in Workspace")
                if onEventEnd then
                        onEventEnd()
                end
                return
        end
        
        setPlayerCameraEvent = remoteEvents:FindFirstChild("SetPlayerCamera")
        if not setPlayerCameraEvent then
                setPlayerCameraEvent = Instance.new("RemoteEvent")
                setPlayerCameraEvent.Name = "SetPlayerCamera"
                setPlayerCameraEvent.Parent = remoteEvents
        end
        
        toggleBarrelGUI(true)
        
        local allRollableItems = getAllRollableItems()
        eventItemPool = createEventPool(allRollableItems)
        
        if #eventItemPool == 0 then
                warn("⚠️ Failed to create event pool, no items available")
                toggleBarrelGUI(false)
                if onEventEnd then
                        onEventEnd()
                end
                return
        end
        
        for _, barrel in ipairs(barrelsFolder:GetChildren()) do
                if barrel:IsA("Model") then
                        local body = barrel:FindFirstChild("Body")
                        local camPart = barrel:FindFirstChild("cam")
                        local spawnPart = barrel:FindFirstChild("spawn")
                        local finalPart = barrel:FindFirstChild("final")
                        
                        if body and camPart and spawnPart and finalPart then
                                local proximityPrompt = Instance.new("ProximityPrompt")
                                proximityPrompt.ActionText = "Pull Item"
                                proximityPrompt.ObjectText = "Barrel (" .. formatNumber(PULL_COST) .. " Cash)"
                                proximityPrompt.HoldDuration = 0.5
                                proximityPrompt.MaxActivationDistance = 10
                                proximityPrompt.RequiresLineOfSight = false
                                proximityPrompt.Parent = body
                                
                                table.insert(activeProximityPrompts, proximityPrompt)
                                
                                local highlight = Instance.new("Highlight")
                                highlight.FillColor = Color3.fromRGB(139, 69, 19)
                                highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
                                highlight.FillTransparency = 0.5
                                highlight.OutlineTransparency = 0
                                highlight.Enabled = false
                                highlight.Parent = barrel
                                
                                table.insert(activeHighlights, highlight)
                                
                                proximityPrompt.PromptShown:Connect(function()
                                        highlight.Enabled = true
                                end)
                                
                                proximityPrompt.PromptHidden:Connect(function()
                                        highlight.Enabled = false
                                end)
                                
                                proximityPrompt.Triggered:Connect(function(player)
                                        handleBarrelPull(player, barrel)
                                end)
                                
                        end
                end
        end
        
        
        task.wait(EVENT_DURATION)
        
        for _, prompt in ipairs(activeProximityPrompts) do
                if prompt and prompt.Parent then
                        prompt:Destroy()
                end
        end
        activeProximityPrompts = {}
        
        for _, highlight in ipairs(activeHighlights) do
                if highlight and highlight.Parent then
                        highlight:Destroy()
                end
        end
        activeHighlights = {}
        eventItemPool = {}
        
        toggleBarrelGUI(false)
        
        
        if onEventEnd then
                onEventEnd()
        end
end

toggleBarrelGUI(false)

return BarrelEvent
