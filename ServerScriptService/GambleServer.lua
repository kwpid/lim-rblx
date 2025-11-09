local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)
local GambleConfig = require(ReplicatedStorage.GambleConfig)

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
end

local gambleEvent = remoteEvents:FindFirstChild("GambleEvent")
if not gambleEvent then
        gambleEvent = Instance.new("RemoteEvent")
        gambleEvent.Name = "GambleEvent"
        gambleEvent.Parent = remoteEvents
end

local getRollableItemsFunction = remoteEvents:FindFirstChild("GetRollableItems")
if not getRollableItemsFunction then
        getRollableItemsFunction = Instance.new("RemoteFunction")
        getRollableItemsFunction.Name = "GetRollableItems"
        getRollableItemsFunction.Parent = remoteEvents
end

local gambleRequestsFolder = ReplicatedStorage:FindFirstChild("GAMBLE REQUESTS")
if not gambleRequestsFolder then
        gambleRequestsFolder = Instance.new("Folder")
        gambleRequestsFolder.Name = "GAMBLE REQUESTS"
        gambleRequestsFolder.Parent = ReplicatedStorage
end

local ongoingGamblesFolder = ReplicatedStorage:FindFirstChild("ONGOING GAMBLES")
if not ongoingGamblesFolder then
        ongoingGamblesFolder = Instance.new("Folder")
        ongoingGamblesFolder.Name = "ONGOING GAMBLES"
        ongoingGamblesFolder.Parent = ReplicatedStorage
end

local createNotificationEvent = remoteEvents:FindFirstChild("CreateNotification")
if not createNotificationEvent then
        createNotificationEvent = Instance.new("RemoteEvent")
        createNotificationEvent.Name = "CreateNotification"
        createNotificationEvent.Parent = remoteEvents
end

function removeGambles(plr)
        for _, gamble in pairs(ongoingGamblesFolder:GetChildren()) do
                if gamble.Player1.Value.Value == plr.Name or gamble.Player2.Value.Value == plr.Name then
                        local otherPlayerName = gamble.Player1.Value.Value == plr.Name and gamble.Player2.Value.Value or gamble.Player1.Value.Value
                        local otherPlayer = Players:FindFirstChild(otherPlayerName)
                        
                        if gamble:FindFirstChild("GAME_STARTED") and otherPlayer then
                                local winner = otherPlayer
                                local loser = plr
                                
                                local winnerItems = winner.Name == gamble.Player1.Value.Value and gamble.Player1.Items or gamble.Player2.Items
                                local loserItems = loser.Name == gamble.Player1.Value.Value and gamble.Player1.Items or gamble.Player2.Items
                                
                                for _, itemFolder in ipairs(loserItems:GetChildren()) do
                                        local robloxId = itemFolder.RobloxId.Value
                                        local serialNumber = itemFolder:FindFirstChild("SerialNumber") and itemFolder.SerialNumber.Value or nil
                                        
                                        local index, item = findItemInInventory(loser, robloxId, serialNumber)
                                        if index then
                                                local loserData = DataStoreAPI:GetPlayerData(loser)
                                                if loserData and loserData.Inventory[index] then
                                                        if serialNumber then
                                                                table.remove(loserData.Inventory, index)
                                                        else
                                                                local currentAmount = loserData.Inventory[index].Amount or 1
                                                                if currentAmount > 1 then
                                                                        loserData.Inventory[index].Amount = currentAmount - 1
                                                                        ItemDatabase:DecrementTotalCopies(robloxId, 1)
                                                                else
                                                                        table.remove(loserData.Inventory, index)
                                                                        ItemDatabase:DecrementTotalCopies(robloxId, 1)
                                                                end
                                                        end
                                                        
                                                        DataStoreAPI:UpdateInventoryValue(loser)
                                                end
                                                
                                                local itemData = {
                                                        RobloxId = robloxId,
                                                        Name = itemFolder.ItemName.Value,
                                                        Value = itemFolder.ItemValue.Value,
                                                        Rarity = itemFolder.Rarity.Value
                                                }
                                                
                                                if serialNumber then
                                                        itemData.SerialNumber = serialNumber
                                                end
                                                
                                                DataStoreAPI:AddItem(winner, itemData)
                                        end
                                end
                                
                                local DataStoreManager = require(script.Parent.DataStoreManager)
                                DataStoreManager:SavePlayerData(loser)
                                DataStoreManager:SavePlayerData(winner)
                                
                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(winner, {
                                                Type = "VICTORY",
                                                Title = "You Won!",
                                                Body = plr.Name .. " left the game. You win by default and receive all items!"
                                        })
                                end
                        elseif otherPlayer then
                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(otherPlayer, {
                                                Type = "ERROR",
                                                Title = "Gamble Cancelled",
                                                Body = plr.Name .. " left the game. Gamble cancelled."
                                        })
                                end
                        end
                        
                        gamble:Destroy()
                end
        end

        for _, request in pairs(gambleRequestsFolder:GetChildren()) do
                if request.Name == plr.Name or request.Value == plr.Name then
                        request:Destroy()
                end
        end
end

Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
                char:WaitForChild("Humanoid").Died:Connect(function()
                        removeGambles(plr)
                end)
        end)
end)

Players.PlayerRemoving:Connect(removeGambles)

function findGambleForPlayer(plr)
        for _, gamble in pairs(ongoingGamblesFolder:GetChildren()) do
                if gamble.Player1.Value.Value == plr.Name or gamble.Player2.Value.Value == plr.Name then
                        return gamble
                end
        end
        return nil
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

function validateItemSelection(player, robloxId, serialNumber)
        local inventory = DataStoreAPI:GetInventory(player)
        for _, item in ipairs(inventory) do
                if item.RobloxId == robloxId then
                        if serialNumber and item.SerialNumber == serialNumber then
                                return true, item
                        elseif not serialNumber and not item.SerialNumber then
                                return true, item
                        end
                end
        end
        return false, nil
end

function resetConfirmationStates(gamble)
        if gamble.Player1:FindFirstChild("CONFIRMED") then
                gamble.Player1.CONFIRMED:Destroy()
        end
        if gamble.Player2:FindFirstChild("CONFIRMED") then
                gamble.Player2.CONFIRMED:Destroy()
        end
end

function isPlayerInGamble(plr, gamble)
        if not gamble then
                return false
        end
        return gamble.Player1.Value.Value == plr.Name or gamble.Player2.Value.Value == plr.Name
end

function calculateStakeValue(itemsFolder)
        local totalValue = 0
        for _, itemFolder in ipairs(itemsFolder:GetChildren()) do
                local itemValue = itemFolder:FindFirstChild("ItemValue")
                if itemValue then
                        totalValue = totalValue + itemValue.Value
                end
        end
        return totalValue
end

function validateStakeTolerance(value1, value2)
        if value1 == 0 or value2 == 0 then
                return false
        end
        
        local minValue = math.min(value1, value2)
        local maxValue = math.max(value1, value2)
        
        return (minValue / maxValue) >= 0.75
end

function getRollableItems()
        local allItems = ItemDatabase:GetAllItems()
        local rollableItems = {}
        
        for _, item in ipairs(allItems) do
                if item.Rarity ~= "Limited" and item.Rarity ~= "Vanity" then
                        if not item.Stock or item.Stock == 0 or (item.CurrentStock and item.CurrentStock < item.Stock) then
                                table.insert(rollableItems, {
                                        RobloxId = item.RobloxId,
                                        Name = item.Name,
                                        Value = item.Value
                                })
                        end
                end
        end
        
        return rollableItems
end

function getRandomItemFromDatabase()
        local rollableItems = getRollableItems()
        
        if #rollableItems == 0 then
                return nil
        end
        
        return rollableItems[math.random(1, #rollableItems)]
end

getRollableItemsFunction.OnServerInvoke = function(player)
        return getRollableItems()
end

gambleEvent.OnServerEvent:Connect(function(plr, instruction, data)
        if instruction == "send gamble request" then
                local playerSent = data[1]

                if playerSent and playerSent ~= plr then
                        local inGamble = false

                        for _, gamble in pairs(ongoingGamblesFolder:GetChildren()) do
                                if gamble.Player1.Value.Value == playerSent.Name or gamble.Player1.Value.Value == plr.Name or
                                        gamble.Player2.Value.Value == playerSent.Name or gamble.Player2.Value.Value == plr.Name then
                                        inGamble = true
                                        break
                                end
                        end

                        for _, request in pairs(gambleRequestsFolder:GetChildren()) do
                                if request.Name == playerSent.Name or request.Name == plr.Name or
                                        request.Value == playerSent.Name or request.Value == plr.Name then
                                        inGamble = true
                                        break
                                end
                        end

                        if not inGamble then
                                local newRequest = Instance.new("StringValue")
                                newRequest.Name = plr.Name
                                newRequest.Value = playerSent.Name
                                newRequest.Parent = gambleRequestsFolder

                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(playerSent, {
                                                Type = "VICTORY",
                                                Title = "Gamble Request",
                                                Body = plr.Name .. " wants to Risk It 1v1!"
                                        })
                                end
                        end
                end
        elseif instruction == "reject gamble request" then
                for _, request in pairs(gambleRequestsFolder:GetChildren()) do
                        if request.Name == plr.Name or request.Value == plr.Name then
                                local otherPlayerName = request.Name == plr.Name and request.Value or request.Name
                                local otherPlayer = Players:FindFirstChild(otherPlayerName)

                                request:Destroy()

                                if createNotificationEvent and otherPlayer then
                                        createNotificationEvent:FireClient(otherPlayer, {
                                                Type = "ERROR",
                                                Title = "Gamble Declined",
                                                Body = plr.Name .. " declined your gamble request."
                                        })
                                end
                                break
                        end
                end
        elseif instruction == "accept gamble request" then
                local requestValue = nil
                for _, request in pairs(gambleRequestsFolder:GetChildren()) do
                        if request.Name == plr.Name or request.Value == plr.Name then
                                requestValue = request
                                break
                        end
                end

                if requestValue and requestValue.Parent == gambleRequestsFolder and requestValue.Value == plr.Name then
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
                                        Title = "Gamble Accepted",
                                        Body = receiverPlr.Name .. " accepted your gamble request!"
                                })
                        end

                        local newGamble = Instance.new("Folder")
                        newGamble.Name = senderPlr.Name .. "_" .. receiverPlr.Name

                        local player1 = Instance.new("Folder")
                        player1.Name = "Player1"
                        player1.Parent = newGamble

                        local player1Value = Instance.new("StringValue")
                        player1Value.Name = "Value"
                        player1Value.Value = senderPlr.Name
                        player1Value.Parent = player1

                        local player1Items = Instance.new("Folder")
                        player1Items.Name = "Items"
                        player1Items.Parent = player1

                        local player2 = Instance.new("Folder")
                        player2.Name = "Player2"
                        player2.Parent = newGamble

                        local player2Value = Instance.new("StringValue")
                        player2Value.Name = "Value"
                        player2Value.Value = receiverPlr.Name
                        player2Value.Parent = player2

                        local player2Items = Instance.new("Folder")
                        player2Items.Name = "Items"
                        player2Items.Parent = player2

                        newGamble.Parent = ongoingGamblesFolder
                end
        elseif instruction == "add item to gamble" then
                local gamble = findGambleForPlayer(plr)
                if not gamble or not isPlayerInGamble(plr, gamble) then
                        return
                end

                if gamble:FindFirstChild("GAME_STARTED") then
                        return
                end

                local robloxId = data.RobloxId
                local serialNumber = data.SerialNumber

                local isValid, itemData = validateItemSelection(plr, robloxId, serialNumber)
                if not isValid then
                        return
                end
                
                if not serialNumber then
                        local selectedCount = 0
                        local playerFolder = gamble.Player1.Value.Value == plr.Name and gamble.Player1 or gamble.Player2
                        local itemsFolder = playerFolder.Items
                        
                        for _, itemFolder in ipairs(itemsFolder:GetChildren()) do
                                if itemFolder.RobloxId.Value == robloxId and not itemFolder:FindFirstChild("SerialNumber") then
                                        selectedCount = selectedCount + 1
                                end
                        end
                        
                        local ownedAmount = itemData.Amount or 1
                        if selectedCount >= ownedAmount then
                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(plr, {
                                                Type = "ERROR",
                                                Title = "Cannot Add More",
                                                Body = "You've already added all copies of this item!"
                                        })
                                end
                                return
                        end
                end

                if itemData.Rarity == "Vanity" then
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(plr, {
                                        Type = "ERROR",
                                        Title = "Cannot Gamble",
                                        Body = "Vanity items cannot be gambled!"
                                })
                        end
                        return
                end
                
                if itemData.Rarity == "Common" then
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(plr, {
                                        Type = "ERROR",
                                        Title = "Cannot Gamble",
                                        Body = "Common items cannot be gambled!"
                                })
                        end
                        return
                end
                
                if itemData.Rarity == "Uncommon" and not GambleConfig.AllowUncommons then
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(plr, {
                                        Type = "ERROR",
                                        Title = "Cannot Gamble",
                                        Body = "Uncommon items cannot be gambled!"
                                })
                        end
                        return
                end

                local playerFolder = gamble.Player1.Value.Value == plr.Name and gamble.Player1 or gamble.Player2
                local itemsFolder = playerFolder.Items

                local itemName
                if serialNumber then
                        local existingItem = itemsFolder:FindFirstChild(tostring(robloxId) .. "_" .. tostring(serialNumber))
                        if existingItem then
                                return
                        end
                        itemName = tostring(robloxId) .. "_" .. tostring(serialNumber)
                else
                        local copyCounter = 1
                        while itemsFolder:FindFirstChild(tostring(robloxId) .. "_" .. copyCounter) do
                                copyCounter = copyCounter + 1
                        end
                        itemName = tostring(robloxId) .. "_" .. copyCounter
                end

                local itemValue = Instance.new("Folder")
                itemValue.Name = itemName

                local robloxIdVal = Instance.new("IntValue")
                robloxIdVal.Name = "RobloxId"
                robloxIdVal.Value = robloxId
                robloxIdVal.Parent = itemValue

                local nameVal = Instance.new("StringValue")
                nameVal.Name = "ItemName"
                nameVal.Value = itemData.Name
                nameVal.Parent = itemValue

                local valueVal = Instance.new("IntValue")
                valueVal.Name = "ItemValue"
                valueVal.Value = itemData.Value
                valueVal.Parent = itemValue

                local rarityVal = Instance.new("StringValue")
                rarityVal.Name = "Rarity"
                rarityVal.Value = itemData.Rarity
                rarityVal.Parent = itemValue

                if serialNumber then
                        local serialVal = Instance.new("IntValue")
                        serialVal.Name = "SerialNumber"
                        serialVal.Value = serialNumber
                        serialVal.Parent = itemValue
                end

                itemValue.Parent = itemsFolder

                resetConfirmationStates(gamble)
        elseif instruction == "remove item from gamble" then
                local gamble = findGambleForPlayer(plr)
                if not gamble or not isPlayerInGamble(plr, gamble) then
                        return
                end

                if gamble:FindFirstChild("GAME_STARTED") then
                        return
                end

                local robloxId = data.RobloxId
                local serialNumber = data.SerialNumber

                local playerFolder = gamble.Player1.Value.Value == plr.Name and gamble.Player1 or gamble.Player2
                local itemsFolder = playerFolder.Items

                local itemToRemove
                if serialNumber then
                        itemToRemove = itemsFolder:FindFirstChild(tostring(robloxId) .. "_" .. tostring(serialNumber))
                else
                        for _, itemFolder in ipairs(itemsFolder:GetChildren()) do
                                if itemFolder.RobloxId.Value == robloxId and not itemFolder:FindFirstChild("SerialNumber") then
                                        itemToRemove = itemFolder
                                        break
                                end
                        end
                end
                
                if itemToRemove then
                        itemToRemove:Destroy()
                end

                resetConfirmationStates(gamble)
        elseif instruction == "confirm items" then
                local gamble = findGambleForPlayer(plr)
                if not gamble or not isPlayerInGamble(plr, gamble) then
                        return
                end

                if gamble:FindFirstChild("GAME_STARTED") then
                        return
                end

                local playerFolder = gamble.Player1.Value.Value == plr.Name and gamble.Player1 or gamble.Player2
                local itemsFolder = playerFolder.Items

                if #itemsFolder:GetChildren() == 0 then
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(plr, {
                                        Type = "ERROR",
                                        Title = "No Items",
                                        Body = "You must select at least one item!"
                                })
                        end
                        return
                end

                for _, itemFolder in ipairs(itemsFolder:GetChildren()) do
                        local robloxId = itemFolder.RobloxId.Value
                        local serialNumber = itemFolder:FindFirstChild("SerialNumber") and itemFolder.SerialNumber.Value or nil
                        
                        local isValid = validateItemSelection(plr, robloxId, serialNumber)
                        if not isValid then
                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(plr, {
                                                Type = "ERROR",
                                                Title = "Invalid Item",
                                                Body = "You no longer own one of the selected items!"
                                        })
                                end
                                return
                        end
                end

                local player1Items = gamble.Player1.Items:GetChildren()
                local player2Items = gamble.Player2.Items:GetChildren()

                if #player1Items > 0 and #player2Items > 0 then
                        local player1Value = calculateStakeValue(gamble.Player1.Items)
                        local player2Value = calculateStakeValue(gamble.Player2.Items)

                        if not validateStakeTolerance(player1Value, player2Value) then
                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(plr, {
                                                Type = "ERROR",
                                                Title = "Value Mismatch",
                                                Body = "Values must be within 25% of each other!"
                                        })
                                end
                                return
                        end
                end

                if not playerFolder:FindFirstChild("CONFIRMED") then
                        local confirmed = Instance.new("BoolValue")
                        confirmed.Name = "CONFIRMED"
                        confirmed.Value = true
                        confirmed.Parent = playerFolder
                end

                local player1Confirmed = gamble.Player1:FindFirstChild("CONFIRMED")
                local player2Confirmed = gamble.Player2:FindFirstChild("CONFIRMED")

                if player1Confirmed and player2Confirmed then
                        print("Both players confirmed! Checking values...")
                        local player1Value = calculateStakeValue(gamble.Player1.Items)
                        local player2Value = calculateStakeValue(gamble.Player2.Items)
                        
                        print("Player1 value:", player1Value, "Player2 value:", player2Value)
                        
                        if not validateStakeTolerance(player1Value, player2Value) then
                                print("Value mismatch! Resetting confirmations")
                                resetConfirmationStates(gamble)
                                if createNotificationEvent then
                                        createNotificationEvent:FireClient(plr, {
                                                Type = "ERROR",
                                                Title = "Value Mismatch",
                                                Body = "Values must be within 25% of each other!"
                                        })
                                end
                                return
                        end
                        
                        print("Values validated! Starting game...")
                        task.wait(0.5)
                        
                        local gameStarted = Instance.new("BoolValue")
                        gameStarted.Name = "GAME_STARTED"
                        gameStarted.Value = true
                        gameStarted.Parent = gamble
                        
                        print("GAME_STARTED created!")
                        
                        local player1Wins = Instance.new("IntValue")
                        player1Wins.Name = "Player1Wins"
                        player1Wins.Value = 0
                        player1Wins.Parent = gamble
                        
                        local player2Wins = Instance.new("IntValue")
                        player2Wins.Name = "Player2Wins"
                        player2Wins.Value = 0
                        player2Wins.Parent = gamble
                else
                        print("Waiting for both players to confirm...")
                end
        elseif instruction == "cancel gamble" then
                local gamble = findGambleForPlayer(plr)
                if gamble and isPlayerInGamble(plr, gamble) then
                        local otherPlayerName = gamble.Player1.Value.Value == plr.Name and gamble.Player2.Value.Value or gamble.Player1.Value.Value
                        local otherPlayer = Players:FindFirstChild(otherPlayerName)

                        if createNotificationEvent and otherPlayer then
                                createNotificationEvent:FireClient(otherPlayer, {
                                        Type = "ERROR",
                                        Title = "Gamble Cancelled",
                                        Body = plr.Name .. " cancelled the gamble."
                                })
                        end

                        gamble:Destroy()
                end
        elseif instruction == "request round" then
                local gamble = findGambleForPlayer(plr)
                if not gamble or not isPlayerInGamble(plr, gamble) or not gamble:FindFirstChild("GAME_STARTED") then
                        return
                end

                local roundNumber = data.RoundNumber

                local player1Item = getRandomItemFromDatabase()
                local player2Item = getRandomItemFromDatabase()

                if not player1Item or not player2Item then
                        return
                end

                local player1 = Players:FindFirstChild(gamble.Player1.Value.Value)
                local player2 = Players:FindFirstChild(gamble.Player2.Value.Value)

                if player1 and player2 then
                        local player1WinsCounter = gamble:FindFirstChild("Player1Wins")
                        local player2WinsCounter = gamble:FindFirstChild("Player2Wins")
                        
                        if player1Item.Value > player2Item.Value then
                                if player1WinsCounter then
                                        player1WinsCounter.Value = player1WinsCounter.Value + 1
                                end
                        elseif player2Item.Value > player1Item.Value then
                                if player2WinsCounter then
                                        player2WinsCounter.Value = player2WinsCounter.Value + 1
                                end
                        end
                        
                        gambleEvent:FireClient(player1, "round result", {
                                RoundNumber = roundNumber,
                                YourItem = {
                                        RobloxId = player1Item.RobloxId,
                                        Name = player1Item.Name,
                                        Value = player1Item.Value
                                },
                                TheirItem = {
                                        RobloxId = player2Item.RobloxId,
                                        Name = player2Item.Name,
                                        Value = player2Item.Value
                                },
                                YouWon = player1Item.Value > player2Item.Value,
                                YourWins = player1WinsCounter and player1WinsCounter.Value or 0,
                                TheirWins = player2WinsCounter and player2WinsCounter.Value or 0
                        })

                        gambleEvent:FireClient(player2, "round result", {
                                RoundNumber = roundNumber,
                                YourItem = {
                                        RobloxId = player2Item.RobloxId,
                                        Name = player2Item.Name,
                                        Value = player2Item.Value
                                },
                                TheirItem = {
                                        RobloxId = player1Item.RobloxId,
                                        Name = player1Item.Name,
                                        Value = player1Item.Value
                                },
                                YouWon = player2Item.Value > player1Item.Value,
                                YourWins = player2WinsCounter and player2WinsCounter.Value or 0,
                                TheirWins = player1WinsCounter and player1WinsCounter.Value or 0
                        })
                end
        elseif instruction == "finish game" then
                local gamble = findGambleForPlayer(plr)
                if not gamble or not isPlayerInGamble(plr, gamble) or not gamble:FindFirstChild("GAME_STARTED") then
                        return
                end

                local player1 = Players:FindFirstChild(gamble.Player1.Value.Value)
                local player2 = Players:FindFirstChild(gamble.Player2.Value.Value)

                if not player1 or not player2 then
                        gamble:Destroy()
                        return
                end

                local player1WinsCounter = gamble:FindFirstChild("Player1Wins")
                local player2WinsCounter = gamble:FindFirstChild("Player2Wins")
                
                if not player1WinsCounter or not player2WinsCounter then
                        gamble:Destroy()
                        return
                end

                local player1Wins = player1WinsCounter.Value
                local player2Wins = player2WinsCounter.Value
                
                if player1Wins < 7 and player2Wins < 7 then
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(plr, {
                                        Type = "ERROR",
                                        Title = "Game Not Finished",
                                        Body = "No one has reached 7 wins yet!"
                                })
                        end
                        return
                end

                local winner = player1Wins >= 7 and player1 or (player2Wins >= 7 and player2 or nil)
                local loser = winner == player1 and player2 or (winner == player2 and player1 or nil)

                if winner and loser then
                        local winnerItems = winner == player1 and gamble.Player1.Items or gamble.Player2.Items
                        local loserItems = loser == player1 and gamble.Player1.Items or gamble.Player2.Items

                        for _, itemFolder in ipairs(loserItems:GetChildren()) do
                                local robloxId = itemFolder.RobloxId.Value
                                local serialNumber = itemFolder:FindFirstChild("SerialNumber") and itemFolder.SerialNumber.Value or nil

                                local index, item = findItemInInventory(loser, robloxId, serialNumber)
                                if index then
                                        local loserData = DataStoreAPI:GetPlayerData(loser)
                                        if loserData and loserData.Inventory[index] then
                                                if serialNumber then
                                                        table.remove(loserData.Inventory, index)
                                                else
                                                        local currentAmount = loserData.Inventory[index].Amount or 1
                                                        if currentAmount > 1 then
                                                                loserData.Inventory[index].Amount = currentAmount - 1
                                                                ItemDatabase:DecrementTotalCopies(robloxId, 1)
                                                        else
                                                                table.remove(loserData.Inventory, index)
                                                                ItemDatabase:DecrementTotalCopies(robloxId, 1)
                                                        end
                                                end
                                                
                                                DataStoreAPI:UpdateInventoryValue(loser)
                                        end
                                        
                                        local itemData = {
                                                RobloxId = robloxId,
                                                Name = itemFolder.ItemName.Value,
                                                Value = itemFolder.ItemValue.Value,
                                                Rarity = itemFolder.Rarity.Value
                                        }
                                        
                                        if serialNumber then
                                                itemData.SerialNumber = serialNumber
                                        end
                                        
                                        DataStoreAPI:AddItem(winner, itemData)
                                end
                        end

                        local DataStoreManager = require(script.Parent.DataStoreManager)
                        DataStoreManager:SavePlayerData(winner)
                        DataStoreManager:SavePlayerData(loser)
                        
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(winner, {
                                        Type = "VICTORY",
                                        Title = "You Won!",
                                        Body = "You won the gamble against " .. loser.Name .. "!"
                                })

                                createNotificationEvent:FireClient(loser, {
                                        Type = "ERROR",
                                        Title = "You Lost",
                                        Body = "You lost the gamble to " .. winner.Name .. "."
                                })
                        end
                else
                        if createNotificationEvent then
                                createNotificationEvent:FireClient(player1, {
                                        Type = "VICTORY",
                                        Title = "Tie Game",
                                        Body = "The gamble ended in a tie!"
                                })

                                createNotificationEvent:FireClient(player2, {
                                        Type = "VICTORY",
                                        Title = "Tie Game",
                                        Body = "The gamble ended in a tie!"
                                })
                        end
                end

                gamble:Destroy()
        end
end)

print("GambleServer loaded successfully")
