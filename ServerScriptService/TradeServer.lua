local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)
local config = require(ReplicatedStorage:WaitForChild("TradeConfiguration"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
end

local tradeEvent = remoteEvents:FindFirstChild("TradeEvent")
if not tradeEvent then
        tradeEvent = Instance.new("RemoteEvent")
        tradeEvent.Name = "TradeEvent"
        tradeEvent.Parent = remoteEvents
end

local tradeRequestsFolder = ReplicatedStorage:FindFirstChild("TRADE REQUESTS")
if not tradeRequestsFolder then
        tradeRequestsFolder = Instance.new("Folder")
        tradeRequestsFolder.Name = "TRADE REQUESTS"
        tradeRequestsFolder.Parent = ReplicatedStorage
        print("✅ TradeServer: Created TRADE REQUESTS folder")
end

local ongoingTradesFolder = ReplicatedStorage:FindFirstChild("ONGOING TRADES")
if not ongoingTradesFolder then
        ongoingTradesFolder = Instance.new("Folder")
        ongoingTradesFolder.Name = "ONGOING TRADES"
        ongoingTradesFolder.Parent = ReplicatedStorage
        print("✅ TradeServer: Created ONGOING TRADES folder")
end

function removeTrades(plr)
        for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
                        trade:Destroy()
                end
        end

        for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                if request.Name == plr.Name or request.Value == plr.Name then
                        request:Destroy()
                end
        end
end

Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
                char:WaitForChild("Humanoid").Died:Connect(function()
                        removeTrades(plr)
                end)
        end)
end)

Players.PlayerRemoving:Connect(removeTrades)

function findTradeForPlayer(plr)
        for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
                        return trade
                end
        end
        return nil
end

function resetAcceptanceStates(trade)
        if trade.Receiver:FindFirstChild("ACCEPTED") then
                trade.Receiver.ACCEPTED:Destroy()
        end
        if trade.Sender:FindFirstChild("ACCEPTED") then
                trade.Sender.ACCEPTED:Destroy()
        end
end

function findItemInInventory(player, robloxId, serialNumber)
        local inventory = DataStoreAPI:GetInventory(player)
        for i, item in ipairs(inventory) do
                if item.RobloxId == robloxId then
                        if serialNumber and item.SerialNumber == serialNumber then
                                return i, item
                        elseif not serialNumber and not item.SerialNumber then
                                return i, item
                        end
                end
        end
        return nil, nil
end

print("✅ TradeServer: Event listener connected and ready")

tradeEvent.OnServerEvent:Connect(function(plr, instruction, data)
        print("📩 TradeServer received:", instruction, "from", plr.Name)
        
        if instruction == "send trade request" then
                local playerSent = data[1]

                if playerSent and playerSent ~= plr then
                        local inTrade = false

                        for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                                if trade.Sender.Value == playerSent.Name or trade.Sender.Value == plr.Name or 
                                   trade.Receiver.Value == playerSent.Name or trade.Receiver.Value == plr.Name then
                                        inTrade = true
                                        break
                                end
                        end

                        for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                                if request.Name == playerSent.Name or request.Name == plr.Name or 
                                   request.Value == playerSent.Name or request.Value == plr.Name then
                                        inTrade = true
                                        break
                                end
                        end

                        if not inTrade then
                                local newRequest = Instance.new("StringValue")
                                newRequest.Name = plr.Name
                                newRequest.Value = playerSent.Name
                                newRequest.Parent = tradeRequestsFolder
                        end
                end

        elseif instruction == "reject trade request" then
                for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                        if request.Name == plr.Name or request.Value == plr.Name then
                                request:Destroy()
                                break
                        end
                end

        elseif instruction == "accept trade request" then
                local requestValue = nil
                for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                        if request.Name == plr.Name or request.Value == plr.Name then
                                requestValue = request
                                break
                        end
                end

                if requestValue and requestValue.Parent == tradeRequestsFolder and requestValue.Value == plr.Name then
                        local senderPlr = Players:FindFirstChild(requestValue.Name)
                        local receiverPlr = Players:FindFirstChild(requestValue.Value)

                        if not senderPlr or not receiverPlr then
                                requestValue:Destroy()
                                return
                        end

                        requestValue:Destroy()

                        local tradeFolder = Instance.new("Folder")
                        tradeFolder.Name = senderPlr.Name .. "_" .. receiverPlr.Name

                        local senderValue = Instance.new("StringValue")
                        senderValue.Name = "Sender"
                        senderValue.Value = senderPlr.Name
                        senderValue.Parent = tradeFolder

                        local receiverValue = Instance.new("StringValue")
                        receiverValue.Name = "Receiver"
                        receiverValue.Value = receiverPlr.Name
                        receiverValue.Parent = tradeFolder

                        local senderOffer = Instance.new("Folder")
                        senderOffer.Name = senderPlr.Name .. "'s offer"
                        senderOffer.Parent = tradeFolder

                        local receiverOffer = Instance.new("Folder")
                        receiverOffer.Name = receiverPlr.Name .. "'s offer"
                        receiverOffer.Parent = tradeFolder

                        tradeFolder.Parent = ongoingTradesFolder
                end

        elseif instruction == "add item to trade" then
                local robloxId = data[1]
                local serialNumber = data[2]
                local amount = data[3] or 1

                local currentTrade = findTradeForPlayer(plr)
                if not currentTrade then return end

                local plrOffer = currentTrade[plr.Name .. "'s offer"]
                local numItems = #plrOffer:GetChildren()

                local _, inventoryItem = findItemInInventory(plr, robloxId, serialNumber)
                if not inventoryItem then return end

                if serialNumber then
                        local alreadyInTrade = false
                        for _, offerItem in pairs(plrOffer:GetChildren()) do
                                local offerSerial = offerItem:FindFirstChild("SerialNumber")
                                local offerRobloxId = offerItem:FindFirstChild("RobloxId")
                                if offerRobloxId and offerSerial and offerRobloxId.Value == robloxId and offerSerial.Value == serialNumber then
                                        alreadyInTrade = true
                                        break
                                end
                        end

                        if not alreadyInTrade then
                                if numItems >= config.MaxSlots then return end

                                resetAcceptanceStates(currentTrade)

                                local itemFolder = Instance.new("Folder")
                                itemFolder.Name = "Item_" .. robloxId .. "_" .. serialNumber

                                local idValue = Instance.new("NumberValue")
                                idValue.Name = "RobloxId"
                                idValue.Value = robloxId
                                idValue.Parent = itemFolder

                                local nameValue = Instance.new("StringValue")
                                nameValue.Name = "ItemName"
                                nameValue.Value = inventoryItem.Name
                                nameValue.Parent = itemFolder

                                local serialValue = Instance.new("NumberValue")
                                serialValue.Name = "SerialNumber"
                                serialValue.Value = serialNumber
                                serialValue.Parent = itemFolder

                                local rarityValue = Instance.new("StringValue")
                                rarityValue.Name = "Rarity"
                                rarityValue.Value = inventoryItem.Rarity
                                rarityValue.Parent = itemFolder

                                local valueValue = Instance.new("NumberValue")
                                valueValue.Name = "Value"
                                valueValue.Value = inventoryItem.Value
                                valueValue.Parent = itemFolder

                                itemFolder.Parent = plrOffer
                        end
                else
                        local existingOffer = nil
                        for _, offerItem in pairs(plrOffer:GetChildren()) do
                                local offerRobloxId = offerItem:FindFirstChild("RobloxId")
                                local offerSerial = offerItem:FindFirstChild("SerialNumber")
                                if offerRobloxId and not offerSerial and offerRobloxId.Value == robloxId then
                                        existingOffer = offerItem
                                        break
                                end
                        end

                        if existingOffer then
                                local amountValue = existingOffer:FindFirstChild("Amount")
                                if amountValue then
                                        if amountValue.Value < inventoryItem.Amount then
                                                resetAcceptanceStates(currentTrade)
                                                amountValue.Value = amountValue.Value + amount
                                        end
                                end
                        else
                                if numItems >= config.MaxSlots then return end

                                resetAcceptanceStates(currentTrade)

                                local itemFolder = Instance.new("Folder")
                                itemFolder.Name = "Item_" .. robloxId

                                local idValue = Instance.new("NumberValue")
                                idValue.Name = "RobloxId"
                                idValue.Value = robloxId
                                idValue.Parent = itemFolder

                                local nameValue = Instance.new("StringValue")
                                nameValue.Name = "ItemName"
                                nameValue.Value = inventoryItem.Name
                                nameValue.Parent = itemFolder

                                local amountValue = Instance.new("NumberValue")
                                amountValue.Name = "Amount"
                                amountValue.Value = amount
                                amountValue.Parent = itemFolder

                                local rarityValue = Instance.new("StringValue")
                                rarityValue.Name = "Rarity"
                                rarityValue.Value = inventoryItem.Rarity
                                rarityValue.Parent = itemFolder

                                local valueValue = Instance.new("NumberValue")
                                valueValue.Name = "Value"
                                valueValue.Value = inventoryItem.Value
                                valueValue.Parent = itemFolder

                                itemFolder.Parent = plrOffer
                        end
                end

        elseif instruction == "remove item from trade" then
                local robloxId = data[1]
                local serialNumber = data[2]
                local amount = data[3] or 1

                local currentTrade = findTradeForPlayer(plr)
                if not currentTrade then return end

                local plrOffer = currentTrade[plr.Name .. "'s offer"]

                for _, offerItem in pairs(plrOffer:GetChildren()) do
                        local offerRobloxId = offerItem:FindFirstChild("RobloxId")
                        local offerSerial = offerItem:FindFirstChild("SerialNumber")
                        local offerAmount = offerItem:FindFirstChild("Amount")

                        if offerRobloxId and offerRobloxId.Value == robloxId then
                                if serialNumber and offerSerial and offerSerial.Value == serialNumber then
                                        resetAcceptanceStates(currentTrade)
                                        offerItem:Destroy()
                                        break
                                elseif not serialNumber and not offerSerial and offerAmount then
                                        if offerAmount.Value <= amount then
                                                resetAcceptanceStates(currentTrade)
                                                offerItem:Destroy()
                                        else
                                                resetAcceptanceStates(currentTrade)
                                                offerAmount.Value = offerAmount.Value - amount
                                        end
                                        break
                                end
                        end
                end

        elseif instruction == "accept trade" then
                local currentTrade = findTradeForPlayer(plr)
                if not currentTrade then return end

                local plrValue = currentTrade.Sender.Value == plr.Name and currentTrade.Sender or
                        currentTrade.Receiver.Value == plr.Name and currentTrade.Receiver

                if plrValue then
                        if not plrValue:FindFirstChild("ACCEPTED") then
                                local acceptedValue = Instance.new("StringValue")
                                acceptedValue.Name = "ACCEPTED"
                                acceptedValue.Parent = plrValue
                        else
                                plrValue.ACCEPTED:Destroy()
                        end
                end

                if currentTrade.Sender:FindFirstChild("ACCEPTED") and currentTrade.Receiver:FindFirstChild("ACCEPTED") then
                        task.wait(config.TimeBeforeTradeConfirmed)

                        if currentTrade.Sender:FindFirstChild("ACCEPTED") and currentTrade.Receiver:FindFirstChild("ACCEPTED") then
                                local senderPlr = Players:FindFirstChild(currentTrade.Sender.Value)
                                local receiverPlr = Players:FindFirstChild(currentTrade.Receiver.Value)

                                if not senderPlr or not receiverPlr then
                                        currentTrade:Destroy()
                                        return
                                end

                                local senderOffer = currentTrade[senderPlr.Name .. "'s offer"]
                                local receiverOffer = currentTrade[receiverPlr.Name .. "'s offer"]

                                local senderData = _G.PlayerData[senderPlr.UserId]
                                local receiverData = _G.PlayerData[receiverPlr.UserId]

                                if not senderData or not receiverData then
                                        currentTrade:Destroy()
                                        return
                                end

                                local senderItems = {}
                                for _, offerItem in pairs(senderOffer:GetChildren()) do
                                        local robloxId = offerItem:FindFirstChild("RobloxId")
                                        local serialNumber = offerItem:FindFirstChild("SerialNumber")
                                        local amount = offerItem:FindFirstChild("Amount")
                                        local itemName = offerItem:FindFirstChild("ItemName")
                                        local rarity = offerItem:FindFirstChild("Rarity")
                                        local value = offerItem:FindFirstChild("Value")

                                        if robloxId and itemName and rarity and value then
                                                table.insert(senderItems, {
                                                        RobloxId = robloxId.Value,
                                                        SerialNumber = serialNumber and serialNumber.Value or nil,
                                                        Amount = amount and amount.Value or 1,
                                                        Name = itemName.Value,
                                                        Rarity = rarity.Value,
                                                        Value = value.Value
                                                })
                                        end
                                end

                                local receiverItems = {}
                                for _, offerItem in pairs(receiverOffer:GetChildren()) do
                                        local robloxId = offerItem:FindFirstChild("RobloxId")
                                        local serialNumber = offerItem:FindFirstChild("SerialNumber")
                                        local amount = offerItem:FindFirstChild("Amount")
                                        local itemName = offerItem:FindFirstChild("ItemName")
                                        local rarity = offerItem:FindFirstChild("Rarity")
                                        local value = offerItem:FindFirstChild("Value")

                                        if robloxId and itemName and rarity and value then
                                                table.insert(receiverItems, {
                                                        RobloxId = robloxId.Value,
                                                        SerialNumber = serialNumber and serialNumber.Value or nil,
                                                        Amount = amount and amount.Value or 1,
                                                        Name = itemName.Value,
                                                        Rarity = rarity.Value,
                                                        Value = value.Value
                                                })
                                        end
                                end

                                for _, item in ipairs(senderItems) do
                                        local inventoryIndex, inventoryItem = findItemInInventory(senderPlr, item.RobloxId, item.SerialNumber)
                                        if inventoryIndex and inventoryItem then
                                                if item.SerialNumber then
                                                        table.remove(senderData.Inventory, inventoryIndex)
                                                else
                                                        if inventoryItem.Amount and inventoryItem.Amount > item.Amount then
                                                                inventoryItem.Amount = inventoryItem.Amount - item.Amount
                                                        else
                                                                table.remove(senderData.Inventory, inventoryIndex)
                                                        end
                                                end
                                        end
                                end

                                for _, item in ipairs(receiverItems) do
                                        local inventoryIndex, inventoryItem = findItemInInventory(receiverPlr, item.RobloxId, item.SerialNumber)
                                        if inventoryIndex and inventoryItem then
                                                if item.SerialNumber then
                                                        table.remove(receiverData.Inventory, inventoryIndex)
                                                else
                                                        if inventoryItem.Amount and inventoryItem.Amount > item.Amount then
                                                                inventoryItem.Amount = inventoryItem.Amount - item.Amount
                                                        else
                                                                table.remove(receiverData.Inventory, inventoryIndex)
                                                        end
                                                end
                                        end
                                end

                                for _, item in ipairs(senderItems) do
                                        DataStoreAPI:AddItem(receiverPlr, {
                                                RobloxId = item.RobloxId,
                                                Name = item.Name,
                                                Value = item.Value,
                                                Rarity = item.Rarity,
                                                SerialNumber = item.SerialNumber,
                                                Amount = item.Amount
                                        })
                                end

                                for _, item in ipairs(receiverItems) do
                                        DataStoreAPI:AddItem(senderPlr, {
                                                RobloxId = item.RobloxId,
                                                Name = item.Name,
                                                Value = item.Value,
                                                Rarity = item.Rarity,
                                                SerialNumber = item.SerialNumber,
                                                Amount = item.Amount
                                        })
                                end

                                DataStoreAPI:UpdateInventoryValue(senderPlr)
                                DataStoreAPI:UpdateInventoryValue(receiverPlr)

                                currentTrade:Destroy()
                        end
                end

        elseif instruction == "reject trade" then
                for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                        if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
                                trade:Destroy()
                                break
                        end
                end
        end
end)
