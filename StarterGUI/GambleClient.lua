local client = game.Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gambleRequestsFolder = ReplicatedStorage:WaitForChild("GAMBLE REQUESTS", 30)
if not gambleRequestsFolder then
        warn("gamble requests folder not found")
        return
end

local ongoingGamblesFolder = ReplicatedStorage:WaitForChild("ONGOING GAMBLES", 30)
if not ongoingGamblesFolder then
        warn("ongoing gambles folder not found")
        return
end

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
if not remoteEvents then
        warn("remoteevents folder not found")
        return
end

local gambleEvent = remoteEvents:WaitForChild("GambleEvent", 30)
if not gambleEvent then
        warn("gambleevent not found")
        return
end

local getInventoryFunction = remoteEvents:WaitForChild("GetInventoryFunction", 30)
if not getInventoryFunction then
        warn("getinventoryfunction not found")
        return
end

local gui = script.Parent

local gambleFrame = gui:WaitForChild("Gamble")
local sendRequestFrame = gambleFrame:WaitForChild("SendRequest")
local requestFrame = gambleFrame:WaitForChild("RequestFrame")
local gameMain = gambleFrame:WaitForChild("Main")

gambleFrame.Visible = false
sendRequestFrame.Visible = false
requestFrame.Visible = false
gameMain.Visible = false

local rarityColors = {
        ["Common"] = Color3.fromRGB(170, 170, 170),
        ["Uncommon"] = Color3.fromRGB(85, 170, 85),
        ["Rare"] = Color3.fromRGB(85, 85, 255),
        ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
        ["Epic"] = Color3.fromRGB(255, 170, 0),
        ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
        ["Mythic"] = Color3.fromRGB(255, 0, 0),
        ["Insane"] = Color3.fromRGB(255, 0, 255),
        ["Limited"] = Color3.fromRGB(255, 215, 0),
        ["Vanity"] = Color3.fromRGB(255, 105, 180)
}

local function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

local playerListButtons = {}
local selectedItemsButtons = {}
local handlerItemsButtons = {}
local currentGamble = nil
local isInGame = false
local currentRound = 1
local yourWins = 0
local theirWins = 0

local function populatePlayerList()
        local playerList = sendRequestFrame:FindFirstChild("PlayerList")
        local playerFrameSample = sendRequestFrame:FindFirstChild("PlayerFrame")
        
        if not playerList or not playerFrameSample then
                warn("PlayerList or PlayerFrame sample not found")
                return
        end
        
        for _, btn in pairs(playerListButtons) do
                if btn then
                        btn:Destroy()
                end
        end
        playerListButtons = {}
        
        local players = game.Players:GetPlayers()
        for i, player in ipairs(players) do
                if player ~= client then
                        local playerFrame = playerFrameSample:Clone()
                        playerFrame.Name = player.Name
                        playerFrame.Visible = true
                        playerFrame.LayoutOrder = i
                        playerFrame.Parent = playerList
                        
                        local nameLabel = playerFrame:FindFirstChild("PlayerName")
                        if nameLabel then
                                nameLabel.Text = player.Name
                        end
                        
                        local sendButton = playerFrame:FindFirstChild("Send")
                        if sendButton then
                                sendButton.MouseButton1Click:Connect(function()
                                        gambleEvent:FireServer("send gamble request", {player})
                                end)
                        end
                        
                        table.insert(playerListButtons, playerFrame)
                end
        end
end

gambleRequestsFolder.ChildAdded:Connect(function(child)
        if child.Value == client.Name then
                requestFrame:FindFirstChild("RequestText").Text = child.Name .. " wants to Risk It 1v1!"
                
                local acceptButton = requestFrame:FindFirstChild("Accept")
                local rejectButton = requestFrame:FindFirstChild("Reject")
                
                if acceptButton then
                        acceptButton.Visible = true
                end
                if rejectButton then
                        rejectButton.Visible = true
                end
                
                requestFrame.Visible = true
        elseif child.Name == client.Name then
                requestFrame:FindFirstChild("RequestText").Text = "You sent a request to " .. child.Value
                
                local acceptButton = requestFrame:FindFirstChild("Accept")
                local rejectButton = requestFrame:FindFirstChild("Reject")
                
                if acceptButton then
                        acceptButton.Visible = false
                end
                if rejectButton then
                        rejectButton.Visible = true
                end
                
                requestFrame.Visible = true
        end
end)

gambleRequestsFolder.ChildRemoved:Connect(function(child)
        if child.Value == client.Name or child.Name == client.Name then
                requestFrame.Visible = false
        end
end)

local acceptButton = requestFrame:FindFirstChild("Accept")
if acceptButton then
        acceptButton.MouseButton1Click:Connect(function()
                gambleEvent:FireServer("accept gamble request")
        end)
end

local rejectButton = requestFrame:FindFirstChild("Reject")
if rejectButton then
        rejectButton.MouseButton1Click:Connect(function()
                gambleEvent:FireServer("reject gamble request")
        end)
end

local function updateSelectedItemsDisplay()
        if not currentGamble then return end
        
        local playerFolder = currentGamble.Player1.Value == client.Name and currentGamble.Player1 or currentGamble.Player2
        local opponentFolder = currentGamble.Player1.Value == client.Name and currentGamble.Player2 or currentGamble.Player1
        
        local selectItems = gameMain:FindFirstChild("SelectItems")
        if not selectItems then return end
        
        local selectedItemsFrame = selectItems:FindFirstChild("Selected_Items")
        local selectedItemsScroll = selectedItemsFrame and selectedItemsFrame:FindFirstChild("SelectedItems")
        local totalChosenValue = selectedItemsFrame and selectedItemsFrame:FindFirstChild("TotalChosenValue")
        
        local opponentItemsFrame = selectItems:FindFirstChild("Opponent_Items")
        local oppSelectedScroll = opponentItemsFrame and opponentItemsFrame:FindFirstChild("Opp_SelectedItem")
        local oppTotalValue = opponentItemsFrame and opponentItemsFrame:FindFirstChild("TotalChosenValue")
        
        if selectedItemsScroll then
                for _, btn in pairs(selectedItemsButtons) do
                        if btn then
                                btn:Destroy()
                        end
                end
                selectedItemsButtons = {}
                
                local sample = script:FindFirstChild("Sample")
                if not sample then return end
                
                local totalValue = 0
                local items = playerFolder.Items:GetChildren()
                
                for i, itemFolder in ipairs(items) do
                        local button = sample:Clone()
                        button.Name = itemFolder.Name
                        button.LayoutOrder = i
                        button.Visible = true
                        button.Parent = selectedItemsScroll
                        
                        local robloxId = itemFolder.RobloxId.Value
                        button.Image = "rbxthumb://type=Asset&id=" .. robloxId .. "&w=150&h=150"
                        
                        local rarity = itemFolder.Rarity.Value
                        local uiStroke = button:FindFirstChildOfClass("UIStroke")
                        if uiStroke then
                                uiStroke.Color = rarityColors[rarity] or Color3.new(1, 1, 1)
                        end
                        
                        local serialLabel = button:FindFirstChild("Serial")
                        if serialLabel then
                                local serial = itemFolder:FindFirstChild("SerialNumber")
                                if serial then
                                        serialLabel.Text = "#" .. serial.Value
                                        serialLabel.Visible = true
                                else
                                        serialLabel.Visible = false
                                end
                        end
                        
                        local qtyLabel = button:FindFirstChild("Qty")
                        if qtyLabel then
                                qtyLabel.Visible = false
                        end
                        
                        button.MouseButton1Click:Connect(function()
                                gambleEvent:FireServer("remove item from gamble", {
                                        RobloxId = robloxId,
                                        SerialNumber = itemFolder:FindFirstChild("SerialNumber") and itemFolder.SerialNumber.Value or nil
                                })
                        end)
                        
                        table.insert(selectedItemsButtons, button)
                        totalValue = totalValue + itemFolder.ItemValue.Value
                end
                
                if totalChosenValue then
                        totalChosenValue.Text = "R$" .. formatNumber(totalValue)
                end
        end
        
        if oppSelectedScroll and opponentFolder then
                for _, child in pairs(oppSelectedScroll:GetChildren()) do
                        if child:IsA("ImageButton") then
                                child:Destroy()
                        end
                end
                
                local sample = script:FindFirstChild("Sample")
                if not sample then return end
                
                local oppTotalVal = 0
                local oppItems = opponentFolder.Items:GetChildren()
                
                for i, itemFolder in ipairs(oppItems) do
                        local button = sample:Clone()
                        button.Name = itemFolder.Name
                        button.LayoutOrder = i
                        button.Visible = true
                        button.Parent = oppSelectedScroll
                        
                        local robloxId = itemFolder.RobloxId.Value
                        button.Image = "rbxthumb://type=Asset&id=" .. robloxId .. "&w=150&h=150"
                        
                        local rarity = itemFolder.Rarity.Value
                        local uiStroke = button:FindFirstChildOfClass("UIStroke")
                        if uiStroke then
                                uiStroke.Color = rarityColors[rarity] or Color3.new(1, 1, 1)
                        end
                        
                        local serialLabel = button:FindFirstChild("Serial")
                        if serialLabel then
                                local serial = itemFolder:FindFirstChild("SerialNumber")
                                if serial then
                                        serialLabel.Text = "#" .. serial.Value
                                        serialLabel.Visible = true
                                else
                                        serialLabel.Visible = false
                                end
                        end
                        
                        local qtyLabel = button:FindFirstChild("Qty")
                        if qtyLabel then
                                qtyLabel.Visible = false
                        end
                        
                        oppTotalVal = oppTotalVal + itemFolder.ItemValue.Value
                end
                
                if oppTotalValue then
                        oppTotalValue.Text = "R$" .. formatNumber(oppTotalVal)
                end
        end
        
        local player1Confirmed = currentGamble.Player1:FindFirstChild("CONFIRMED")
        local player2Confirmed = currentGamble.Player2:FindFirstChild("CONFIRMED")
        
        local mainTxt = selectItems:FindFirstChild("MainTxt")
        if mainTxt then
                if player1Confirmed and player2Confirmed then
                        mainTxt.Text = "Both players confirmed!"
                elseif (currentGamble.Player1.Value == client.Name and player1Confirmed) or
                       (currentGamble.Player2.Value == client.Name and player2Confirmed) then
                        mainTxt.Text = "Waiting for opponent to confirm..."
                else
                        mainTxt.Text = "Select Items To Bet"
                end
        end
end

local function populateInventoryHandler()
        local selectItems = gameMain:FindFirstChild("SelectItems")
        if not selectItems then return end
        
        local handler = selectItems:FindFirstChild("Handler")
        if not handler then return end
        
        for _, btn in pairs(handlerItemsButtons) do
                if btn then
                        btn:Destroy()
                end
        end
        handlerItemsButtons = {}
        
        local sample = script:FindFirstChild("Sample")
        if not sample then return end
        
        local success, inventory = pcall(function()
                return getInventoryFunction:InvokeServer()
        end)
        
        if not success or not inventory then
                warn("Failed to get inventory")
                return
        end
        
        table.sort(inventory, function(a, b)
                return a.Value > b.Value
        end)
        
        for i, item in ipairs(inventory) do
                if item.Rarity ~= "Vanity" then
                        local button = sample:Clone()
                        button.Name = item.Name or "Item_" .. i
                        button.LayoutOrder = i
                        button.Visible = true
                        button.Parent = handler
                        
                        button.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
                        
                        local uiStroke = button:FindFirstChildOfClass("UIStroke")
                        if uiStroke then
                                uiStroke.Color = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
                        end
                        
                        local serialLabel = button:FindFirstChild("Serial")
                        if serialLabel then
                                if item.SerialNumber then
                                        serialLabel.Text = "#" .. item.SerialNumber
                                        serialLabel.Visible = true
                                else
                                        serialLabel.Visible = false
                                end
                        end
                        
                        local qtyLabel = button:FindFirstChild("Qty")
                        if qtyLabel then
                                if item.SerialNumber then
                                        qtyLabel.Visible = false
                                elseif item.Amount then
                                        qtyLabel.Text = item.Amount
                                        qtyLabel.Visible = true
                                else
                                        qtyLabel.Text = "1"
                                        qtyLabel.Visible = true
                                end
                        end
                        
                        button.MouseButton1Click:Connect(function()
                                gambleEvent:FireServer("add item to gamble", {
                                        RobloxId = item.RobloxId,
                                        SerialNumber = item.SerialNumber
                                })
                        end)
                        
                        table.insert(handlerItemsButtons, button)
                end
        end
end

local function startGambleSelection()
        if not currentGamble then return end
        
        gameMain.Visible = true
        local selectItems = gameMain:FindFirstChild("SelectItems")
        local gameFrame = gameMain:FindFirstChild("Game")
        
        if selectItems then
                selectItems.Visible = true
        end
        if gameFrame then
                gameFrame.Visible = false
        end
        
        populateInventoryHandler()
        updateSelectedItemsDisplay()
end

ongoingGamblesFolder.ChildAdded:Connect(function(child)
        if child.Player1.Value == client.Name or child.Player2.Value == client.Name then
                currentGamble = child
                isInGame = false
                currentRound = 1
                yourWins = 0
                theirWins = 0
                
                requestFrame.Visible = false
                sendRequestFrame.Visible = false
                
                startGambleSelection()
                
                child.Player1.Items.ChildAdded:Connect(function()
                        updateSelectedItemsDisplay()
                end)
                
                child.Player1.Items.ChildRemoved:Connect(function()
                        updateSelectedItemsDisplay()
                end)
                
                child.Player2.Items.ChildAdded:Connect(function()
                        updateSelectedItemsDisplay()
                end)
                
                child.Player2.Items.ChildRemoved:Connect(function()
                        updateSelectedItemsDisplay()
                end)
                
                child.Player1.ChildAdded:Connect(function(obj)
                        if obj.Name == "CONFIRMED" then
                                updateSelectedItemsDisplay()
                        end
                end)
                
                child.Player1.ChildRemoved:Connect(function(obj)
                        if obj.Name == "CONFIRMED" then
                                updateSelectedItemsDisplay()
                        end
                end)
                
                child.Player2.ChildAdded:Connect(function(obj)
                        if obj.Name == "CONFIRMED" then
                                updateSelectedItemsDisplay()
                        end
                end)
                
                child.Player2.ChildRemoved:Connect(function(obj)
                        if obj.Name == "CONFIRMED" then
                                updateSelectedItemsDisplay()
                        end
                end)
                
                child.ChildAdded:Connect(function(obj)
                        if obj.Name == "GAME_STARTED" then
                                task.wait(1)
                                
                                local selectItems = gameMain:FindFirstChild("SelectItems")
                                if selectItems then
                                        selectItems.Visible = false
                                end
                                
                                local gameFrame = gameMain:FindFirstChild("Game")
                                if gameFrame then
                                        gameFrame.Visible = true
                                        
                                        local yourWinsLabel = gameFrame:FindFirstChild("YourWins")
                                        local oppWinsLabel = gameFrame:FindFirstChild("OppWins")
                                        
                                        if yourWinsLabel then
                                                yourWinsLabel.Text = "@" .. client.Name .. " Wins: 0"
                                        end
                                        
                                        if oppWinsLabel then
                                                local oppName = currentGamble.Player1.Value == client.Name and currentGamble.Player2.Value or currentGamble.Player1.Value
                                                oppWinsLabel.Text = "@" .. oppName .. " Wins: 0"
                                        end
                                        
                                        isInGame = true
                                        currentRound = 1
                                        yourWins = 0
                                        theirWins = 0
                                        
                                        task.wait(1)
                                        gambleEvent:FireServer("request round", {RoundNumber = currentRound})
                                end
                        end
                end)
        end
end)

ongoingGamblesFolder.ChildRemoved:Connect(function(child)
        if currentGamble == child then
                currentGamble = nil
                isInGame = false
                gameMain.Visible = false
                
                local selectItems = gameMain:FindFirstChild("SelectItems")
                if selectItems then
                        selectItems.Visible = false
                end
                
                local gameFrame = gameMain:FindFirstChild("Game")
                if gameFrame then
                        gameFrame.Visible = false
                end
        end
end)

local selectItems = gameMain:FindFirstChild("SelectItems")
if selectItems then
        local confirmButton = selectItems:FindFirstChild("Confirm")
        if confirmButton then
                confirmButton.MouseButton1Click:Connect(function()
                        gambleEvent:FireServer("confirm items")
                end)
        end
        
        local cancelButton = selectItems:FindFirstChild("Cancel")
        if cancelButton then
                cancelButton.MouseButton1Click:Connect(function()
                        gambleEvent:FireServer("cancel gamble")
                end)
        end
end

gambleEvent.OnClientEvent:Connect(function(instruction, data)
        if instruction == "round result" then
                local gameFrame = gameMain:FindFirstChild("Game")
                if not gameFrame or not isInGame then return end
                
                local yourItem = gameFrame:FindFirstChild("YourItem")
                local yourItemValue = gameFrame:FindFirstChild("ItemValue")
                local yourItemName = gameFrame:FindFirstChild("ItemName")
                
                local theirItem = gameFrame:FindFirstChild("TheirItem")
                local theirItemValue = gameFrame:FindFirstChild("TheirItemValue")
                local theirItemName = gameFrame:FindFirstChild("TheirItemName")
                
                local yourWinsLabel = gameFrame:FindFirstChild("YourWins")
                local oppWinsLabel = gameFrame:FindFirstChild("OppWins")
                
                local animationDuration = 3
                local spinInterval = 0.05
                local spinsBeforeSlow = math.floor(animationDuration / spinInterval * 0.7)
                local currentSpin = 0
                
                local function getRandomItem()
                        local items = {
                                {Id = 12345, Name = "Random Item 1", Value = math.random(1000, 1000000)},
                                {Id = 67890, Name = "Random Item 2", Value = math.random(1000, 1000000)},
                                {Id = 54321, Name = "Random Item 3", Value = math.random(1000, 1000000)}
                        }
                        return items[math.random(1, #items)]
                end
                
                local spinConnection
                spinConnection = game:GetService("RunService").Heartbeat:Connect(function()
                        currentSpin = currentSpin + 1
                        
                        local tempYourItem = getRandomItem()
                        local tempTheirItem = getRandomItem()
                        
                        if yourItem then
                                yourItem.Image = "rbxthumb://type=Asset&id=" .. tempYourItem.Id .. "&w=150&h=150"
                        end
                        if yourItemValue then
                                yourItemValue.Text = "R$" .. formatNumber(tempYourItem.Value)
                        end
                        if yourItemName then
                                yourItemName.Text = tempYourItem.Name
                        end
                        
                        if theirItem then
                                theirItem.Image = "rbxthumb://type=Asset&id=" .. tempTheirItem.Id .. "&w=150&h=150"
                        end
                        if theirItemValue then
                                theirItemValue.Text = "R$" .. formatNumber(tempTheirItem.Value)
                        end
                        if theirItemName then
                                theirItemName.Text = tempTheirItem.Name
                        end
                        
                        if currentSpin >= spinsBeforeSlow then
                                task.wait(0.1)
                        else
                                task.wait(spinInterval)
                        end
                        
                        if currentSpin >= animationDuration / spinInterval then
                                spinConnection:Disconnect()
                                
                                if yourItem then
                                        yourItem.Image = "rbxthumb://type=Asset&id=" .. data.YourItem.RobloxId .. "&w=150&h=150"
                                end
                                if yourItemValue then
                                        yourItemValue.Text = "R$" .. formatNumber(data.YourItem.Value)
                                end
                                if yourItemName then
                                        yourItemName.Text = data.YourItem.Name
                                end
                                
                                if theirItem then
                                        theirItem.Image = "rbxthumb://type=Asset&id=" .. data.TheirItem.RobloxId .. "&w=150&h=150"
                                end
                                if theirItemValue then
                                        theirItemValue.Text = "R$" .. formatNumber(data.TheirItem.Value)
                                end
                                if theirItemName then
                                        theirItemName.Text = data.TheirItem.Name
                                end
                                
                                if data.YouWon then
                                        yourWins = yourWins + 1
                                else
                                        theirWins = theirWins + 1
                                end
                                
                                if yourWinsLabel then
                                        yourWinsLabel.Text = "@" .. client.Name .. " Wins: " .. yourWins
                                end
                                
                                if oppWinsLabel then
                                        local oppName = currentGamble.Player1.Value == client.Name and currentGamble.Player2.Value or currentGamble.Player1.Value
                                        oppWinsLabel.Text = "@" .. oppName .. " Wins: " .. theirWins
                                end
                                
                                task.wait(1.5)
                                
                                if currentRound < 7 then
                                        currentRound = currentRound + 1
                                        gambleEvent:FireServer("request round", {RoundNumber = currentRound})
                                else
                                        task.wait(1)
                                        gambleEvent:FireServer("finish game", {
                                                YourWins = yourWins,
                                                TheirWins = theirWins
                                        })
                                end
                        end
                end)
        end
end)

local closeButton = sendRequestFrame:FindFirstChild("Close")
if closeButton then
        closeButton.MouseButton1Click:Connect(function()
                sendRequestFrame.Visible = false
        end)
end

sendRequestFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if sendRequestFrame.Visible then
                populatePlayerList()
        end
end)

gambleFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if gambleFrame.Visible and sendRequestFrame.Visible then
                populatePlayerList()
        end
end)

print("GambleClient loaded successfully")
