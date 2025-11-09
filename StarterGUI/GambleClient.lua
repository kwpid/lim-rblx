local client = game.Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GambleConfig = require(ReplicatedStorage:WaitForChild("GambleConfig"))

local rollableItemsCache = {}
local getRollableItemsFunction = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GetRollableItems")

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

local gambleFrame = script.Parent
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
local confirmConnection = nil
local cancelConnection = nil

local function populatePlayerList()
        local playerList = sendRequestFrame:FindFirstChild("PlayerList")
        local playerFrameSample = script.PlayerFrame

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

                        local sendButton = playerFrame:FindFirstChild("SendButton")
                        if sendButton then
                                sendButton.MouseButton1Click:Connect(function()
                                        gambleEvent:FireServer("send gamble request", { player })
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

                gambleFrame.Visible = true
                sendRequestFrame.Visible = false
                gameMain.Visible = false
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

                gambleFrame.Visible = true
                sendRequestFrame.Visible = false
                gameMain.Visible = false
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
        if not currentGamble then 
                warn("updateSelectedItemsDisplay: No current gamble")
                return 
        end
        
        local player1 = currentGamble:FindFirstChild("Player1")
        local player2 = currentGamble:FindFirstChild("Player2")
        
        if not player1 or not player2 then
                warn("updateSelectedItemsDisplay: Player1 or Player2 not found yet")
                return
        end
        
        local player1Value = player1:FindFirstChild("Value")
        local player2Value = player2:FindFirstChild("Value")
        
        if not player1Value or not player2Value then
                warn("updateSelectedItemsDisplay: Player values not found yet")
                return
        end

        local playerFolder = player1Value.Value == client.Name and player1 or player2
        local opponentFolder = player1Value.Value == client.Name and player2 or player1

        local selectedItemsFrame = gameMain:FindFirstChild("Selected_Items")
        if not selectedItemsFrame then
                warn("updateSelectedItemsDisplay: Selected_Items frame not found under Main")
                return
        end
        
        local selectedItemsScroll = selectedItemsFrame:FindFirstChild("SelectedItems")
        local totalChosenValue = selectedItemsFrame:FindFirstChild("TotalChosenValue")

        local opponentItemsFrame = gameMain:FindFirstChild("Opponent_Items")
        if not opponentItemsFrame then
                warn("updateSelectedItemsDisplay: Opponent_Items frame not found under Main")
                return
        end
        
        local oppSelectedScroll = opponentItemsFrame:FindFirstChild("Opp_SelectedItems")
        local oppTotalValue = opponentItemsFrame:FindFirstChild("TotalChosenValue")
        
        print("updateSelectedItemsDisplay called")
        print("selectedItemsScroll found:", selectedItemsScroll ~= nil)
        print("oppSelectedScroll found:", oppSelectedScroll ~= nil)

        if selectedItemsScroll then
                for _, btn in pairs(selectedItemsButtons) do
                        if btn then
                                btn:Destroy()
                        end
                end
                selectedItemsButtons = {}

                local sample = script:FindFirstChild("Sample")
                if not sample then 
                        warn("Sample not found in GambleClient script!")
                        return 
                end

                local totalValue = 0
                local items = playerFolder.Items:GetChildren()
                
                print("Updating selected items display, found " .. #items .. " items")

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
                                        SerialNumber = itemFolder:FindFirstChild("SerialNumber") and
                                            itemFolder.SerialNumber.Value or nil
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
                if not sample then 
                        warn("Sample not found in GambleClient script (opponent section)!")
                        return 
                end

                local oppTotalVal = 0
                local oppItems = opponentFolder.Items:GetChildren()
                
                print("Updating opponent items display, found " .. #oppItems .. " items")

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

        local player1Confirmed = player1:FindFirstChild("CONFIRMED")
        local player2Confirmed = player2:FindFirstChild("CONFIRMED")

        local selectItems = gameMain:FindFirstChild("SelectItems")
        local mainTxt = selectItems and selectItems:FindFirstChild("MainTxt")
        local confirmButton = selectItems and selectItems:FindFirstChild("Confirm")
        
        local isPlayer1 = player1Value.Value == client.Name
        local myConfirmed = isPlayer1 and player1Confirmed or player2Confirmed
        local oppConfirmed = isPlayer1 and player2Confirmed or player1Confirmed
        local oppName = isPlayer1 and player2Value.Value or player1Value.Value
        
        if confirmButton then
                if myConfirmed then
                        confirmButton.Text = "Confirmed ✓"
                else
                        confirmButton.Text = "Confirm"
                end
        end
        
        if mainTxt then
                if player1Confirmed and player2Confirmed then
                        mainTxt.Text = "Both players confirmed! Starting game..."
                elseif myConfirmed and not oppConfirmed then
                        mainTxt.Text = "Waiting for " .. oppName .. " to confirm..."
                elseif oppConfirmed and not myConfirmed then
                        mainTxt.Text = oppName .. " is ready! Confirm your items"
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

        local playerFolder = currentGamble and (currentGamble.Player1.Value.Value == client.Name and currentGamble.Player1 or currentGamble.Player2)
        local selectedItemsFolder = playerFolder and playerFolder.Items

        local layoutOrder = 0
        for i, item in ipairs(inventory) do
                local isAllowedRarity = item.Rarity ~= "Vanity" and item.Rarity ~= "Common" 
                        and (item.Rarity ~= "Uncommon" or GambleConfig.AllowUncommons)
                
                if isAllowedRarity and not item.IsLocked then
                        if item.SerialNumber then
                                local itemKey = tostring(item.RobloxId) .. "_" .. tostring(item.SerialNumber)
                                local alreadySelected = selectedItemsFolder and selectedItemsFolder:FindFirstChild(itemKey)

                                if not alreadySelected then
                                        layoutOrder = layoutOrder + 1
                                        local button = sample:Clone()
                                        button.Name = item.Name or "Item_" .. i
                                        button.LayoutOrder = layoutOrder
                                        button.Visible = true
                                        button.Parent = handler

                                        button.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"

                                        local uiStroke = button:FindFirstChildOfClass("UIStroke")
                                        if uiStroke then
                                                uiStroke.Color = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
                                        end

                                        local serialLabel = button:FindFirstChild("Serial")
                                        if serialLabel then
                                                serialLabel.Text = "#" .. item.SerialNumber
                                                serialLabel.Visible = true
                                        end

                                        local qtyLabel = button:FindFirstChild("Qty")
                                        if qtyLabel then
                                                qtyLabel.Visible = false
                                        end

                                        button.MouseButton1Click:Connect(function()
                                                gambleEvent:FireServer("add item to gamble", {
                                                        RobloxId = item.RobloxId,
                                                        SerialNumber = item.SerialNumber
                                                })
                                        end)

                                        table.insert(handlerItemsButtons, button)
                                end
                        else
                                local selectedCount = 0
                                if selectedItemsFolder then
                                        for _, selectedItem in ipairs(selectedItemsFolder:GetChildren()) do
                                                if selectedItem.RobloxId.Value == item.RobloxId and not selectedItem:FindFirstChild("SerialNumber") then
                                                        selectedCount = selectedCount + 1
                                                end
                                        end
                                end
                                
                                local amount = item.Amount or 1
                                local remainingToShow = amount - selectedCount
                                
                                for copyNum = 1, remainingToShow do
                                        layoutOrder = layoutOrder + 1
                                        local button = sample:Clone()
                                        button.Name = (item.Name or "Item") .. "_" .. copyNum
                                        button.LayoutOrder = layoutOrder
                                        button.Visible = true
                                        button.Parent = handler

                                        button.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"

                                        local uiStroke = button:FindFirstChildOfClass("UIStroke")
                                        if uiStroke then
                                                uiStroke.Color = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
                                        end

                                        local serialLabel = button:FindFirstChild("Serial")
                                        if serialLabel then
                                                serialLabel.Visible = false
                                        end

                                        local qtyLabel = button:FindFirstChild("Qty")
                                        if qtyLabel then
                                                qtyLabel.Visible = false
                                        end

                                        button.MouseButton1Click:Connect(function()
                                                gambleEvent:FireServer("add item to gamble", {
                                                        RobloxId = item.RobloxId,
                                                        SerialNumber = nil
                                                })
                                        end)

                                        table.insert(handlerItemsButtons, button)
                                end
                        end
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
                
                if confirmConnection then
                        confirmConnection:Disconnect()
                        confirmConnection = nil
                end
                if cancelConnection then
                        cancelConnection:Disconnect()
                        cancelConnection = nil
                end
                
                local confirmButton = selectItems:FindFirstChild("Confirm")
                if confirmButton then
                        confirmConnection = confirmButton.MouseButton1Click:Connect(function()
                                gambleEvent:FireServer("confirm items")
                        end)
                end

                local cancelButton = selectItems:FindFirstChild("Cancel")
                if cancelButton then
                        cancelConnection = cancelButton.MouseButton1Click:Connect(function()
                                gambleEvent:FireServer("cancel gamble")
                        end)
                end
        end
        if gameFrame then
                gameFrame.Visible = false
        end

        populateInventoryHandler()
        updateSelectedItemsDisplay()
end

ongoingGamblesFolder.ChildAdded:Connect(function(child)
        local player1Folder = child:WaitForChild("Player1", 5)
        local player2Folder = child:WaitForChild("Player2", 5)
        
        if not player1Folder or not player2Folder then
                warn("Failed to find Player1 or Player2 in gamble folder")
                return
        end
        
        local player1Name = player1Folder:WaitForChild("Value", 5)
        local player2Name = player2Folder:WaitForChild("Value", 5)
        
        if not player1Name or not player2Name then
                warn("Failed to find player names in gamble folder")
                return
        end
        
        if player1Name.Value == client.Name or player2Name.Value == client.Name then
                currentGamble = child
                isInGame = false
                currentRound = 1
                yourWins = 0
                theirWins = 0

                gambleFrame.Visible = true
                requestFrame.Visible = false
                sendRequestFrame.Visible = false
                gameMain.Visible = true

                startGambleSelection()

                child.Player1.Items.ChildAdded:Connect(function()
                        updateSelectedItemsDisplay()
                        populateInventoryHandler()
                end)

                child.Player1.Items.ChildRemoved:Connect(function()
                        updateSelectedItemsDisplay()
                        populateInventoryHandler()
                end)

                child.Player2.Items.ChildAdded:Connect(function()
                        updateSelectedItemsDisplay()
                        populateInventoryHandler()
                end)

                child.Player2.Items.ChildRemoved:Connect(function()
                        updateSelectedItemsDisplay()
                        populateInventoryHandler()
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
                                print("GAME_STARTED detected! Transitioning to game...")
                                task.wait(1)

                                local selectItems = gameMain:FindFirstChild("SelectItems")
                                if selectItems then
                                        print("Hiding SelectItems")
                                        selectItems.Visible = false
                                else
                                        warn("SelectItems not found!")
                                end

                                local gameFrame = gameMain:FindFirstChild("Game")
                                if gameFrame then
                                        print("Showing Game frame")
                                        gameFrame.Visible = true

                                        local yourWinsLabel = gameFrame:FindFirstChild("YourWins")
                                        local oppWinsLabel = gameFrame:FindFirstChild("OppWins")

                                        if yourWinsLabel then
                                                yourWinsLabel.Text = "@" .. client.Name .. " Wins: 0"
                                        end

                                        if oppWinsLabel then
                                                local oppName = currentGamble.Player1.Value.Value == client.Name and
                                                    currentGamble.Player2.Value.Value or currentGamble.Player1.Value.Value
                                                oppWinsLabel.Text = "@" .. oppName .. " Wins: 0"
                                        end

                                        isInGame = true
                                        currentRound = 1

                                        print("Fetching rollable items for animation...")
                                        local success, items = pcall(function()
                                                return getRollableItemsFunction:InvokeServer()
                                        end)
                                        
                                        if success and items and #items > 0 then
                                                rollableItemsCache = items
                                                print("Loaded " .. #rollableItemsCache .. " items for animation")
                                        else
                                                warn("Failed to load rollable items, animation will use placeholders")
                                        end

                                        local isPlayer1 = currentGamble.Player1.Value.Value == client.Name
                                        if isPlayer1 then
                                                print("Player 1 requesting round 1...")
                                                task.wait(1)
                                                gambleEvent:FireServer("request round", { RoundNumber = currentRound })
                                        else
                                                print("Player 2 waiting for round 1...")
                                        end
                                else
                                        warn("Game frame not found!")
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

                local function getRandomItemFromCache()
                        if #rollableItemsCache == 0 then
                                return { RobloxId = 0, Name = "Loading...", Value = 0 }
                        end
                        return rollableItemsCache[math.random(1, #rollableItemsCache)]
                end

                task.spawn(function()
                        local totalDuration = 2.5
                        local minInterval = 0.05
                        local maxInterval = 0.3
                        
                        local elapsed = 0
                        local spinCount = 0
                        
                        while elapsed < totalDuration do
                                local progress = elapsed / totalDuration
                                
                                local easeProgress = progress * progress * progress
                                
                                local currentInterval = minInterval + (maxInterval - minInterval) * easeProgress
                                
                                local tempYourItem = getRandomItemFromCache()
                                local tempTheirItem = getRandomItemFromCache()

                                if yourItem then
                                        yourItem.Image = "rbxthumb://type=Asset&id=" .. tempYourItem.RobloxId .. "&w=150&h=150"
                                end
                                if yourItemValue then
                                        yourItemValue.Text = "R$" .. formatNumber(tempYourItem.Value)
                                end
                                if yourItemName then
                                        yourItemName.Text = tempYourItem.Name
                                end

                                if theirItem then
                                        theirItem.Image = "rbxthumb://type=Asset&id=" .. tempTheirItem.RobloxId .. "&w=150&h=150"
                                end
                                if theirItemValue then
                                        theirItemValue.Text = "R$" .. formatNumber(tempTheirItem.Value)
                                end
                                if theirItemName then
                                        theirItemName.Text = tempTheirItem.Name
                                end

                                task.wait(currentInterval)
                                elapsed = elapsed + currentInterval
                                spinCount = spinCount + 1
                        end

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

                        if yourWinsLabel then
                                yourWinsLabel.Text = "@" .. client.Name .. " Wins: " .. (data.YourWins or 0)
                        end

                        if oppWinsLabel then
                                local oppName = currentGamble.Player1.Value.Value == client.Name and
                                    currentGamble.Player2.Value.Value or currentGamble.Player1.Value.Value
                                oppWinsLabel.Text = "@" .. oppName .. " Wins: " .. (data.TheirWins or 0)
                        end
                        
                        local roundStatus = gameFrame:FindFirstChild("RoundStatus") or gameFrame:FindFirstChild("MainTxt")
                        if roundStatus then
                                if data.YourItem.Value > data.TheirItem.Value then
                                        roundStatus.Text = "You won Round " .. data.RoundNumber .. "!"
                                elseif data.TheirItem.Value > data.YourItem.Value then
                                        roundStatus.Text = "You lost Round " .. data.RoundNumber
                                else
                                        roundStatus.Text = "Round " .. data.RoundNumber .. " - Tie!"
                                end
                        end

                        task.wait(1.5)

                        local isPlayer1 = currentGamble and currentGamble.Player1.Value.Value == client.Name
                        if isPlayer1 then
                                if currentRound < 7 then
                                        currentRound = currentRound + 1
                                        gambleEvent:FireServer("request round", { RoundNumber = currentRound })
                                else
                                        task.wait(1)
                                        gambleEvent:FireServer("finish game")
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
