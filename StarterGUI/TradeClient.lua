local client = game.Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("TradeConfiguration"))

local tradeRequestsFolder = ReplicatedStorage:WaitForChild("TRADE REQUESTS", 30)
if not tradeRequestsFolder then
        warn("❌ TradeClient: TRADE REQUESTS folder not found!")
        return
end

local ongoingTradesFolder = ReplicatedStorage:WaitForChild("ONGOING TRADES", 30)
if not ongoingTradesFolder then
        warn("❌ TradeClient: ONGOING TRADES folder not found!")
        return
end

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
if not remoteEvents then
        warn("❌ TradeClient: RemoteEvents folder not found!")
        return
end

local tradeEvent = remoteEvents:WaitForChild("TradeEvent", 30)
if not tradeEvent then
        warn("❌ TradeClient: TradeEvent not found!")
        return
end

local getInventoryFunction = remoteEvents:WaitForChild("GetInventoryFunction", 30)
if not getInventoryFunction then
        warn("❌ TradeClient: GetInventoryFunction not found!")
        return
end

print("✅ TradeClient: All resources loaded successfully for", client.Name)

local gui = script.Parent

local openBtn = gui:WaitForChild("OpenSendTrades")
local sendTradesFrame = gui:WaitForChild("SendTradesFrame")
local tradeRequestFrame = gui:WaitForChild("TradeRequestFrame")
local tradeFrame = gui:WaitForChild("TradeFrame")
local tradeHistoryFrame = gui:WaitForChild("TradeHistoryFrame")
local viewInventoryFrame = gui:WaitForChild("ViewInventoryFrame")

sendTradesFrame.Visible = false
tradeRequestFrame.Visible = false
tradeFrame.Visible = false
tradeHistoryFrame.Visible = false
viewInventoryFrame.Visible = false

tradeRequestsFolder.ChildAdded:Connect(function(child)
        if child.Value == client.Name then
                tradeRequestFrame.TradeText.Text = child.Name .. " sent you a trade request!"

                tradeRequestFrame.AcceptButton.Visible = true
                tradeRequestFrame.RejectButton.Visible = true
                tradeRequestFrame.Visible = true
        elseif child.Name == client.Name then
                tradeRequestFrame.TradeText.Text = "You sent a trade request to " .. child.Value

                tradeRequestFrame.AcceptButton.Visible = false
                tradeRequestFrame.RejectButton.Visible = true
                tradeRequestFrame.Visible = true
        end
end)

tradeRequestsFolder.ChildRemoved:Connect(function(child)
        if child.Value == client.Name or child.Name == client.Name then
                tradeRequestFrame.Visible = false
        end
end)

local function getItemThumbnail(robloxId)
        local success, result = pcall(function()
                return "rbxthumb://type=Asset&id=" .. robloxId .. "&w=150&h=150"
        end)
        if success then
                return result
        else
                return ""
        end
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

local function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

local function formatValueShort(value)
        if value >= 1000000000 then
                return string.format("%.2fB", value / 1000000000)
        elseif value >= 1000000 then
                return string.format("%.2fM", value / 1000000)
        elseif value >= 1000 then
                return string.format("%.2fK", value / 1000)
        else
                return tostring(value)
        end
end

local currentInventoryButtons = {}
local viewInventoryButtons = {}

local function populateViewInventory(targetPlayer)
        local sample = script:FindFirstChild("Sample")
        local handler = viewInventoryFrame:FindFirstChild("Handler")
        local title = viewInventoryFrame:FindFirstChild("Title")
        
        if not sample or not handler then
                warn("❌ TradeClient: ViewInventoryFrame missing required elements")
                return
        end
        
        if title then
                title.Text = targetPlayer.Name .. "'s Inventory"
        end
        
        for _, btn in pairs(viewInventoryButtons) do
                if btn then
                        btn:Destroy()
                end
        end
        viewInventoryButtons = {}
        
        local getPlayerInventoryFunction = remoteEvents:FindFirstChild("GetPlayerInventoryFunction")
        if not getPlayerInventoryFunction then
                warn("❌ TradeClient: GetPlayerInventoryFunction not found")
                return
        end
        
        local success, response = pcall(function()
                return getPlayerInventoryFunction:InvokeServer(targetPlayer.UserId)
        end)
        
        if not success or not response or type(response) ~= "table" or not response.success then
                warn("❌ TradeClient: Failed to get inventory for", targetPlayer.Name)
                viewInventoryFrame.Visible = false
                return
        end
        
        local inventory = response.inventory
        
        table.sort(inventory, function(a, b)
                return a.Value > b.Value
        end)
        
        for i, item in ipairs(inventory) do
                local button = sample:Clone()
                button.Name = item.Name or "Item_" .. i
                button.LayoutOrder = i
                button.Visible = true
                button.Parent = handler
                
                local contentFrame = button:FindFirstChild("Content")
                local content2Frame = button:FindFirstChild("content2")
                
                if contentFrame then
                        local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
                        contentFrame.BorderColor3 = rarityColor
                end
                if content2Frame then
                        local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
                        content2Frame.BorderColor3 = rarityColor
                end
                
                local qtyLabel = button:FindFirstChild("Qty")
                if qtyLabel then
                        if item.SerialNumber then
                                qtyLabel.Text = "#" .. item.SerialNumber
                        elseif item.Amount then
                                qtyLabel.Text = item.Amount .. "x"
                        else
                                qtyLabel.Text = "1x"
                        end
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
                
                local rarityLabel = contentFrame and contentFrame:FindFirstChild("Rarity")
                if rarityLabel then
                        if item.Rarity == "Common" then
                                rarityLabel.Visible = false
                        else
                                rarityLabel.Visible = true
                                rarityLabel.Text = item.Rarity
                                rarityLabel.TextColor3 = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
                        end
                end
                
                local t1Label = button:FindFirstChild("t1")
                if t1Label then
                        t1Label.Visible = false
                end
                
                local copiesCount = 0
                if item.Stock and item.Stock > 0 then
                        copiesCount = item.CurrentStock or 0
                else
                        copiesCount = item.TotalCopies or 0
                end
                
                local rareText = button:FindFirstChild("RareText")
                if rareText then
                        if copiesCount > 0 and copiesCount <= 25 then
                                rareText.Visible = true
                        else
                                rareText.Visible = false
                        end
                end
                
                local limText = button:FindFirstChild("LimText")
                if limText then
                        if item.Limited then
                                limText.Visible = true
                        else
                                limText.Visible = false
                        end
                end
                
                local copiesLabel = button:FindFirstChild("copies")
                if copiesLabel then
                        local stockCount = item.Stock or 0
                        
                        if copiesCount > 0 then
                                if stockCount > 0 then
                                        copiesLabel.Text = copiesCount .. " / " .. stockCount .. " copies"
                                else
                                        copiesLabel.Text = copiesCount .. " copies"
                                end
                                copiesLabel.Visible = true
                        else
                                copiesLabel.Visible = false
                        end
                end
                
                local o2Label = contentFrame and contentFrame:FindFirstChild("o2")
                if o2Label then
                        if item.Stock and item.Stock > 0 then
                                o2Label.Text = formatNumber(copiesCount) .. "/" .. formatNumber(item.Stock)
                        else
                                o2Label.Text = formatNumber(copiesCount)
                        end
                end
                
                local valueLabel = contentFrame and contentFrame:FindFirstChild("Value")
                if valueLabel then
                        valueLabel.Text = "R$ " .. formatNumber(item.Value)
                end
                
                local v2Label = contentFrame and contentFrame:FindFirstChild("v2")
                if v2Label then
                        v2Label.Text = formatNumber(item.Value)
                end
                
                local nameLabel = content2Frame and content2Frame:FindFirstChild("name")
                if nameLabel then
                        local displayName = item.Name
                        if #displayName > 20 then
                                displayName = string.sub(displayName, 1, 17) .. "..."
                        end
                        nameLabel.Text = displayName
                end
                
                local img = button:FindFirstChild("Image")
                if img and img:IsA("ImageLabel") then
                        img.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
                end
                
                table.insert(viewInventoryButtons, button)
        end
        
        viewInventoryFrame.Visible = true
end

ongoingTradesFolder.ChildAdded:Connect(function(child)
        if child:WaitForChild("Sender").Value == client.Name or child:WaitForChild("Receiver").Value == client.Name then
                local clientValue = child:WaitForChild("Sender").Value == client.Name and child.Sender or child.Receiver
                local otherPlrValue = clientValue.Name == "Sender" and child.Receiver or child.Sender

                clientValue.AncestryChanged:Connect(function()
                        if clientValue.Parent == nil then
                                tradeFrame.Visible = false
                                openBtn.Visible = true
                                for _, btn in pairs(currentInventoryButtons) do
                                        if btn then
                                                btn:Destroy()
                                        end
                                end
                                currentInventoryButtons = {}
                        end
                end)

                tradeRequestFrame.Visible = false
                sendTradesFrame.Visible = false
                openBtn.Visible = false

                tradeFrame.TradingFrame.TradingWithName.Text = "Trading with " .. otherPlrValue.Value
                tradeFrame.TradingFrame.TheirOfferFrame.TheirOfferText.Text = otherPlrValue.Value .. "'s offer"
                tradeFrame.TradingFrame.PlayerAccepted.Text = ""

                tradeFrame.TradingFrame.AcceptButton.Text = "Accept"
                tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(58, 191, 232)

                for _, child in pairs(tradeFrame.TradingFrame.YourOfferFrame.Slots:GetChildren()) do
                        if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
                                child:Destroy()
                        end
                end
                for _, child in pairs(tradeFrame.TradingFrame.TheirOfferFrame.Slots:GetChildren()) do
                        if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
                                child:Destroy()
                        end
                end

                otherPlrValue.ChildAdded:Connect(function(child)
                        if child.Name == "ACCEPTED" then
                                tradeFrame.TradingFrame.PlayerAccepted.Text = otherPlrValue.Value .. " has accepted"
                        end
                end)
                otherPlrValue.ChildRemoved:Connect(function(child)
                        if child.Name == "ACCEPTED" then
                                tradeFrame.TradingFrame.PlayerAccepted.Text = ""
                        end
                end)
                
                clientValue.ChildAdded:Connect(function(child)
                        if child.Name == "ACCEPTED" then
                                tradeFrame.TradingFrame.AcceptButton.Text = "Accepted"
                        end
                end)
                clientValue.ChildRemoved:Connect(function(child)
                        if child.Name == "ACCEPTED" then
                                tradeFrame.TradingFrame.AcceptButton.Text = "Accept"
                        end
                end)

                local inventoryList = tradeFrame.InventoryFrame.InventoryList
                local searchBox = tradeFrame.InventoryFrame:FindFirstChild("SearchInv")
                
                for _, child in pairs(inventoryList:GetChildren()) do
                        if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
                                child:Destroy()
                        end
                end
                currentInventoryButtons = {}

                local success, inventory = pcall(function()
                        return getInventoryFunction:InvokeServer()
                end)

                if not success then
                        warn("❌ TradeClient: Failed to get inventory: " .. tostring(inventory))
                        return
                end

                if not inventory then
                        warn("❌ TradeClient: Inventory is nil")
                        return
                end

                local itemsToDisplay = {}
                local allItemsData = {}

                for _, item in ipairs(inventory) do
                        if item.SerialNumber then
                                table.insert(itemsToDisplay, {
                                        RobloxId = item.RobloxId,
                                        Name = item.Name,
                                        Value = item.Value,
                                        Rarity = item.Rarity,
                                        SerialNumber = item.SerialNumber,
                                        Amount = 1,
                                        MaxAmount = 1,
                                        isSerial = true
                                })
                        else
                                table.insert(itemsToDisplay, {
                                        RobloxId = item.RobloxId,
                                        Name = item.Name,
                                        Value = item.Value,
                                        Rarity = item.Rarity,
                                        Amount = 0,
                                        MaxAmount = item.Amount or 1,
                                        isSerial = false
                                })
                        end
                end

                local function createItemButton(displayItem)
                        local newItemButton = script:WaitForChild("ItemButton"):Clone()
                        local uniqueId = displayItem.RobloxId .. "_" .. (displayItem.SerialNumber or "regular")
                        newItemButton.Name = uniqueId

                        newItemButton.ItemName.Text = displayItem.Name
                        newItemButton.ItemImage1.Image = getItemThumbnail(displayItem.RobloxId)
                        
                        if displayItem.isSerial then
                                newItemButton.QtySerial.Text = "#" .. displayItem.SerialNumber
                        else
                                newItemButton.QtySerial.Text = "x" .. (displayItem.Amount or 0) .. "/" .. displayItem.MaxAmount
                        end

                        newItemButton.MouseButton1Click:Connect(function()
                                if displayItem.isSerial then
                                        local alreadyInTrade = tradeFrame.TradingFrame.YourOfferFrame.Slots:FindFirstChild("Offer_" .. uniqueId)
                                        if alreadyInTrade then
                                                tradeEvent:FireServer("remove item from trade", {displayItem.RobloxId, displayItem.SerialNumber})
                                        else
                                                tradeEvent:FireServer("add item to trade", {displayItem.RobloxId, displayItem.SerialNumber})
                                        end
                                else
                                        if displayItem.Amount < displayItem.MaxAmount then
                                                displayItem.Amount = displayItem.Amount + 1
                                                newItemButton.QtySerial.Text = "x" .. displayItem.Amount .. "/" .. displayItem.MaxAmount
                                                tradeEvent:FireServer("add item to trade", {displayItem.RobloxId, nil, 1})
                                        end
                                end
                        end)

                        newItemButton.MouseButton2Click:Connect(function()
                                if not displayItem.isSerial then
                                        if displayItem.Amount > 0 then
                                                displayItem.Amount = displayItem.Amount - 1
                                                newItemButton.QtySerial.Text = "x" .. displayItem.Amount .. "/" .. displayItem.MaxAmount
                                                tradeEvent:FireServer("remove item from trade", {displayItem.RobloxId, nil, 1})
                                        end
                                end
                        end)

                        return newItemButton
                end
                
                local function updateInventoryDisplay(searchQuery)
                        for _, child in pairs(inventoryList:GetChildren()) do
                                if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
                                        child:Destroy()
                                end
                        end
                        currentInventoryButtons = {}
                        
                        local query = searchQuery and searchQuery:lower() or ""
                        
                        for _, displayItem in ipairs(allItemsData) do
                                local itemName = displayItem.Name:lower()
                                if query == "" or itemName:find(query, 1, true) then
                                        local newItemButton = createItemButton(displayItem)
                                        newItemButton.Parent = inventoryList
                                        table.insert(currentInventoryButtons, newItemButton)
                                end
                        end
                end
                
                for _, displayItem in ipairs(itemsToDisplay) do
                        table.insert(allItemsData, displayItem)
                end
                
                table.sort(allItemsData, function(a, b)
                        return a.Value > b.Value
                end)
                
                updateInventoryDisplay("")
                
                if searchBox then
                        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                                updateInventoryDisplay(searchBox.Text)
                        end)
                end

                local clientOffer = child[clientValue.Value .. "'s offer"]
                local otherPlrOffer = child[otherPlrValue.Value .. "'s offer"]
                
                local function updateYourValue()
                        local totalValue = 0
                        for _, offerItem in pairs(clientOffer:GetChildren()) do
                                local value = offerItem:FindFirstChild("Value")
                                local amount = offerItem:FindFirstChild("Amount")
                                if value then
                                        local multiplier = amount and amount.Value or 1
                                        totalValue = totalValue + (value.Value * multiplier)
                                end
                        end
                        tradeFrame.TradingFrame.YourOfferFrame.YourValue.Text = "Value: " .. tostring(totalValue)
                end
                
                local function updateTheirValue()
                        local totalValue = 0
                        for _, offerItem in pairs(otherPlrOffer:GetChildren()) do
                                local value = offerItem:FindFirstChild("Value")
                                local amount = offerItem:FindFirstChild("Amount")
                                if value then
                                        local multiplier = amount and amount.Value or 1
                                        totalValue = totalValue + (value.Value * multiplier)
                                end
                        end
                        tradeFrame.TradingFrame.TheirOfferFrame.TheirValue.Text = "Value: " .. tostring(totalValue)
                end

                clientOffer.ChildAdded:Connect(function(slotChild)
                        task.wait()
                        updateYourValue()
                        
                        local robloxId = slotChild:FindFirstChild("RobloxId")
                        local serialNumber = slotChild:FindFirstChild("SerialNumber")
                        local amount = slotChild:FindFirstChild("Amount")
                        local itemName = slotChild:FindFirstChild("ItemName")

                        if not robloxId or not itemName then return end

                        local newToolButton = script.ItemButton:Clone()
                        newToolButton.Name = "Offer_" .. (serialNumber and (robloxId.Value .. "_" .. serialNumber.Value) or robloxId.Value)
                        
                        newToolButton.ItemName.Text = itemName.Value

                        newToolButton.ItemImage1.Image = getItemThumbnail(robloxId.Value)
                        
                        if serialNumber then
                                newToolButton.QtySerial.Text = "#" .. serialNumber.Value
                        elseif amount then
                                newToolButton.QtySerial.Text = "x" .. amount.Value
                                
                                amount:GetPropertyChangedSignal("Value"):Connect(function()
                                        newToolButton.QtySerial.Text = "x" .. amount.Value
                                        updateYourValue()
                                end)
                        else
                                newToolButton.QtySerial.Text = ""
                        end

                        newToolButton.MouseButton1Click:Connect(function()
                                if serialNumber then
                                        tradeEvent:FireServer("remove item from trade", {robloxId.Value, serialNumber.Value})
                                else
                                        tradeEvent:FireServer("remove item from trade", {robloxId.Value, nil, 1})
                                end
                        end)

                        slotChild.ChildAdded:Connect(function(child)
                                if child.Name == "Amount" then
                                        task.wait(0.1)
                                        newToolButton.QtySerial.Text = "x" .. child.Value
                                        updateYourValue()
                                        
                                        child:GetPropertyChangedSignal("Value"):Connect(function()
                                                newToolButton.QtySerial.Text = "x" .. child.Value
                                                updateYourValue()
                                        end)
                                end
                        end)

                        slotChild.ChildRemoved:Connect(function(child)
                                if child.Name == "Amount" then
                                        task.wait(0.1)
                                        local currentAmount = slotChild:FindFirstChild("Amount")
                                        if currentAmount then
                                                newToolButton.QtySerial.Text = "x" .. currentAmount.Value
                                        else
                                                newToolButton:Destroy()
                                                
                                                for _, displayItem in ipairs(allItemsData) do
                                                        if displayItem.RobloxId == robloxId.Value and not displayItem.isSerial then
                                                                if displayItem.Amount > 0 then
                                                                        displayItem.Amount = displayItem.Amount - 1
                                                                        updateInventoryDisplay(searchBox and searchBox.Text or "")
                                                                end
                                                                break
                                                        end
                                                end
                                        end
                                        updateYourValue()
                                end
                        end)

                        slotChild:GetPropertyChangedSignal("Parent"):Connect(function()
                                if slotChild.Parent == nil then
                                        newToolButton:Destroy()
                                        
                                        if not serialNumber then
                                                for _, displayItem in ipairs(allItemsData) do
                                                        if displayItem.RobloxId == robloxId.Value and not displayItem.isSerial then
                                                                local amtToRemove = amount and amount.Value or 1
                                                                displayItem.Amount = math.max(0, displayItem.Amount - amtToRemove)
                                                                updateInventoryDisplay(searchBox and searchBox.Text or "")
                                                                break
                                                        end
                                                end
                                        end
                                        
                                        updateYourValue()
                                end
                        end)

                        newToolButton.Parent = tradeFrame.TradingFrame.YourOfferFrame.Slots
                end)
                
                clientOffer.ChildRemoved:Connect(function()
                        updateYourValue()
                end)

                otherPlrOffer.ChildAdded:Connect(function(slotChild)
                        task.wait()
                        updateTheirValue()
                        
                        local robloxId = slotChild:FindFirstChild("RobloxId")
                        local serialNumber = slotChild:FindFirstChild("SerialNumber")
                        local amount = slotChild:FindFirstChild("Amount")
                        local itemName = slotChild:FindFirstChild("ItemName")

                        if not robloxId or not itemName then return end

                        local newToolButton = script.ItemButton:Clone()
                        newToolButton.Name = "TheirOffer_" .. (serialNumber and (robloxId.Value .. "_" .. serialNumber.Value) or robloxId.Value)
                        
                        newToolButton.ItemName.Text = itemName.Value

                        newToolButton.ItemImage1.Image = getItemThumbnail(robloxId.Value)
                        newToolButton.AutoButtonColor = false
                        
                        if serialNumber then
                                newToolButton.QtySerial.Text = "#" .. serialNumber.Value
                        elseif amount then
                                newToolButton.QtySerial.Text = "x" .. amount.Value
                                
                                amount:GetPropertyChangedSignal("Value"):Connect(function()
                                        newToolButton.QtySerial.Text = "x" .. amount.Value
                                        updateTheirValue()
                                end)
                        else
                                newToolButton.QtySerial.Text = ""
                        end

                        slotChild.ChildAdded:Connect(function(child)
                                if child.Name == "Amount" then
                                        task.wait(0.1)
                                        newToolButton.QtySerial.Text = "x" .. child.Value
                                        updateTheirValue()
                                        
                                        child:GetPropertyChangedSignal("Value"):Connect(function()
                                                newToolButton.QtySerial.Text = "x" .. child.Value
                                                updateTheirValue()
                                        end)
                                end
                        end)

                        slotChild.ChildRemoved:Connect(function(child)
                                if child.Name == "Amount" then
                                        task.wait(0.1)
                                        local currentAmount = slotChild:FindFirstChild("Amount")
                                        if currentAmount then
                                                newToolButton.QtySerial.Text = "x" .. currentAmount.Value
                                        else
                                                newToolButton:Destroy()
                                        end
                                        updateTheirValue()
                                end
                        end)

                        slotChild:GetPropertyChangedSignal("Parent"):Connect(function()
                                if slotChild.Parent == nil then
                                        newToolButton:Destroy()
                                        updateTheirValue()
                                end
                        end)

                        newToolButton.Parent = tradeFrame.TradingFrame.TheirOfferFrame.Slots
                end)
                
                otherPlrOffer.ChildRemoved:Connect(function()
                        updateTheirValue()
                end)

                tradeFrame.Visible = true
        end
end)

openBtn.MouseButton1Click:Connect(function()
        if sendTradesFrame.Visible == true then
                sendTradesFrame.Visible = false
        elseif tradeFrame.Visible == false then
                for _, child in pairs(sendTradesFrame.PlayerList:GetChildren()) do
                        if child:IsA("Frame") then
                                child:Destroy()
                        end
                end

                for _, plr in pairs(game.Players:GetPlayers()) do
                        if plr ~= client then
                                local playerFrame = script:WaitForChild("PlayerFrame"):Clone()
                                playerFrame.PlayerDisplayName.Text = plr.DisplayName
                                playerFrame.PlayerUserName.Text = "@" .. plr.Name
                                playerFrame.PlayerImage.Image = game.Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot,
                                        Enum.ThumbnailSize.Size100x100)

                                playerFrame.SendButton.MouseButton1Click:Connect(function()
                                        if tradeRequestFrame.Visible == false then
                                                print("🔄 TradeClient: Sending trade request to", plr.Name)
                                                tradeEvent:FireServer("send trade request", { plr })
                                        end
                                end)
                                
                                local viewInvBtn = playerFrame:FindFirstChild("ViewInventory")
                                if viewInvBtn then
                                        viewInvBtn.MouseButton1Click:Connect(function()
                                                populateViewInventory(plr)
                                        end)
                                end

                                playerFrame.Parent = sendTradesFrame.PlayerList
                        end
                end

                sendTradesFrame.Visible = true
        end
end)

sendTradesFrame.CloseButton.MouseButton1Click:Connect(function()
        sendTradesFrame.Visible = false
end)

tradeRequestFrame.RejectButton.MouseButton1Click:Connect(function()
        tradeEvent:FireServer("reject trade request")
end)

tradeRequestFrame.AcceptButton.MouseButton1Click:Connect(function()
        tradeEvent:FireServer("accept trade request")
end)

tradeFrame.TradingFrame.RejectButton.MouseButton1Click:Connect(function()
        tradeEvent:FireServer("reject trade")
end)

tradeFrame.TradingFrame.AcceptButton.MouseButton1Click:Connect(function()
        tradeEvent:FireServer("accept trade")

        if tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 == Color3.fromRGB(58, 191, 232) then
                tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(40, 109, 152)
        else
                tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(58, 191, 232)
        end
end)

sendTradesFrame.OpenHistory.MouseButton1Click:Connect(function()
        if tradeHistoryFrame.Visible then
                tradeHistoryFrame.Visible = false
        else
                tradeEvent:FireServer("get trade history")
                tradeHistoryFrame.Visible = true
        end
end)

tradeHistoryFrame.CloseButton.MouseButton1Click:Connect(function()
        tradeHistoryFrame.Visible = false
end)

local viewInvCloseBtn = viewInventoryFrame:FindFirstChild("Close")
if viewInvCloseBtn then
        viewInvCloseBtn.MouseButton1Click:Connect(function()
                viewInventoryFrame.Visible = false
                
                for _, btn in pairs(viewInventoryButtons) do
                        if btn then
                                btn:Destroy()
                        end
                end
                viewInventoryButtons = {}
        end)
end

tradeEvent.OnClientEvent:Connect(function(instruction, data)
        if instruction == "load trade history" then
                local scrollFrame = tradeHistoryFrame.Main.ScrollingFrame
                
                for _, child in pairs(scrollFrame:GetChildren()) do
                        if child:IsA("Frame") then
                                child:Destroy()
                        end
                end
                
                if not data or #data == 0 then
                        return
                end
                
                for _, historyEntry in ipairs(data) do
                        local historyFrame = script.HistoryFrame:Clone()
                        
                        historyFrame.PlayerUser.Text = "@" .. historyEntry.OtherPlayer
                        
                        local dateLabel = historyFrame:FindFirstChild("Date")
                        if dateLabel then
                                dateLabel.Text = historyEntry.Date
                        end
                        
                        historyFrame.ForValue.Text = "For: " .. formatValueShort(historyEntry.ReceivedValue)
                        historyFrame.GaveValue.Text = "Gave: " .. formatValueShort(historyEntry.GaveValue)
                        
                        local success, pfp = pcall(function()
                                return game.Players:GetUserThumbnailAsync(historyEntry.OtherPlayerId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                        end)
                        if success then
                                historyFrame.PlayerImage1.Image = pfp
                        end
                        
                        for _, item in ipairs(historyEntry.ReceivedItems) do
                                local itemBtn = script.ItemButton:Clone()
                                itemBtn.ItemName.Text = item.Name
                                itemBtn.ItemImage1.Image = getItemThumbnail(item.RobloxId)
                                if item.SerialNumber then
                                        itemBtn.QtySerial.Text = "#" .. item.SerialNumber
                                elseif item.Amount and item.Amount > 1 then
                                        itemBtn.QtySerial.Text = "x" .. item.Amount
                                else
                                        itemBtn.QtySerial.Text = ""
                                end
                                itemBtn.Parent = historyFrame.For
                        end
                        
                        for _, item in ipairs(historyEntry.GaveItems) do
                                local itemBtn = script.ItemButton:Clone()
                                itemBtn.ItemName.Text = item.Name
                                itemBtn.ItemImage1.Image = getItemThumbnail(item.RobloxId)
                                if item.SerialNumber then
                                        itemBtn.QtySerial.Text = "#" .. item.SerialNumber
                                elseif item.Amount and item.Amount > 1 then
                                        itemBtn.QtySerial.Text = "x" .. item.Amount
                                else
                                        itemBtn.QtySerial.Text = ""
                                end
                                itemBtn.Parent = historyFrame.Gave
                        end
                        
                        historyFrame.Parent = scrollFrame
                end
                
        elseif instruction == "countdown update" then
                if tradeFrame.Visible then
                        tradeFrame.TradingFrame.PlayerAccepted.Text = "Trade completing in " .. tostring(data) .. "..."
                end
                
        elseif instruction == "countdown cancelled" then
                if tradeFrame.Visible then
                        tradeFrame.TradingFrame.PlayerAccepted.Text = ""
                end
                
        elseif instruction == "trade completed" then
                tradeFrame.Visible = false
                openBtn.Visible = true
                for _, btn in pairs(currentInventoryButtons) do
                        if btn then
                                btn:Destroy()
                        end
                end
                currentInventoryButtons = {}
        end
end)
