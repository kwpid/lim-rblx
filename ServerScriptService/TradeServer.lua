-- TradeServer.lua
-- Rewritten trading system for crate opening game
-- Works with DataStoreAPI and current inventory structure

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)

-- Create TradeReplicatedStorage folder
local tradeRS = ReplicatedStorage:FindFirstChild("TradeReplicatedStorage")
if not tradeRS then
        tradeRS = Instance.new("Folder")
        tradeRS.Name = "TradeReplicatedStorage"
        tradeRS.Parent = ReplicatedStorage
end

-- Create RemoteEvent
local re = tradeRS:FindFirstChild("RemoteEvent")
if not re then
        re = Instance.new("RemoteEvent")
        re.Name = "RemoteEvent"
        re.Parent = tradeRS
end

-- Move TRADE_CONFIG to TradeReplicatedStorage and rename to CONFIGURATION
local config = ReplicatedStorage:FindFirstChild("TRADE_CONFIG")
if config then
        local configClone = config:Clone()
        configClone.Name = "CONFIGURATION"
        configClone.Parent = tradeRS
        config = require(configClone)
else
        -- Default config if not found
        config = {
                MaxSlots = 10,
                TimeBeforeTradeConfirmed = 5,
                AllowStockItemTrades = false
        }
end

-- Create folders for trade requests and ongoing trades
local tradeRequestsFolder = tradeRS:FindFirstChild("TRADE REQUESTS")
if not tradeRequestsFolder then
        tradeRequestsFolder = Instance.new("Folder")
        tradeRequestsFolder.Name = "TRADE REQUESTS"
        tradeRequestsFolder.Parent = tradeRS
end

local ongoingTradesFolder = tradeRS:FindFirstChild("ONGOING TRADES")
if not ongoingTradesFolder then
        ongoingTradesFolder = Instance.new("Folder")
        ongoingTradesFolder.Name = "ONGOING TRADES"
        ongoingTradesFolder.Parent = tradeRS
end

-- Helper function to format numbers
local function formatNumber(num)
        local formatted = tostring(num)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

-- Helper function to calculate offer value
local function calculateOfferValue(offerData)
        local totalValue = 0
        for _, item in pairs(offerData) do
                totalValue = totalValue + (item.Value * item.TradeAmount)
        end
        return totalValue
end

-- Remove all trades involving a player
local function removeTrades(player)
        for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
                        if trade.Sender.Value == player.Name or trade.Receiver.Value == player.Name then
                                trade:Destroy()
                        end
                end
        end

        for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                if request.Name == player.Name or request.Value == player.Name then
                        request:Destroy()
                end
        end
end

-- Get player's tradeable inventory (with trading IDs)
local function getTradInventory(player)
        local inventory = DataStoreAPI:GetInventory(player)
        local tradeableItems = {}
        
        for i, item in ipairs(inventory) do
                -- Skip stock items if trading them is disabled
                local canTrade = true
                if item.SerialNumber and not config.AllowStockItemTrades then
                        canTrade = false
                end
                
                if canTrade then
                        -- Add trading ID to item
                        item.TradingID = math.random(100000, 999999)
                        item.InventoryIndex = i -- Store original index
                        table.insert(tradeableItems, item)
                end
        end
        
        return tradeableItems
end

-- Find item in player's inventory by RobloxId and optional SerialNumber
local function findInventoryItem(player, robloxId, serialNumber)
        local inventory = DataStoreAPI:GetInventory(player)
        
        for i, item in ipairs(inventory) do
                if item.RobloxId == robloxId then
                        -- For stock items, match serial number
                        if serialNumber then
                                if item.SerialNumber == serialNumber then
                                        return item, i
                                end
                        else
                                -- For regular items, just match RobloxId
                                if not item.SerialNumber then
                                        return item, i
                                end
                        end
                end
        end
        
        return nil, nil
end

-- Remove items from player's inventory (called during trade execution)
local function removeItemsFromInventory(player, tradeItems)
        local playerData = DataStoreAPI:GetPlayerData(player)
        if not playerData then return false end
        
        for _, tradeItem in pairs(tradeItems) do
                local item, index = findInventoryItem(player, tradeItem.RobloxId, tradeItem.SerialNumber)
                
                if item then
                        if tradeItem.SerialNumber then
                                -- Stock item - remove the entire item
                                table.remove(playerData.Inventory, index)
                        else
                                -- Regular item - reduce amount
                                if item.Amount then
                                        item.Amount = item.Amount - tradeItem.TradeAmount
                                        if item.Amount <= 0 then
                                                table.remove(playerData.Inventory, index)
                                        end
                                else
                                        -- No amount field, treat as 1
                                        table.remove(playerData.Inventory, index)
                                end
                        end
                end
        end
        
        DataStoreAPI:UpdateInventoryValue(player)
        return true
end

-- Add items to player's inventory (called during trade execution)
local function addItemsToInventory(player, tradeItems)
        for _, tradeItem in pairs(tradeItems) do
                local itemData = {
                        RobloxId = tradeItem.RobloxId,
                        Name = tradeItem.Name,
                        Value = tradeItem.Value,
                        Rarity = tradeItem.Rarity
                }
                
                if tradeItem.SerialNumber then
                        -- Stock item
                        itemData.SerialNumber = tradeItem.SerialNumber
                        DataStoreAPI:AddItem(player, itemData)
                else
                        -- Regular item - add the amount
                        for i = 1, tradeItem.TradeAmount do
                                DataStoreAPI:AddItem(player, itemData)
                        end
                end
        end
        
        return true
end

-- Clean up trades when player dies or leaves
Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(char)
                local humanoid = char:WaitForChild("Humanoid")
                humanoid.Died:Connect(function()
                        removeTrades(player)
                end)
        end)
end)

Players.PlayerRemoving:Connect(removeTrades)

-- Handle client requests
re.OnServerEvent:Connect(function(player, instruction, data)
        
        -- Send trade request
        if instruction == "send trade request" then
                local targetPlayer = data[1]
                
                if not targetPlayer or targetPlayer == player then return end
                
                -- Check if already in a trade
                local inTrade = false
                for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                        if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
                                if trade.Sender.Value == targetPlayer.Name or trade.Sender.Value == player.Name or
                                        trade.Receiver.Value == targetPlayer.Name or trade.Receiver.Value == player.Name then
                                        inTrade = true
                                        break
                                end
                        end
                end
                
                for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                        if request.Name == targetPlayer.Name or request.Name == player.Name or
                                request.Value == targetPlayer.Name or request.Value == player.Name then
                                inTrade = true
                                break
                        end
                end
                
                if not inTrade then
                        local newRequest = Instance.new("StringValue")
                        newRequest.Name = player.Name
                        newRequest.Value = targetPlayer.Name
                        newRequest.Parent = tradeRequestsFolder
                end
                
        -- Reject trade request
        elseif instruction == "reject trade request" then
                for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                        if request.Name == player.Name or request.Value == player.Name then
                                request:Destroy()
                                break
                        end
                end
                
        -- Accept trade request
        elseif instruction == "accept trade request" then
                local requestValue = nil
                for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                        if request.Name == player.Name or request.Value == player.Name then
                                requestValue = request
                                break
                        end
                end
                
                if requestValue and requestValue.Value == player.Name then
                        local senderPlayer = Players:FindFirstChild(requestValue.Name)
                        local receiverPlayer = Players:FindFirstChild(requestValue.Value)
                        
                        if not senderPlayer or not receiverPlayer then return end
                        
                        requestValue:Destroy()
                        
                        -- Create trade folder
                        local tradeFolder = Instance.new("Folder")
                        tradeFolder.Name = senderPlayer.Name .. "_" .. receiverPlayer.Name
                        
                        local senderValue = Instance.new("StringValue")
                        senderValue.Name = "Sender"
                        senderValue.Value = senderPlayer.Name
                        senderValue.Parent = tradeFolder
                        
                        local receiverValue = Instance.new("StringValue")
                        receiverValue.Name = "Receiver"
                        receiverValue.Value = receiverPlayer.Name
                        receiverValue.Parent = tradeFolder
                        
                        -- Create offer folders (stored as ObjectValues that contain tables)
                        local senderOffer = Instance.new("Folder")
                        senderOffer.Name = senderPlayer.Name .. "'s offer"
                        senderOffer.Parent = tradeFolder
                        
                        local receiverOffer = Instance.new("Folder")
                        receiverOffer.Name = receiverPlayer.Name .. "'s offer"
                        receiverOffer.Parent = tradeFolder
                        
                        tradeFolder.Parent = ongoingTradesFolder
                end
                
        -- Get tradeable inventory
        elseif instruction == "get tradeable inventory" then
                local inventory = getTradInventory(player)
                re:FireClient(player, "receive tradeable inventory", inventory)
                
        -- Add item to trade
        elseif instruction == "add item to trade" then
                local itemData = data[1]
                
                -- Find current trade
                local currentTrade = nil
                for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                        if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
                                if trade.Sender.Value == player.Name or trade.Receiver.Value == player.Name then
                                        currentTrade = trade
                                        break
                                end
                        end
                end
                
                if not currentTrade then return end
                
                local playerOffer = currentTrade:FindFirstChild(player.Name .. "'s offer")
                if not playerOffer then return end
                
                -- Check max slots
                if #playerOffer:GetChildren() >= config.MaxSlots then return end
                
                -- Verify player owns this item
                local item, index = findInventoryItem(player, itemData.RobloxId, itemData.SerialNumber)
                if not item then return end
                
                -- Reset acceptance
                if currentTrade.Sender:FindFirstChild("ACCEPTED") then
                        currentTrade.Sender.ACCEPTED:Destroy()
                end
                if currentTrade.Receiver:FindFirstChild("ACCEPTED") then
                        currentTrade.Receiver.ACCEPTED:Destroy()
                end
                
                -- Check if item already in trade
                local existingTradeItem = nil
                for _, tradeItem in pairs(playerOffer:GetChildren()) do
                        if tradeItem:IsA("ObjectValue") and tradeItem.Value then
                                local data = tradeItem.Value
                                if data.RobloxId == itemData.RobloxId and data.SerialNumber == itemData.SerialNumber then
                                        existingTradeItem = tradeItem
                                        break
                                end
                        end
                end
                
                if existingTradeItem and not itemData.SerialNumber then
                        -- Stack regular items
                        local currentAmount = existingTradeItem.Value.TradeAmount
                        local availableAmount = (item.Amount or 1) - currentAmount
                        
                        if availableAmount >= 1 then
                                existingTradeItem.Value.TradeAmount = currentAmount + 1
                        end
                else
                        -- Add new item to trade
                        if itemData.SerialNumber or ((item.Amount or 1) >= 1) then
                                local tradeItemValue = Instance.new("ObjectValue")
                                tradeItemValue.Name = itemData.RobloxId .. "_" .. (#playerOffer:GetChildren() + 1)
                                tradeItemValue.Value = {
                                        RobloxId = itemData.RobloxId,
                                        Name = itemData.Name,
                                        Value = itemData.Value,
                                        Rarity = itemData.Rarity,
                                        SerialNumber = itemData.SerialNumber,
                                        TradeAmount = 1
                                }
                                tradeItemValue.Parent = playerOffer
                        end
                end
                
        -- Remove item from trade
        elseif instruction == "remove item from trade" then
                local itemData = data[1]
                
                -- Find current trade
                local currentTrade = nil
                for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                        if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
                                if trade.Sender.Value == player.Name or trade.Receiver.Value == player.Name then
                                        currentTrade = trade
                                        break
                                end
                        end
                end
                
                if not currentTrade then return end
                
                local playerOffer = currentTrade:FindFirstChild(player.Name .. "'s offer")
                if not playerOffer then return end
                
                -- Reset acceptance
                if currentTrade.Sender:FindFirstChild("ACCEPTED") then
                        currentTrade.Sender.ACCEPTED:Destroy()
                end
                if currentTrade.Receiver:FindFirstChild("ACCEPTED") then
                        currentTrade.Receiver.ACCEPTED:Destroy()
                end
                
                -- Find and remove/reduce item
                for _, tradeItem in pairs(playerOffer:GetChildren()) do
                        if tradeItem:IsA("ObjectValue") and tradeItem.Value then
                                local data = tradeItem.Value
                                if data.RobloxId == itemData.RobloxId and data.SerialNumber == itemData.SerialNumber then
                                        if data.SerialNumber or data.TradeAmount <= 1 then
                                                -- Remove entire item
                                                tradeItem:Destroy()
                                        else
                                                -- Reduce amount
                                                data.TradeAmount = data.TradeAmount - 1
                                        end
                                        break
                                end
                        end
                end
                
        -- Accept trade
        elseif instruction == "accept trade" then
                local currentTrade = nil
                for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                        if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
                                if trade.Sender.Value == player.Name or trade.Receiver.Value == player.Name then
                                        currentTrade = trade
                                        break
                                end
                        end
                end
                
                if not currentTrade then return end
                
                local playerValue = currentTrade.Sender.Value == player.Name and currentTrade.Sender or currentTrade.Receiver
                
                -- Toggle acceptance
                if not playerValue:FindFirstChild("ACCEPTED") then
                        local accepted = Instance.new("StringValue")
                        accepted.Name = "ACCEPTED"
                        accepted.Parent = playerValue
                else
                        playerValue.ACCEPTED:Destroy()
                end
                
                -- Check if both accepted
                if currentTrade.Sender:FindFirstChild("ACCEPTED") and currentTrade.Receiver:FindFirstChild("ACCEPTED") then
                        -- Create countdown timer
                        local timerValue = Instance.new("NumberValue")
                        timerValue.Name = "TradeTimer"
                        timerValue.Value = config.TimeBeforeTradeConfirmed
                        timerValue.Parent = currentTrade
                        
                        task.spawn(function()
                                local timeLeft = config.TimeBeforeTradeConfirmed
                                while timeLeft > 0 do
                                        task.wait(0.1)
                                        timeLeft = timeLeft - 0.1
                                        if timerValue and timerValue.Parent then
                                                timerValue.Value = math.max(0, timeLeft)
                                        else
                                                return
                                        end
                                end
                                
                                -- Execute trade
                                if currentTrade.Parent and currentTrade.Sender:FindFirstChild("ACCEPTED") and currentTrade.Receiver:FindFirstChild("ACCEPTED") then
                                        local senderPlayer = Players:FindFirstChild(currentTrade.Sender.Value)
                                        local receiverPlayer = Players:FindFirstChild(currentTrade.Receiver.Value)
                                        
                                        if senderPlayer and receiverPlayer then
                                                local senderOffer = currentTrade:FindFirstChild(senderPlayer.Name .. "'s offer")
                                                local receiverOffer = currentTrade:FindFirstChild(receiverPlayer.Name .. "'s offer")
                                                
                                                -- Convert offers to item arrays
                                                local senderItems = {}
                                                local receiverItems = {}
                                                
                                                if senderOffer then
                                                        for _, tradeItem in pairs(senderOffer:GetChildren()) do
                                                                if tradeItem:IsA("ObjectValue") and tradeItem.Value then
                                                                        table.insert(senderItems, tradeItem.Value)
                                                                end
                                                        end
                                                end
                                                
                                                if receiverOffer then
                                                        for _, tradeItem in pairs(receiverOffer:GetChildren()) do
                                                                if tradeItem:IsA("ObjectValue") and tradeItem.Value then
                                                                        table.insert(receiverItems, tradeItem.Value)
                                                                end
                                                        end
                                                end
                                                
                                                -- Execute trade
                                                removeItemsFromInventory(senderPlayer, senderItems)
                                                addItemsToInventory(receiverPlayer, senderItems)
                                                
                                                removeItemsFromInventory(receiverPlayer, receiverItems)
                                                addItemsToInventory(senderPlayer, receiverItems)
                                                
                                                -- Notify clients
                                                re:FireClient(senderPlayer, "trade completed")
                                                re:FireClient(receiverPlayer, "trade completed")
                                                
                                                print(string.format("✅ Trade completed: %s <-> %s", senderPlayer.Name, receiverPlayer.Name))
                                        end
                                        
                                        currentTrade:Destroy()
                                end
                        end)
                end
                
        -- Cancel trade
        elseif instruction == "cancel trade" then
                removeTrades(player)
        end
end)

print("✅ TradeServer loaded successfully")
