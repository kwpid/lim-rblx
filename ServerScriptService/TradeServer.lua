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

local createNotificationEvent = remoteEvents:FindFirstChild("CreateNotification")
if not createNotificationEvent then
        createNotificationEvent = Instance.new("RemoteEvent")
        createNotificationEvent.Name = "CreateNotification"
        createNotificationEvent.Parent = remoteEvents
end

local tradeRequestsFolder = ReplicatedStorage:FindFirstChild("TRADE REQUESTS")
if not tradeRequestsFolder then
        tradeRequestsFolder = Instance.new("Folder")
        tradeRequestsFolder.Name = "TRADE REQUESTS"
        tradeRequestsFolder.Parent = ReplicatedStorage
end

local ongoingTradesFolder = ReplicatedStorage:FindFirstChild("ONGOING TRADES")
if not ongoingTradesFolder then
        ongoingTradesFolder = Instance.new("Folder")
        ongoingTradesFolder.Name = "ONGOING TRADES"
        ongoingTradesFolder.Parent = ReplicatedStorage
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

function unequipItemFromCharacter(player, robloxId)
        local character = player.Character
        if not character then
                return
        end

        local head = character:FindFirstChild("Head")
        if head then
                local headlessId = head:FindFirstChild("HeadlessRobloxId")
                if headlessId and headlessId.Value == robloxId then
                        head.Transparency = 0

                        local face = head:FindFirstChildOfClass("Decal")
                        if face then
                                face.Transparency = 0
                        end

                        headlessId:Destroy()
                end
        end

        for _, child in ipairs(character:GetChildren()) do
                if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
                        local storedId = child:FindFirstChild("OriginalRobloxId")
                        if storedId and storedId.Value == robloxId then
                                child:Destroy()
                        end
                end
        end

        local backpack = player:FindFirstChild("Backpack")
        if backpack then
                for _, child in ipairs(backpack:GetChildren()) do
                        if child:IsA("Tool") then
                                local storedId = child:FindFirstChild("OriginalRobloxId")
                                if storedId and storedId.Value == robloxId then
                                        child:Destroy()
                                end
                        end
                end
        end
end

tradeEvent.OnServerEvent:Connect(function(plr, instruction, data)
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

                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(playerSent, {
                                                Type = "VICTORY",
                                                Title = "Trade Request",
                                                Body = plr.Name .. " sent you a trade request!"
                                        })
                                end
                        end
                end
        elseif instruction == "reject trade request" then
                for _, request in pairs(tradeRequestsFolder:GetChildren()) do
                        if request.Name == plr.Name or request.Value == plr.Name then
                                local otherPlayerName = request.Name == plr.Name and request.Value or request.Name
                                local otherPlayer = Players:FindFirstChild(otherPlayerName)

                                request:Destroy()

                                if createNotificationEvent and otherPlayer then
                                        createNotificationEvent:FireClient(otherPlayer, {
                                                Type = "ERROR",
                                                Title = "Trade Declined",
                                                Body = plr.Name .. " declined your trade request."
                                        })
                                end
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

                        if createNotificationEvent then
                                createNotificationEvent:FireClient(senderPlr, {
                                        Type = "VICTORY",
                                        Title = "Trade Accepted",
                                        Body = receiverPlr.Name .. " accepted your trade request!"
                                })
                        end

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
                        local senderPlr = Players:FindFirstChild(currentTrade.Sender.Value)
                        local receiverPlr = Players:FindFirstChild(currentTrade.Receiver.Value)

                        if not senderPlr or not receiverPlr then
                                currentTrade:Destroy()
                                return
                        end

                        local countdownTime = 3
                        for i = countdownTime, 1, -1 do
                                if not currentTrade or not currentTrade.Parent then break end
                                if not currentTrade.Sender:FindFirstChild("ACCEPTED") or not currentTrade.Receiver:FindFirstChild("ACCEPTED") then
                                        tradeEvent:FireClient(senderPlr, "countdown cancelled")
                                        tradeEvent:FireClient(receiverPlr, "countdown cancelled")
                                        return
                                end

                                tradeEvent:FireClient(senderPlr, "countdown update", i)
                                tradeEvent:FireClient(receiverPlr, "countdown update", i)
                                task.wait(1)
                        end

                        if currentTrade and currentTrade.Parent and currentTrade.Sender:FindFirstChild("ACCEPTED") and currentTrade.Receiver:FindFirstChild("ACCEPTED") then
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
                                        local inventoryIndex, inventoryItem = findItemInInventory(senderPlr,
                                                item.RobloxId, item.SerialNumber)
                                        if inventoryIndex and inventoryItem then
                                                if item.SerialNumber then
                                                        table.remove(senderData.Inventory, inventoryIndex)
                                                else
                                                        local actualItem = senderData.Inventory[inventoryIndex]
                                                        if actualItem.Amount and actualItem.Amount > item.Amount then
                                                                actualItem.Amount = actualItem.Amount - item.Amount
                                                                ItemDatabase:DecrementTotalCopies(item.RobloxId,
                                                                        item.Amount)
                                                        else
                                                                table.remove(senderData.Inventory, inventoryIndex)
                                                                ItemDatabase:DecrementOwners(item.RobloxId)
                                                                ItemDatabase:DecrementTotalCopies(item.RobloxId,
                                                                        actualItem.Amount or 1)
                                                        end
                                                end

                                                if senderData.EquippedItems then
                                                        for i = #senderData.EquippedItems, 1, -1 do
                                                                if senderData.EquippedItems[i] == item.RobloxId then
                                                                        table.remove(senderData.EquippedItems, i)
                                                                        unequipItemFromCharacter(senderPlr, item
                                                                        .RobloxId)
                                                                end
                                                        end
                                                end
                                        end
                                end

                                for _, item in ipairs(receiverItems) do
                                        local inventoryIndex, inventoryItem = findItemInInventory(receiverPlr,
                                                item.RobloxId, item.SerialNumber)
                                        if inventoryIndex and inventoryItem then
                                                if item.SerialNumber then
                                                        table.remove(receiverData.Inventory, inventoryIndex)
                                                else
                                                        local actualItem = receiverData.Inventory[inventoryIndex]
                                                        if actualItem.Amount and actualItem.Amount > item.Amount then
                                                                actualItem.Amount = actualItem.Amount - item.Amount
                                                                ItemDatabase:DecrementTotalCopies(item.RobloxId,
                                                                        item.Amount)
                                                        else
                                                                table.remove(receiverData.Inventory, inventoryIndex)
                                                                ItemDatabase:DecrementOwners(item.RobloxId)
                                                                ItemDatabase:DecrementTotalCopies(item.RobloxId,
                                                                        actualItem.Amount or 1)
                                                        end
                                                end

                                                if receiverData.EquippedItems then
                                                        for i = #receiverData.EquippedItems, 1, -1 do
                                                                if receiverData.EquippedItems[i] == item.RobloxId then
                                                                        table.remove(receiverData.EquippedItems, i)
                                                                        unequipItemFromCharacter(receiverPlr,
                                                                                item.RobloxId)
                                                                end
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
                                        }, true)
                                end

                                for _, item in ipairs(receiverItems) do
                                        DataStoreAPI:AddItem(senderPlr, {
                                                RobloxId = item.RobloxId,
                                                Name = item.Name,
                                                Value = item.Value,
                                                Rarity = item.Rarity,
                                                SerialNumber = item.SerialNumber,
                                                Amount = item.Amount
                                        }, true)
                                end

                                DataStoreAPI:UpdateInventoryValue(senderPlr)
                                DataStoreAPI:UpdateInventoryValue(receiverPlr)

                                local senderGaveValue = 0
                                for _, item in ipairs(senderItems) do
                                        senderGaveValue = senderGaveValue + (item.Value * item.Amount)
                                end

                                local senderReceivedValue = 0
                                for _, item in ipairs(receiverItems) do
                                        senderReceivedValue = senderReceivedValue + (item.Value * item.Amount)
                                end

                                local receiverGaveValue = senderReceivedValue
                                local receiverReceivedValue = senderGaveValue

                                local timestamp = os.date("%m/%d/%Y %I:%M %p")

                                table.insert(senderData.TradeHistory, 1, {
                                        OtherPlayer = receiverPlr.Name,
                                        OtherPlayerId = receiverPlr.UserId,
                                        Date = timestamp,
                                        GaveItems = senderItems,
                                        ReceivedItems = receiverItems,
                                        GaveValue = senderGaveValue,
                                        ReceivedValue = senderReceivedValue
                                })

                                table.insert(receiverData.TradeHistory, 1, {
                                        OtherPlayer = senderPlr.Name,
                                        OtherPlayerId = senderPlr.UserId,
                                        Date = timestamp,
                                        GaveItems = receiverItems,
                                        ReceivedItems = senderItems,
                                        GaveValue = receiverGaveValue,
                                        ReceivedValue = receiverReceivedValue
                                })

                                if #senderData.TradeHistory > 50 then
                                        table.remove(senderData.TradeHistory)
                                end
                                if #receiverData.TradeHistory > 50 then
                                        table.remove(receiverData.TradeHistory)
                                end

                                tradeEvent:FireClient(senderPlr, "trade completed")
                                tradeEvent:FireClient(receiverPlr, "trade completed")

                                currentTrade:Destroy()
                        end
                end
        elseif instruction == "reject trade" then
                for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
                        if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
                                local otherPlayerName = trade.Sender.Value == plr.Name and trade.Receiver.Value or
                                trade.Sender.Value
                                local otherPlayer = Players:FindFirstChild(otherPlayerName)

                                if createNotificationEvent and otherPlayer then
                                        createNotificationEvent:FireClient(otherPlayer, {
                                                Type = "ERROR",
                                                Title = "Trade Cancelled",
                                                Body = plr.Name .. " cancelled the trade."
                                        })
                                end

                                trade:Destroy()
                                break
                        end
                end
        elseif instruction == "get trade history" then
                local playerData = _G.PlayerData[plr.UserId]
                if playerData and playerData.TradeHistory then
                        tradeEvent:FireClient(plr, "load trade history", playerData.TradeHistory)
                else
                        tradeEvent:FireClient(plr, "load trade history", {})
                end
        end
end)
