local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")

local ItemDatabase = require(script.Parent.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.Parent.DataStoreAPI)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))
local WebhookHandler = require(script.Parent.Parent.WebhookHandler)

local ScavengerHunt = {}

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local chatNotificationEvent = remoteEvents:FindFirstChild("ChatNotificationEvent")
local createNotificationEvent = remoteEvents:FindFirstChild("CreateNotification")

local currentEventEndCallback = nil
local hiddenItemModel = nil

local function getValueColorTag(value)
        if value >= 10000000 then
                return "<font color=\"#FF00FF\">"
        elseif value >= 2500000 then
                return "<font color=\"#FF0000\">"
        elseif value >= 750000 then
                return "<font color=\"#FF5500\">"
        elseif value >= 250000 then
                return "<font color=\"#FFAA00\">"
        elseif value >= 50000 then
                return "<font color=\"#AA55FF\">"
        elseif value >= 10000 then
                return "<font color=\"#5555FF\">"
        elseif value >= 2500 then
                return "<font color=\"#55AA55\">"
        else
                return "<font color=\"#AAAAAA\">"
        end
end

local function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

local function isUltraEpicOrHigher(item)
        local rarity = item.Rarity or ItemRarityModule.GetRarity(item.Value)
        return item.Value >= 750000
end

local function isFaceItem(robloxId)
        local success, assetInfo = pcall(function()
                return MarketplaceService:GetProductInfo(robloxId, Enum.InfoType.Asset)
        end)
        
        if success and assetInfo then
                return assetInfo.AssetTypeId == 18
        end
        
        return false
end

local function pickRandomScavengerItem(items)
        local filteredItems = {}
        
        for _, item in ipairs(items) do
                if isUltraEpicOrHigher(item) and not isFaceItem(item.RobloxId) then
                        table.insert(filteredItems, item)
                end
        end
        
        if #filteredItems == 0 then
                return nil
        end
        
        local totalWeight = 0
        local weights = {}
        
        for _, item in ipairs(filteredItems) do
                -- Higher exponent (1.5) makes higher value items MUCH less likely
                -- Ultra Epic (750k) will be most common, Insane (10M+) will be extremely rare
                local weight = 1 / (item.Value ^ 1.5)
                table.insert(weights, weight)
                totalWeight = totalWeight + weight
        end
        
        local randomValue = math.random() * totalWeight
        local cumulative = 0
        for i, item in ipairs(filteredItems) do
                cumulative = cumulative + weights[i]
                if randomValue <= cumulative then
                        return item
                end
        end
        
        return filteredItems[#filteredItems]
end

local function createHiddenItem(itemData, hideLocation, onCollected)
        local itemModel = nil
        local loadSuccess = false
        
        local success, assetContainer = pcall(function()
                return InsertService:LoadAsset(itemData.RobloxId)
        end)
        
        if success and assetContainer then
                for _, child in ipairs(assetContainer:GetChildren()) do
                        if child:IsA("Accoutrement") or child:IsA("Tool") or child:IsA("Hat") or child:IsA("Model") then
                                itemModel = child:Clone()
                                itemModel.Name = "ScavengerItem_" .. itemData.Name
                                loadSuccess = true
                                print("✅ Loaded actual model for scavenger hunt: " .. itemData.Name)
                                break
                        end
                end
                assetContainer:Destroy()
        end
        
        if not loadSuccess then
                warn("⚠️ Could not load model for " .. itemData.Name .. " (ID: " .. itemData.RobloxId .. "), using fallback")
        end
        
        if not itemModel then
                itemModel = Instance.new("Model")
                itemModel.Name = "ScavengerItem_" .. itemData.Name
                
                local part = Instance.new("Part")
                part.Name = "ItemPart"
                part.Size = Vector3.new(3, 3, 3)
                part.Anchored = true
                part.CanCollide = true
                part.Material = Enum.Material.Neon
                
                local rarityColors = {
                        ["Common"] = Color3.fromRGB(170, 170, 170),
                        ["Uncommon"] = Color3.fromRGB(85, 170, 85),
                        ["Rare"] = Color3.fromRGB(85, 85, 255),
                        ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
                        ["Epic"] = Color3.fromRGB(255, 170, 0),
                        ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
                        ["Mythic"] = Color3.fromRGB(255, 0, 0),
                        ["Insane"] = Color3.fromRGB(255, 0, 255)
                }
                part.Color = rarityColors[itemData.Rarity] or Color3.new(1, 1, 1)
                part.Parent = itemModel
                
                local surfaceGui = Instance.new("SurfaceGui")
                surfaceGui.Face = Enum.NormalId.Top
                surfaceGui.Parent = part
                
                local imageLabel = Instance.new("ImageLabel")
                imageLabel.Size = UDim2.new(1, 0, 1, 0)
                imageLabel.BackgroundTransparency = 1
                imageLabel.Image = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150"
                imageLabel.Parent = surfaceGui
        end
        
        local rarityColors = {
                ["Common"] = Color3.fromRGB(170, 170, 170),
                ["Uncommon"] = Color3.fromRGB(85, 170, 85),
                ["Rare"] = Color3.fromRGB(85, 85, 255),
                ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
                ["Epic"] = Color3.fromRGB(255, 170, 0),
                ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
                ["Mythic"] = Color3.fromRGB(255, 0, 0),
                ["Insane"] = Color3.fromRGB(255, 0, 255)
        }
        local rarityColor = rarityColors[itemData.Rarity] or Color3.new(1, 1, 1)
        
        local part
        if itemModel:IsA("Accoutrement") or itemModel:IsA("Hat") then
                part = itemModel:FindFirstChild("Handle")
        elseif itemModel:IsA("Tool") then
                part = itemModel:FindFirstChild("Handle")
        elseif itemModel:IsA("Model") then
                part = itemModel.PrimaryPart or itemModel:FindFirstChildWhichIsA("BasePart", true)
        end
        
        if not part then
                part = itemModel:FindFirstChildWhichIsA("BasePart", true)
        end
        
        if not part then
                part = Instance.new("Part")
                part.Name = "ItemPart"
                part.Size = Vector3.new(3, 3, 3)
                part.Anchored = true
                part.CanCollide = true
                part.Parent = itemModel
        end
        
        local highlight = Instance.new("Highlight")
        highlight.Name = "RarityHighlight"
        highlight.Adornee = itemModel
        highlight.FillTransparency = 0.3
        highlight.OutlineTransparency = 0
        highlight.FillColor = rarityColor
        highlight.OutlineColor = rarityColor
        highlight.Parent = itemModel
        
        local pointLight = Instance.new("PointLight")
        pointLight.Name = "GlowLight"
        pointLight.Color = rarityColor
        pointLight.Brightness = 2
        pointLight.Range = 15
        pointLight.Parent = part
        
        task.spawn(function()
                local pulseSpeed = 2
                local minBrightness = 1
                local maxBrightness = 3
                
                while itemModel and itemModel.Parent and pointLight and pointLight.Parent do
                        for brightness = minBrightness, maxBrightness, 0.1 do
                                if not itemModel or not itemModel.Parent or not pointLight or not pointLight.Parent then break end
                                pointLight.Brightness = brightness
                                task.wait(pulseSpeed / 20)
                        end
                        for brightness = maxBrightness, minBrightness, -0.1 do
                                if not itemModel or not itemModel.Parent or not pointLight or not pointLight.Parent then break end
                                pointLight.Brightness = brightness
                                task.wait(pulseSpeed / 20)
                        end
                end
        end)
        
        local proximityPrompt = Instance.new("ProximityPrompt")
        proximityPrompt.ActionText = "Collect Item"
        proximityPrompt.ObjectText = itemData.Name
        proximityPrompt.MaxActivationDistance = 10
        proximityPrompt.RequiresLineOfSight = false
        proximityPrompt.Parent = part
        
        itemModel.Parent = workspace
        
        if itemModel:IsA("Model") and itemModel.PrimaryPart then
                itemModel:SetPrimaryPartCFrame(CFrame.new(hideLocation.Position))
        else
                part.CFrame = CFrame.new(hideLocation.Position)
        end
        
        part.Anchored = true
        
        task.spawn(function()
                while itemModel and itemModel.Parent do
                        part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(2), 0)
                        task.wait(0.05)
                end
        end)
        
        local collected = false
        proximityPrompt.Triggered:Connect(function(player)
                if collected then return end
                collected = true
                
                onCollected(player, itemData)
                
                itemModel:Destroy()
        end)
        
        return itemModel
end

local function handleItemCollection(player, itemData)
        if itemData.IsStockItem then
                local item = ItemDatabase:GetItemByRobloxId(itemData.RobloxId)
                if item then
                        local serialNumber = ItemDatabase:IncrementStock(item)
                        if serialNumber then
                                itemData.SerialNumber = serialNumber
                                print("✅ " .. player.Name .. " collecting scavenger hunt stock item " .. itemData.Name .. " #" .. serialNumber)
                        else
                                warn("⚠️ Stock sold out for " .. itemData.Name .. " before " .. player.Name .. " could collect it")
                                
                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(player, {
                                                Type = "ERROR",
                                                Title = "Item Sold Out",
                                                Body = itemData.Name .. " sold out before you could collect it!"
                                        })
                                end
                                return
                        end
                else
                        warn("❌ Item not found in database: " .. itemData.Name)
                        return
                end
        end
        
        local success = DataStoreAPI:AddItem(player, itemData)
        
        if not success then
                warn("❌ Failed to give scavenger hunt item to player: " .. player.Name)
                return
        end
        
        if itemData.SerialNumber then
                print("✅ " .. player.Name .. " collected scavenger hunt stock item " .. itemData.Name .. " #" .. itemData.SerialNumber)
        else
                print("✅ " .. player.Name .. " collected scavenger hunt item " .. itemData.Name)
        end
        
        if createNotificationEvent then
                local notificationBody = itemData.Name .. "\n" .. itemData.Rarity
                if itemData.SerialNumber then
                        notificationBody = notificationBody .. " #" .. itemData.SerialNumber
                end
                
                local rarityColors = {
                        ["Common"] = Color3.fromRGB(170, 170, 170),
                        ["Uncommon"] = Color3.fromRGB(85, 170, 85),
                        ["Rare"] = Color3.fromRGB(85, 85, 255),
                        ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
                        ["Epic"] = Color3.fromRGB(255, 170, 0),
                        ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
                        ["Mythic"] = Color3.fromRGB(255, 0, 0),
                        ["Insane"] = Color3.fromRGB(255, 0, 255)
                }
                local notificationColor = rarityColors[itemData.Rarity] or Color3.fromRGB(255, 215, 0)
                
                createNotificationEvent:FireClient(player, {
                        Type = "EVENT_COLLECT",
                        Title = "Scavenger Hunt Item Found!",
                        Body = notificationBody,
                        ImageId = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150",
                        Color = notificationColor
                })
        end
        
        if itemData.Value >= 250000 then
                local colorTag = getValueColorTag(itemData.Value)
                local closeTag = "</font>"
                
                local message = colorTag .. player.Name .. " found the scavenger hunt item: " .. itemData.Name
                
                if itemData.SerialNumber then
                        message = message .. " #" .. itemData.SerialNumber
                end
                
                message = message .. " (R$" .. formatNumber(itemData.Value) .. ")!" .. closeTag
                
                if chatNotificationEvent then
                        chatNotificationEvent:FireAllClients(message)
                end
        end
        
        if itemData.Value >= 250000 then
                WebhookHandler:SendHighValueUnbox(player, itemData, "scavenger_hunt")
        end
        
        if currentEventEndCallback then
                task.spawn(function()
                        task.wait(0.5)
                        
                        if createNotificationEvent then
                                local eventEndBody = player.Name .. " found the hidden item!"
                                if itemData.SerialNumber then
                                        eventEndBody = eventEndBody .. "\n" .. itemData.Name .. " #" .. itemData.SerialNumber
                                else
                                        eventEndBody = eventEndBody .. "\n" .. itemData.Name
                                end
                                
                                createNotificationEvent:FireAllClients({
                                        Type = "EVENT_END",
                                        Title = "Scavenger Hunt Ended!",
                                        Body = eventEndBody,
                                        ImageId = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150"
                                })
                        end
                        
                        currentEventEndCallback()
                        currentEventEndCallback = nil
                end)
        end
end

function ScavengerHunt.GetEventInfo()
        return {
                Name = "Scavenger Hunt!",
                Description = "A rare item has been hidden somewhere in the map! Find it before someone else does!",
                Image = "rbxassetid://8150337440"
        }
end

function ScavengerHunt.Start(onEventEnd)
        print("🔍 Starting Scavenger Hunt event")
        
        currentEventEndCallback = onEventEnd
        
        local scavengerFolder = workspace:FindFirstChild("ScavengerEvent")
        if not scavengerFolder then
                warn("❌ No ScavengerEvent folder found in workspace! Event cancelled.")
                if onEventEnd then onEventEnd() end
                currentEventEndCallback = nil
                return
        end
        
        local hideLocations = scavengerFolder:GetChildren()
        if #hideLocations == 0 then
                warn("❌ No hide locations found in ScavengerEvent folder! Event cancelled.")
                if onEventEnd then onEventEnd() end
                currentEventEndCallback = nil
                return
        end
        
        local maxWait = 30
        local waited = 0
        while not ItemDatabase.IsReady and waited < maxWait do
                task.wait(0.5)
                waited = waited + 0.5
        end
        
        if not ItemDatabase.IsReady then
                warn("❌ ItemDatabase not ready! Event cancelled.")
                if onEventEnd then onEventEnd() end
                currentEventEndCallback = nil
                return
        end
        
        local allItems = ItemDatabase:GetRollableItems()
        if #allItems == 0 then
                warn("❌ No items available for scavenger hunt!")
                if onEventEnd then onEventEnd() end
                currentEventEndCallback = nil
                return
        end
        
        local selectedItem = pickRandomScavengerItem(allItems)
        if not selectedItem then
                warn("❌ No Ultra Epic or higher items available for scavenger hunt!")
                if onEventEnd then onEventEnd() end
                currentEventEndCallback = nil
                return
        end
        
        local randomLocation = hideLocations[math.random(1, #hideLocations)]
        
        local itemData = {
                RobloxId = selectedItem.RobloxId,
                Name = selectedItem.Name,
                Value = selectedItem.Value,
                Rarity = selectedItem.Rarity or ItemRarityModule.GetRarity(selectedItem.Value),
                IsStockItem = (selectedItem.Stock and selectedItem.Stock > 0) or false
        }
        
        print("✅ Hiding scavenger hunt item: " .. itemData.Name .. " at " .. randomLocation.Name)
        
        hiddenItemModel = createHiddenItem(itemData, randomLocation, handleItemCollection)
end

return ScavengerHunt
