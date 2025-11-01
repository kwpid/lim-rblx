-- TradeServer.lua
-- Server-side trading system for crate opening game
-- Works with DataStore-based inventory system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)

-- Create/Get TradeReplicatedStorage folder
local tradeRS = ReplicatedStorage:FindFirstChild("TradeReplicatedStorage")
if not tradeRS then
        tradeRS = Instance.new("Folder")
        tradeRS.Name = "TradeReplicatedStorage"
        tradeRS.Parent = ReplicatedStorage
end

-- Load config
local config = require(ReplicatedStorage:WaitForChild("TRADE_CONFIG"))

-- Create RemoteEvent for trade communication
local tradeEvent = tradeRS:FindFirstChild("TradeEvent")
if not tradeEvent then
        tradeEvent = Instance.new("RemoteEvent")
        tradeEvent.Name = "TradeEvent"
        tradeEvent.Parent = tradeRS
end

-- Create RemoteFunction for getting trade data
local getTradeDataFunction = tradeRS:FindFirstChild("GetTradeDataFunction")
if not getTradeDataFunction then
        getTradeDataFunction = Instance.new("RemoteFunction")
        getTradeDataFunction.Name = "GetTradeDataFunction"
        getTradeDataFunction.Parent = tradeRS
end

-- Trade requests and ongoing trades tracking
local tradeRequests = {} -- {sender = receiver}
local ongoingTrades = {} -- {[tradeId] = tradeData}

-- Trade history DataStore
local tradeHistoryStore = DataStoreService:GetDataStore("TradeHistoryStore_v1")

-- Helper function to check if item is tradeable
local function isItemTradeable(itemData)
        -- Stock items cannot be traded (have SerialNumber)
        if not config.AllowStockItemTrades and itemData.SerialNumber then
                return false
        end
        return true
end

-- Helper function to find item in player's inventory
local function findItemInInventory(player, robloxId)
        local inventory = DataStoreAPI:GetInventory(player)
        if not inventory then return nil end
        
        for i, item in ipairs(inventory) do
                if item.RobloxId == robloxId and isItemTradeable(item) then
                        return item, i
                end
        end
        return nil
end

-- Helper function to calculate offer value
local function calculateOfferValue(offer)
        local totalValue = 0
        for _, item in ipairs(offer) do
                totalValue = totalValue + (item.Value * item.Amount)
        end
        return totalValue
end

-- Save trade to history
local function saveTradeToHistory(player1, player2, player1Offer, player2Offer)
        local timestamp = os.time()
        
        -- Create trade data for both players
        local p1TradeData = {
                tradedWith = player2.Name,
                tradedWithUserId = player2.UserId,
                timestamp = timestamp,
                given = player1Offer,
                received = player2Offer
        }
        
        local p2TradeData = {
                tradedWith = player1.Name,
                tradedWithUserId = player1.UserId,
                timestamp = timestamp,
                given = player2Offer,
                received = player1Offer
        }
        
        -- Save to DataStore
        pcall(function()
                local p1History = tradeHistoryStore:GetAsync(player1.UserId) or {}
                table.insert(p1History, p1TradeData)
                if #p1History > 50 then
                        table.remove(p1History, 1)
                end
                tradeHistoryStore:SetAsync(player1.UserId, p1History)
        end)
        
        pcall(function()
                local p2History = tradeHistoryStore:GetAsync(player2.UserId) or {}
                table.insert(p2History, p2TradeData)
                if #p2History > 50 then
                        table.remove(p2History, 1)
                end
                tradeHistoryStore:SetAsync(player2.UserId, p2History)
        end)
        
        print("📜 Trade saved to history: " .. player1.Name .. " <-> " .. player2.Name)
end

-- Execute the trade (transfer items between players)
local function executeTrade(tradeData)
        local player1 = Players:FindFirstChild(tradeData.player1Name)
        local player2 = Players:FindFirstChild(tradeData.player2Name)
        
        if not player1 or not player2 then
                warn("⚠️ Trade failed: One or both players left")
                return false
        end
        
        -- Verify both players still have the items they're trading
        for _, offerItem in ipairs(tradeData.player1Offer) do
                local item = findItemInInventory(player1, offerItem.RobloxId)
                if not item or (item.Amount or 1) < offerItem.Amount then
                        warn("⚠️ Trade failed: " .. player1.Name .. " doesn't have enough " .. offerItem.Name)
                        return false
                end
        end
        
        for _, offerItem in ipairs(tradeData.player2Offer) do
                local item = findItemInInventory(player2, offerItem.RobloxId)
                if not item or (item.Amount or 1) < offerItem.Amount then
                        warn("⚠️ Trade failed: " .. player2.Name .. " doesn't have enough " .. offerItem.Name)
                        return false
                end
        end
        
        -- Remove items from both players
        for _, offerItem in ipairs(tradeData.player1Offer) do
                DataStoreAPI:RemoveItem(player1, offerItem.RobloxId, offerItem.Amount)
        end
        
        for _, offerItem in ipairs(tradeData.player2Offer) do
                DataStoreAPI:RemoveItem(player2, offerItem.RobloxId, offerItem.Amount)
        end
        
        -- Add items to both players
        for _, offerItem in ipairs(tradeData.player2Offer) do
                local itemToAdd = {
                        RobloxId = offerItem.RobloxId,
                        Name = offerItem.Name,
                        Value = offerItem.Value,
                        Rarity = offerItem.Rarity,
                }
                -- Add items one by one (will auto-stack)
                for i = 1, offerItem.Amount do
                        DataStoreAPI:AddItem(player1, itemToAdd)
                end
        end
        
        for _, offerItem in ipairs(tradeData.player1Offer) do
                local itemToAdd = {
                        RobloxId = offerItem.RobloxId,
                        Name = offerItem.Name,
                        Value = offerItem.Value,
                        Rarity = offerItem.Rarity,
                }
                -- Add items one by one (will auto-stack)
                for i = 1, offerItem.Amount do
                        DataStoreAPI:AddItem(player2, itemToAdd)
                end
        end
        
        -- Save trade to history
        saveTradeToHistory(player1, player2, tradeData.player1Offer, tradeData.player2Offer)
        
        print("✅ Trade completed: " .. player1.Name .. " <-> " .. player2.Name)
        return true
end

-- Handle trade events from clients
tradeEvent.OnServerEvent:Connect(function(player, action, data)
        
        -- Send trade request
        if action == "SendRequest" then
                local targetPlayer = data.targetPlayer
                
                if not targetPlayer or targetPlayer == player then
                        return
                end
                
                -- Check if either player is already in a trade
                for tradeId, trade in pairs(ongoingTrades) do
                        if trade.player1Name == player.Name or trade.player2Name == player.Name or
                           trade.player1Name == targetPlayer.Name or trade.player2Name == targetPlayer.Name then
                                tradeEvent:FireClient(player, "Error", {message = "You or the other player is already in a trade"})
                                return
                        end
                end
                
                -- Check if request already exists
                if tradeRequests[player.Name] or tradeRequests[targetPlayer.Name] then
                        tradeEvent:FireClient(player, "Error", {message = "A trade request is already pending"})
                        return
                end
                
                -- Create request
                tradeRequests[player.Name] = targetPlayer.Name
                tradeEvent:FireClient(targetPlayer, "RequestReceived", {sender = player})
                tradeEvent:FireClient(player, "RequestSent", {receiver = targetPlayer})
                
                print("📤 Trade request: " .. player.Name .. " → " .. targetPlayer.Name)
                
        -- Accept trade request
        elseif action == "AcceptRequest" then
                local senderName = data.senderName
                
                if tradeRequests[senderName] == player.Name then
                        local sender = Players:FindFirstChild(senderName)
                        if sender then
                                -- Create trade
                                local tradeId = HttpService:GenerateGUID(false)
                                ongoingTrades[tradeId] = {
                                        tradeId = tradeId,
                                        player1Name = senderName,
                                        player2Name = player.Name,
                                        player1Offer = {},
                                        player2Offer = {},
                                        player1Accepted = false,
                                        player2Accepted = false
                                }
                                
                                -- Remove request
                                tradeRequests[senderName] = nil
                                
                                -- Notify both players
                                tradeEvent:FireClient(sender, "TradeStarted", {tradeId = tradeId, otherPlayer = player})
                                tradeEvent:FireClient(player, "TradeStarted", {tradeId = tradeId, otherPlayer = sender})
                                
                                print("🤝 Trade started: " .. senderName .. " <-> " .. player.Name)
                        end
                end
                
        -- Reject/Cancel trade request
        elseif action == "RejectRequest" or action == "CancelRequest" then
                for senderName, receiverName in pairs(tradeRequests) do
                        if senderName == player.Name or receiverName == player.Name then
                                local sender = Players:FindFirstChild(senderName)
                                local receiver = Players:FindFirstChild(receiverName)
                                
                                tradeRequests[senderName] = nil
                                
                                if sender then
                                        tradeEvent:FireClient(sender, "RequestCancelled", {})
                                end
                                if receiver then
                                        tradeEvent:FireClient(receiver, "RequestCancelled", {})
                                end
                                break
                        end
                end
                
        -- Add item to offer
        elseif action == "AddItem" then
                local tradeId = data.tradeId
                local robloxId = data.robloxId
                
                local trade = ongoingTrades[tradeId]
                if not trade then return end
                
                -- Determine which player is making the offer
                local isPlayer1 = trade.player1Name == player.Name
                local offer = isPlayer1 and trade.player1Offer or trade.player2Offer
                
                -- Check if max slots reached
                if #offer >= config.MaxSlots then
                        tradeEvent:FireClient(player, "Error", {message = "Maximum trade slots reached"})
                        return
                end
                
                -- Find item in player's inventory
                local item = findItemInInventory(player, robloxId)
                if not item then
                        tradeEvent:FireClient(player, "Error", {message = "Item not found or not tradeable"})
                        return
                end
                
                -- Check if item already in offer
                local existingItem = nil
                for i, offerItem in ipairs(offer) do
                        if offerItem.RobloxId == robloxId then
                                existingItem = offerItem
                                break
                        end
                end
                
                if existingItem then
                        -- Increase amount
                        local currentAmount = item.Amount or 1
                        if existingItem.Amount < currentAmount then
                                existingItem.Amount = existingItem.Amount + 1
                        end
                else
                        -- Add new item
                        table.insert(offer, {
                                RobloxId = item.RobloxId,
                                Name = item.Name,
                                Value = item.Value,
                                Rarity = item.Rarity,
                                Amount = 1
                        })
                end
                
                -- Reset acceptance
                trade.player1Accepted = false
                trade.player2Accepted = false
                
                -- Notify both players
                local otherPlayer = isPlayer1 and Players:FindFirstChild(trade.player2Name) or Players:FindFirstChild(trade.player1Name)
                if otherPlayer then
                        tradeEvent:FireClient(otherPlayer, "OfferUpdated", {tradeId = tradeId, trade = trade})
                end
                tradeEvent:FireClient(player, "OfferUpdated", {tradeId = tradeId, trade = trade})
                
        -- Remove item from offer
        elseif action == "RemoveItem" then
                local tradeId = data.tradeId
                local robloxId = data.robloxId
                
                local trade = ongoingTrades[tradeId]
                if not trade then return end
                
                -- Determine which player is making the offer
                local isPlayer1 = trade.player1Name == player.Name
                local offer = isPlayer1 and trade.player1Offer or trade.player2Offer
                
                -- Find and remove/decrease item
                for i, offerItem in ipairs(offer) do
                        if offerItem.RobloxId == robloxId then
                                if offerItem.Amount > 1 then
                                        offerItem.Amount = offerItem.Amount - 1
                                else
                                        table.remove(offer, i)
                                end
                                break
                        end
                end
                
                -- Reset acceptance
                trade.player1Accepted = false
                trade.player2Accepted = false
                
                -- Notify both players
                local otherPlayer = isPlayer1 and Players:FindFirstChild(trade.player2Name) or Players:FindFirstChild(trade.player1Name)
                if otherPlayer then
                        tradeEvent:FireClient(otherPlayer, "OfferUpdated", {tradeId = tradeId, trade = trade})
                end
                tradeEvent:FireClient(player, "OfferUpdated", {tradeId = tradeId, trade = trade})
                
        -- Accept trade
        elseif action == "AcceptTrade" then
                local tradeId = data.tradeId
                local trade = ongoingTrades[tradeId]
                if not trade then return end
                
                -- Set acceptance
                if trade.player1Name == player.Name then
                        trade.player1Accepted = not trade.player1Accepted
                else
                        trade.player2Accepted = not trade.player2Accepted
                end
                
                -- Notify both players
                local player1 = Players:FindFirstChild(trade.player1Name)
                local player2 = Players:FindFirstChild(trade.player2Name)
                
                if player1 then
                        tradeEvent:FireClient(player1, "AcceptanceChanged", {tradeId = tradeId, trade = trade})
                end
                if player2 then
                        tradeEvent:FireClient(player2, "AcceptanceChanged", {tradeId = tradeId, trade = trade})
                end
                
                -- If both accepted, execute trade after countdown
                if trade.player1Accepted and trade.player2Accepted then
                        -- Start countdown
                        task.spawn(function()
                                task.wait(config.TimeBeforeTradeConfirmed)
                                
                                -- Double check both still accepted
                                if trade.player1Accepted and trade.player2Accepted then
                                        local success = executeTrade(trade)
                                        
                                        if success then
                                                if player1 then
                                                        tradeEvent:FireClient(player1, "TradeCompleted", {})
                                                end
                                                if player2 then
                                                        tradeEvent:FireClient(player2, "TradeCompleted", {})
                                                end
                                        else
                                                if player1 then
                                                        tradeEvent:FireClient(player1, "TradeFailed", {message = "Trade verification failed"})
                                                end
                                                if player2 then
                                                        tradeEvent:FireClient(player2, "TradeFailed", {message = "Trade verification failed"})
                                                end
                                        end
                                        
                                        -- Remove trade
                                        ongoingTrades[tradeId] = nil
                                end
                        end)
                end
                
        -- Cancel trade
        elseif action == "CancelTrade" then
                local tradeId = data.tradeId
                local trade = ongoingTrades[tradeId]
                if not trade then return end
                
                -- Notify both players
                local player1 = Players:FindFirstChild(trade.player1Name)
                local player2 = Players:FindFirstChild(trade.player2Name)
                
                if player1 then
                        tradeEvent:FireClient(player1, "TradeCancelled", {})
                end
                if player2 then
                        tradeEvent:FireClient(player2, "TradeCancelled", {})
                end
                
                -- Remove trade
                ongoingTrades[tradeId] = nil
                
                print("🚫 Trade cancelled: " .. trade.player1Name .. " <-> " .. trade.player2Name)
        end
end)

-- Get trade data function
getTradeDataFunction.OnServerInvoke = function(player, action, data)
        if action == "GetInventory" then
                local inventory = DataStoreAPI:GetInventory(player)
                if not inventory then return {} end
                
                -- Filter tradeable items only
                local tradeableItems = {}
                for _, item in ipairs(inventory) do
                        if isItemTradeable(item) then
                                table.insert(tradeableItems, item)
                        end
                end
                
                return tradeableItems
        elseif action == "GetTradeHistory" then
                local success, history = pcall(function()
                        return tradeHistoryStore:GetAsync(player.UserId) or {}
                end)
                
                if success then
                        return history
                else
                        return {}
                end
        end
        
        return nil
end

-- Clean up trades when player leaves
Players.PlayerRemoving:Connect(function(player)
        -- Remove pending requests
        for senderName, receiverName in pairs(tradeRequests) do
                if senderName == player.Name or receiverName == player.Name then
                        local sender = Players:FindFirstChild(senderName)
                        local receiver = Players:FindFirstChild(receiverName)
                        
                        if sender and sender ~= player then
                                tradeEvent:FireClient(sender, "RequestCancelled", {})
                        end
                        if receiver and receiver ~= player then
                                tradeEvent:FireClient(receiver, "RequestCancelled", {})
                        end
                        
                        tradeRequests[senderName] = nil
                end
        end
        
        -- Cancel ongoing trades
        for tradeId, trade in pairs(ongoingTrades) do
                if trade.player1Name == player.Name or trade.player2Name == player.Name then
                        local otherPlayerName = trade.player1Name == player.Name and trade.player2Name or trade.player1Name
                        local otherPlayer = Players:FindFirstChild(otherPlayerName)
                        
                        if otherPlayer then
                                tradeEvent:FireClient(otherPlayer, "TradeCancelled", {message = player.Name .. " left the game"})
                        end
                        
                        ongoingTrades[tradeId] = nil
                end
        end
end)

print("✅ Trade Server loaded - Trading system active")
