--VARIABLES
local client = game.Players.LocalPlayer

local rs = game.ReplicatedStorage:WaitForChild("TradeReplicatedStorage")
local re = rs:WaitForChild("RemoteEvent")
local config = require(rs:WaitForChild("CONFIGURATION"))

local tradeRequestsFolder = rs:WaitForChild("TRADE REQUESTS")
local ongoingTradesFolder = rs:WaitForChild("ONGOING TRADES")


local function getItemFromStorage(itemName)
  local itemsFolder = game.ReplicatedStorage:WaitForChild("Items")

  -- Search through all subfolders in Items
  for _, folder in pairs(itemsFolder:GetChildren()) do
    if folder:IsA("Folder") then
      local foundItem = folder:FindFirstChild(itemName)
      if foundItem then
        return foundItem
      end
    end
  end

  -- If not found in subfolders, check directly in Items
  return itemsFolder:FindFirstChild(itemName)
end


local gui = script.Parent

local openBtn = gui:WaitForChild("OpenSendTrades")
local sendTradesFrame = gui:WaitForChild("SendTradesFrame")
local tradeRequestFrame = gui:WaitForChild("TradeRequestFrame")
local tradeFrame = gui:WaitForChild("TradeFrame")
local tradeHistoryFrame = gui:WaitForChild("TradeHistoryFrame")
local tradeHistoryMain = tradeHistoryFrame:WaitForChild("Main")
local tradeHistoryScrollingFrame = tradeHistoryMain:WaitForChild("ScrollingFrame")

sendTradesFrame.Visible = false
tradeRequestFrame.Visible = false
tradeFrame.Visible = false
tradeHistoryFrame.Visible = false

-- Search functionality variables
local searchQuery = ""
local filteredItems = {}

local function formatNumber(num)
  if num >= 1000000000 then
    return string.format("%.1fB", num / 1000000000)
  elseif num >= 1000000 then
    return string.format("%.1fM", num / 1000000)
  elseif num >= 1000 then
    return string.format("%.1fK", num / 1000)
  else
    return tostring(num)
  end
end

-- Add this function to check if item is tradeable
local function isItemTradeable(item)
  -- Check if the item has a "NoTrade" value/property
  local noTrade = item:FindFirstChild("NoTrade")
  if noTrade then
    return false -- Item is not tradeable
  end
  return true -- Item is tradeable
end

-- Add this function to calculate offer values
local function calculateOfferValue(offerFolder)
  local totalValue = 0
  for _, item in pairs(offerFolder:GetChildren()) do
    local itemValue = item:FindFirstChild("Value") and item.Value.Value or 0
    local tradeAmount = item:FindFirstChild("TradeAmount") and item.TradeAmount.Value or 1
    totalValue = totalValue + (itemValue * tradeAmount)
  end
  return totalValue
end

-- Add this function to update value displays
local function updateValueDisplays()
  local currentTrade = nil
  for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
    if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") and 
      (trade.Sender.Value == client.Name or trade.Receiver.Value == client.Name) then
      currentTrade = trade
      break
    end
  end

  if currentTrade then
    local clientValue = currentTrade:FindFirstChild("Sender") and currentTrade.Sender.Value == client.Name and currentTrade.Sender or currentTrade.Receiver
    local otherPlrValue = clientValue.Name == "Sender" and currentTrade.Receiver or currentTrade.Sender

    local clientOffer = currentTrade:FindFirstChild(clientValue.Value .. "'s offer")
    local otherPlrOffer = currentTrade:FindFirstChild(otherPlrValue.Value .. "'s offer")

    if clientOffer and otherPlrOffer then
      local clientOfferValue = calculateOfferValue(clientOffer)
      local otherOfferValue = calculateOfferValue(otherPlrOffer)

      -- Update your offer value
      if tradeFrame.TradingFrame.YourOfferFrame:FindFirstChild("YourOfferText") then
        tradeFrame.TradingFrame.YourOfferFrame.YourOfferText.Text = "Your offer"
      end
      if tradeFrame.TradingFrame.YourOfferFrame:FindFirstChild("YourValue") then
        tradeFrame.TradingFrame.YourOfferFrame.YourValue.Text = "Value: " .. formatNumber(clientOfferValue)
      end

      -- Update their offer value
      if tradeFrame.TradingFrame.TheirOfferFrame:FindFirstChild("TheirOfferText") then
        tradeFrame.TradingFrame.TheirOfferFrame.TheirOfferText.Text = otherPlrValue.Value .. "'s offer"
      end
      if tradeFrame.TradingFrame.TheirOfferFrame:FindFirstChild("TheirValue") then
        tradeFrame.TradingFrame.TheirOfferFrame.TheirValue.Text = "Value: " .. formatNumber(otherOfferValue)
      end
    end
  end
end

--SORT ITEMS BY VALUE
local function sortItemsByValue(items)
  local sortedItems = {}
  for i, item in pairs(items) do
    table.insert(sortedItems, item)
  end

  table.sort(sortedItems, function(a, b)
    local aValue = a:FindFirstChild("Value") and a.Value.Value or 0
    local bValue = b:FindFirstChild("Value") and b.Value.Value or 0
    return aValue > bValue -- Highest value first
  end)

  return sortedItems
end

-- SEARCH FUNCTIONALITY
local function itemMatchesSearch(item, query)
  if query == "" then
    return true
  end

  local itemName = item.Name:lower()
  local searchLower = query:lower()

  -- Check if item name contains search query
  if string.find(itemName, searchLower, 1, true) then
    return true
  end

  -- Check item type if it exists
  local itemType = item:FindFirstChild("ItemType")
  if itemType and string.find(itemType.Value:lower(), searchLower, 1, true) then
    return true
  end

  return false
end

local function filterItemsBySearch(items, query)
  local filtered = {}
  for _, item in pairs(items) do
    if itemMatchesSearch(item, query) then
      table.insert(filtered, item)
    end
  end
  return filtered
end

--GET ITEM DISPLAY INFO
local function getItemDisplayInfo(item)
  local itemType = item:FindFirstChild("ItemType") and item.ItemType.Value or "unknown"
  local displayInfo = {}

  if itemType == "face" then
    displayInfo.useViewport = false
    displayInfo.imageId = item:FindFirstChild("DecalId") and item.DecalId.Value or ""
  else
    displayInfo.useViewport = true
  end

  return displayInfo
end

-- IMPROVED VIEWPORT SETUP
local function setupItemViewport(viewportFrame, itemSource)
  local itemModel = Instance.new("Model")
  itemModel.Name = itemSource.Name
  local thumbCam = itemSource:FindFirstChildWhichIsA("Camera")

  for _, child in pairs(itemSource:GetChildren()) do
    if not (child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") or child:IsA("Sound")) then
      local cloned = child:Clone()
      cloned.Parent = itemModel
    end
  end

  itemModel:PivotTo(CFrame.Angles(0, math.rad(180), 0))
  itemModel.Parent = viewportFrame

  if thumbCam then
    local clonedCam = thumbCam:Clone()
    clonedCam.Parent = viewportFrame
    viewportFrame.CurrentCamera = clonedCam
  else
    local fallbackCam = Instance.new("Camera")
    local center = itemModel:GetPivot().Position
    local offset = Vector3.new(1.2, 1.2, 2.2) -- Closer view
    fallbackCam.CFrame = CFrame.new(center + offset, center)
    fallbackCam.Parent = viewportFrame
    viewportFrame.CurrentCamera = fallbackCam
  end
end

--GET QUANTITY IN TRADE FOR ITEM
local function getQuantityInTrade(item)
  local currentTrade = nil
  for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
    if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") and 
      (trade.Sender.Value == client.Name or trade.Receiver.Value == client.Name) then
      currentTrade = trade
      break
    end
  end

  if currentTrade then
    local clientOffer = currentTrade:FindFirstChild(client.Name .. "'s offer")
    if clientOffer then
      for _, tradeItem in pairs(clientOffer:GetChildren()) do
        if tradeItem.Name == item.Name then
          return tradeItem:FindFirstChild("TradeAmount") and tradeItem.TradeAmount.Value or 1
        end
      end
    end
  end

  return 0
end

--CREATE ITEM BUTTON
local function createItemButton(item, isForInventory)
  local newToolButton = script:WaitForChild("ItemButton"):Clone()
  newToolButton.Name = item:FindFirstChild("TRADING ID") and tostring(item["TRADING ID"].Value) or item.Name

  -- Get quantities
  local totalAmount = item:FindFirstChild("Amount") and item.Amount.Value or 1
  local tradeAmount = 0

  if isForInventory then
    tradeAmount = getQuantityInTrade(item)
  else
    tradeAmount = item:FindFirstChild("TradeAmount") and item.TradeAmount.Value or 1
  end

  -- Set item name with quantity
  if isForInventory then
    -- Show remaining quantity for inventory items
    local remainingAmount = totalAmount - tradeAmount
    if remainingAmount > 1 then
      newToolButton.ItemName.Text = item.Name .. " x" .. remainingAmount
    else
      newToolButton.ItemName.Text = item.Name
    end
  else
    -- Show trade quantity for trade items
    if tradeAmount > 1 then
      newToolButton.ItemName.Text = item.Name .. " x" .. tradeAmount
    else
      newToolButton.ItemName.Text = item.Name
    end
  end

  newToolButton.IsInTrade.Visible = false

  local displayInfo = getItemDisplayInfo(item)

  if displayInfo.useViewport then
    -- Use improved viewport for tools and accessories
    newToolButton.ItemImageLabel.Visible = false
    setupItemViewport(newToolButton.ItemViewportFrame, item)

    -- Add quantity label to viewport
    if not newToolButton.ItemViewportFrame:FindFirstChild("QuantityLabel") then
      local quantityLabel = Instance.new("TextLabel")
      quantityLabel.Name = "QuantityLabel"
      quantityLabel.Size = UDim2.new(0, 30, 0, 20)
      quantityLabel.Position = UDim2.new(0, 5, 0, 5)
      quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
      quantityLabel.BackgroundTransparency = 0.3
      quantityLabel.BorderSizePixel = 0
      quantityLabel.Text = isForInventory and tostring(totalAmount - tradeAmount) or tostring(tradeAmount)
      quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      quantityLabel.TextScaled = true
      quantityLabel.Font = Enum.Font.GothamBold
      quantityLabel.Parent = newToolButton.ItemViewportFrame

      -- Only show if quantity > 1
      quantityLabel.Visible = (isForInventory and (totalAmount - tradeAmount) > 1) or (not isForInventory and tradeAmount > 1)
    end
  else
    -- Use image for faces
    newToolButton.ItemViewportFrame.Visible = false
    newToolButton.ItemImageLabel.Image = "rbxasset://textures/face.png" -- Default face texture
    if displayInfo.imageId and displayInfo.imageId ~= "" then
      newToolButton.ItemImageLabel.Image = "rbxassetid://" .. displayInfo.imageId
    end

    -- Add quantity label to image
    if not newToolButton.ItemImageLabel:FindFirstChild("QuantityLabel") then
      local quantityLabel = Instance.new("TextLabel")
      quantityLabel.Name = "QuantityLabel"
      quantityLabel.Size = UDim2.new(0, 30, 0, 20)
      quantityLabel.Position = UDim2.new(0, 5, 0, 5)
      quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
      quantityLabel.BackgroundTransparency = 0.3
      quantityLabel.BorderSizePixel = 0
      quantityLabel.Text = isForInventory and tostring(totalAmount - tradeAmount) or tostring(tradeAmount)
      quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      quantityLabel.TextScaled = true
      quantityLabel.Font = Enum.Font.GothamBold
      quantityLabel.Parent = newToolButton.ItemImageLabel

      -- Only show if quantity > 1
      quantityLabel.Visible = (isForInventory and (totalAmount - tradeAmount) > 1) or (not isForInventory and tradeAmount > 1)
    end
  end

  return newToolButton
end

--UPDATE INVENTORY DISPLAY
local function updateInventoryDisplay()
  local inventoryList = tradeFrame.InventoryFrame.InventoryList

  -- Clear existing buttons
  for i, child in pairs(inventoryList:GetChildren()) do
    if child:IsA("TextButton") or child:IsA("ImageButton") then
      child:Destroy()
    end
  end

  if client.AccessoryInventory then
    local clientItems = {}
    for i, item in pairs(client.AccessoryInventory:GetChildren()) do
      -- Only add tradeable items to the list
      if isItemTradeable(item) then
        table.insert(clientItems, item)
      end
    end

    -- Filter items based on search query
    local filteredItems = filterItemsBySearch(clientItems, searchQuery)
    local sortedItems = sortItemsByValue(filteredItems)

    for i, item in pairs(sortedItems) do
      local newToolButton = createItemButton(item, true)
      local totalAmount = item:FindFirstChild("Amount") and item.Amount.Value or 1
      local tradeAmount = getQuantityInTrade(item)

      -- Show if item has any amount in trade
      newToolButton.IsInTrade.Visible = tradeAmount > 0

      newToolButton.MouseButton1Click:Connect(function()
        local currentTradeAmount = getQuantityInTrade(item)
        local availableAmount = totalAmount - currentTradeAmount

        if availableAmount > 0 then
          -- Add one item to trade
          re:FireServer("add item to trade", {item})
        elseif currentTradeAmount > 0 then
          -- Remove one item from trade
          re:FireServer("remove item from trade", {item})
        end
      end)

      newToolButton.Parent = inventoryList
    end
  end
end

-- SEARCH BAR FUNCTIONALITY
local function setupSearchBar()
  local searchInv = tradeFrame.InventoryFrame:FindFirstChild("SearchInv")
  if searchInv then
    -- Connect search functionality
    searchInv:GetPropertyChangedSignal("Text"):Connect(function()
      searchQuery = searchInv.Text
      updateInventoryDisplay()
    end)

    -- Clear search when focus is lost and text is empty
    searchInv.FocusLost:Connect(function()
      if searchInv.Text == "" then
        searchQuery = ""
        updateInventoryDisplay()
      end
    end)

    -- Optional: Add placeholder text behavior
    if searchInv.Text == "" then
      searchInv.PlaceholderText = "Search items..."
    end
  end
end

--TRADE REQUESTS
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

--ONGOING TRADES
ongoingTradesFolder.ChildAdded:Connect(function(child)

  if child:WaitForChild("Sender").Value == client.Name or child:WaitForChild("Receiver").Value == client.Name then

    local clientValue = child:WaitForChild("Sender").Value == client.Name and child.Sender or child.Receiver
    local otherPlrValue = clientValue.Name == "Sender" and child.Receiver or child.Sender

    clientValue.AncestryChanged:Connect(function()
      if clientValue.Parent == nil then
        tradeFrame.Visible = false
        openBtn.Visible = true
      end
    end)

    tradeRequestFrame.Visible = false
    sendTradesFrame.Visible = false
    openBtn.Visible = false

    tradeFrame.TradingFrame.TradingWithName.Text = "Trading with " .. otherPlrValue.Value
    tradeFrame.TradingFrame.TheirOfferFrame.TheirOfferText.Text = otherPlrValue.Value .. "'s offer"
    tradeFrame.TradingFrame.PlayerAccepted.Text = ""

    tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(58, 191, 232)

    for i, child in pairs(tradeFrame.TradingFrame.YourOfferFrame:GetChildren()) do
      if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
        child:Destroy()
      end
    end
    for i, child in pairs(tradeFrame.TradingFrame.TheirOfferFrame:GetChildren()) do
      if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
        child:Destroy()
      end
    end

    --Alert client when other player has accepted
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
    child.ChildAdded:Connect(function(timerChild)
      if timerChild.Name == "TradeTimer" then
        local timerLabel = tradeFrame.TradingFrame:FindFirstChild("TimerLabel")
        if not timerLabel then
          timerLabel = Instance.new("TextLabel")
          timerLabel.Name = "TimerLabel"
          timerLabel.Size = UDim2.new(0, 200, 0, 30)
          timerLabel.Position = UDim2.new(0.5, -100, 0, 10)
          timerLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
          timerLabel.BackgroundTransparency = 0.2
          timerLabel.BorderSizePixel = 0
          timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
          timerLabel.TextScaled = true
          timerLabel.Font = Enum.Font.GothamBold
          timerLabel.Parent = tradeFrame.TradingFrame
        end

        local connection
        connection = timerChild.Changed:Connect(function()
          local timeLeft = math.ceil(timerChild.Value)
          if timeLeft > 0 then
            timerLabel.Text = "Trade completing in " .. timeLeft .. "s"
            timerLabel.Visible = true
          else
            timerLabel.Visible = false
            connection:Disconnect()
          end
        end)

        timerChild.AncestryChanged:Connect(function()
          if timerChild.Parent == nil and timerLabel then
            timerLabel.Visible = false
            if connection then
              connection:Disconnect()
            end
          end
        end)
      end
    end)

    -- Initial value display update after trade frame becomes visible
    updateValueDisplays()

    -- Setup search bar functionality
    setupSearchBar()

    --Display player's inventory
    updateInventoryDisplay()

    --Display client's offer
    local clientOffer = child[clientValue.Value .. "'s offer"]

    clientOffer.ChildAdded:Connect(function(child)
      updateInventoryDisplay() -- Update inventory when items are added to trade
      updateValueDisplays() -- Update value displays

      local newToolButton = createItemButton(child, false)
      newToolButton.IsInTrade.Visible = false
      newToolButton.Size = script.ItemButton.Size

      newToolButton.MouseButton1Click:Connect(function()
        if client.AccessoryInventory then
          for i, plrItem in pairs(client.AccessoryInventory:GetChildren()) do
            if plrItem:FindFirstChild("TRADING ID") and child:FindFirstChild("TRADING ID") and child["TRADING ID"].Value == plrItem["TRADING ID"].Value then
              re:FireServer("remove item from trade", {plrItem})
              break
            end
          end				
        end
      end)

      child.AncestryChanged:Connect(function()
        if child.Parent == nil then
          updateInventoryDisplay() -- Update inventory when items are removed from trade
          updateValueDisplays() -- Update value displays
          newToolButton:Destroy()
        end
      end)

      -- Update when TradeAmount changes
      local tradeAmountValue = child:FindFirstChild("TradeAmount")
      if tradeAmountValue then
        tradeAmountValue.Changed:Connect(function()
          updateInventoryDisplay()
          updateValueDisplays() -- Update value displays
          -- Update button text
          if tradeAmountValue.Value > 1 then
            newToolButton.ItemName.Text = child.Name .. " x" .. tradeAmountValue.Value
          else
            newToolButton.ItemName.Text = child.Name
          end

          -- Update quantity label
          local quantityLabel = newToolButton.ItemViewportFrame:FindFirstChild("QuantityLabel") or newToolButton.ItemImageLabel:FindFirstChild("QuantityLabel")
          if quantityLabel then
            quantityLabel.Text = tostring(tradeAmountValue.Value)
            quantityLabel.Visible = tradeAmountValue.Value > 1
          end
        end)
      end

      newToolButton.Parent = tradeFrame.TradingFrame.YourOfferFrame.Slots
    end)

    --Display other player's offer
    local otherPlrOffer = child[otherPlrValue.Value .. "'s offer"]

    otherPlrOffer.ChildAdded:Connect(function(child)
      updateValueDisplays() -- Update value displays

      local newToolButton = createItemButton(child, false)
      newToolButton.AutoButtonColor = false

      -- Update when TradeAmount changes
      local tradeAmountValue = child:FindFirstChild("TradeAmount")
      if tradeAmountValue then
        tradeAmountValue.Changed:Connect(function()
          updateValueDisplays() -- Update value displays
          -- Update button text
          if tradeAmountValue.Value > 1 then
            newToolButton.ItemName.Text = child.Name .. " x" .. tradeAmountValue.Value
          else
            newToolButton.ItemName.Text = child.Name
          end

          -- Update quantity label
          local quantityLabel = newToolButton.ItemViewportFrame:FindFirstChild("QuantityLabel") or newToolButton.ItemImageLabel:FindFirstChild("QuantityLabel")
          if quantityLabel then
            quantityLabel.Text = tostring(tradeAmountValue.Value)
            quantityLabel.Visible = tradeAmountValue.Value > 1
          end
        end)
      end

      child.AncestryChanged:Connect(function()
        if child.Parent == nil then
          updateValueDisplays() -- Update value displays
          newToolButton:Destroy()
        end
      end)

      newToolButton.Parent = tradeFrame.TradingFrame.TheirOfferFrame.Slots
    end)

    tradeFrame.Visible = true
  end
end)
local function calculatePlayerInvValue(player)
  local totalValue = 0
  if player.AccessoryInventory then
    for _, item in pairs(player.AccessoryInventory:GetChildren()) do
      -- Only include tradeable items in the value calculation
      if isItemTradeable(item) then
        local itemValue = item:FindFirstChild("Value") and item.Value.Value or 0
        local itemAmount = item:FindFirstChild("Amount") and item.Amount.Value or 1
        totalValue = totalValue + (itemValue * itemAmount)
      end
    end
  end
  return totalValue
end
--SEND TRADE REQUESTS
openBtn.MouseButton1Click:Connect(function()

  if sendTradesFrame.Visible == true then
    sendTradesFrame.Visible = false

  elseif tradeFrame.Visible == false then

    for i, child in pairs(sendTradesFrame.PlayerList:GetChildren()) do
      if child:IsA("Frame") then
        child:Destroy()
      end
    end

    for i, plr in pairs(game.Players:GetPlayers()) do

      if plr ~= client then
        local playerFrame = script:WaitForChild("PlayerFrame"):Clone()
        playerFrame.PlayerDisplayName.Text = plr.DisplayName
        playerFrame.PlayerUserName.Text = "@" .. plr.Name
        playerFrame.PlayerImage.Image = game.Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)

        -- Add PlayerValue display
        if playerFrame:FindFirstChild("PlayerValue") then
          local playerInvValue = calculatePlayerInvValue(plr)
          playerFrame.PlayerValue.Text = "R$ " .. formatNumber(playerInvValue)
        end

        playerFrame.SendButton.MouseButton1Click:Connect(function()
          if tradeRequestFrame.Visible == false then
            re:FireServer("send trade request", {plr})
          end
        end)

        playerFrame.ViewInv.MouseButton1Click:Connect(function()
          -- Get the View Inv GUI
          local viewInvGui = client.PlayerGui:WaitForChild("View Inv")

          -- Find the Target StringValue (parented to the Ind LocalScript)
          local indScript = viewInvGui.Frame:WaitForChild("ind")
          local targetValue = indScript:WaitForChild("Target")

          -- Update the target player's name
          targetValue.Value = plr.Name

          -- Open the GUI
          viewInvGui.Open.Value = true
        end)

        playerFrame.Parent = sendTradesFrame.PlayerList
      end
    end

    sendTradesFrame.Visible = true
  end
end)

sendTradesFrame.CloseButton.MouseButton1Click:Connect(function()
  sendTradesFrame.Visible = false
end)

--ACCEPT OR REJECT TRADE REQUESTS
tradeRequestFrame.RejectButton.MouseButton1Click:Connect(function()
  re:FireServer("reject trade request")
end)

tradeRequestFrame.AcceptButton.MouseButton1Click:Connect(function()
  re:FireServer("accept trade request")
end)

--ACCEPT OR REJECT TRADES
tradeFrame.TradingFrame.RejectButton.MouseButton1Click:Connect(function()
  re:FireServer("reject trade")
end)

tradeFrame.TradingFrame.AcceptButton.MouseButton1Click:Connect(function()
  re:FireServer("accept trade")

  if tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 == Color3.fromRGB(58, 191, 232) then
    tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(40, 109, 152)
  else
    tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(58, 191, 232)
  end
end)
local function calculateHistoryValue(itemsData)
  local totalValue = 0

  for _, itemData in pairs(itemsData) do
    -- Try to get the actual item from ReplicatedStorage for accurate value
    local actualItem = getItemFromStorage(itemData.name)
    local itemValue = 0

    if actualItem then
      itemValue = actualItem:FindFirstChild("Value") and actualItem.Value.Value or 0
    else
      -- Fallback to stored value if available
      itemValue = itemData.value or 0
    end

    totalValue = totalValue + (itemValue * itemData.amount)
  end

  return totalValue
end
local function formatDate(timestamp)
  local date = os.date("*t", timestamp)
  return string.format("%02d %02d %04d", date.month, date.day, date.year)
end
local function createItemButtonFromData(itemData)
  local newToolButton = script:WaitForChild("ItemButton"):Clone()
  newToolButton.Name = itemData.name

  -- Set item name with quantity
  if itemData.amount > 1 then
    newToolButton.ItemName.Text = itemData.name .. " x" .. itemData.amount
  else
    newToolButton.ItemName.Text = itemData.name
  end

  newToolButton.IsInTrade.Visible = false

  -- Try to get the actual item from ReplicatedStorage for proper display
  local actualItem = getItemFromStorage(itemData.name)

  if actualItem then
    local displayInfo = getItemDisplayInfo(actualItem)

    if displayInfo.useViewport then
      -- Use improved viewport for tools and accessories
      newToolButton.ItemImageLabel.Visible = false
      setupItemViewport(newToolButton.ItemViewportFrame, actualItem)

      -- Add quantity label to viewport
      if itemData.amount > 1 then
        local quantityLabel = Instance.new("TextLabel")
        quantityLabel.Name = "QuantityLabel"
        quantityLabel.Size = UDim2.new(0, 30, 0, 20)
        quantityLabel.Position = UDim2.new(0, 5, 0, 5)
        quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        quantityLabel.BackgroundTransparency = 0.3
        quantityLabel.BorderSizePixel = 0
        quantityLabel.Text = tostring(itemData.amount)
        quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        quantityLabel.TextScaled = true
        quantityLabel.Font = Enum.Font.GothamBold
        quantityLabel.Parent = newToolButton.ItemViewportFrame
      end
    else
      -- Use image for faces
      newToolButton.ItemViewportFrame.Visible = false
      newToolButton.ItemImageLabel.Image = "rbxasset://textures/face.png"
      if displayInfo.imageId and displayInfo.imageId ~= "" then
        newToolButton.ItemImageLabel.Image = "rbxassetid://" .. displayInfo.imageId
      end

      -- Add quantity label to image
      if itemData.amount > 1 then
        local quantityLabel = Instance.new("TextLabel")
        quantityLabel.Name = "QuantityLabel"
        quantityLabel.Size = UDim2.new(0, 30, 0, 20)
        quantityLabel.Position = UDim2.new(0, 5, 0, 5)
        quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        quantityLabel.BackgroundTransparency = 0.3
        quantityLabel.BorderSizePixel = 0
        quantityLabel.Text = tostring(itemData.amount)
        quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        quantityLabel.TextScaled = true
        quantityLabel.Font = Enum.Font.GothamBold
        quantityLabel.Parent = newToolButton.ItemImageLabel
      end
    end
  else
    -- Fallback if item not found in storage
    if itemData.itemType == "face" then
      newToolButton.ItemViewportFrame.Visible = false
      newToolButton.ItemImageLabel.Image = "rbxasset://textures/face.png"
      if itemData.decalId and itemData.decalId ~= "" then
        newToolButton.ItemImageLabel.Image = "rbxassetid://" .. itemData.decalId
      end
    else
      -- For other items, show viewport with placeholder
      newToolButton.ItemImageLabel.Visible = false
    end

    -- Add quantity label regardless
    if itemData.amount > 1 then
      local quantityLabel = Instance.new("TextLabel")
      quantityLabel.Name = "QuantityLabel"
      quantityLabel.Size = UDim2.new(0, 30, 0, 20)
      quantityLabel.Position = UDim2.new(0, 5, 0, 5)
      quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
      quantityLabel.BackgroundTransparency = 0.3
      quantityLabel.BorderSizePixel = 0
      quantityLabel.Text = tostring(itemData.amount)
      quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      quantityLabel.TextScaled = true
      quantityLabel.Font = Enum.Font.GothamBold

      if newToolButton.ItemViewportFrame.Visible then
        quantityLabel.Parent = newToolButton.ItemViewportFrame
      else
        quantityLabel.Parent = newToolButton.ItemImageLabel
      end
    end
  end

  return newToolButton
end
-- Add this function to create history entry
local function createHistoryEntry(historyData)
  local historyFrame = script:WaitForChild("HistoryFrame"):Clone()

  -- Set player info
  historyFrame.PlayerUser.Text = "@" .. historyData.tradedWith
  historyFrame.Date.Text = formatDate(historyData.timestamp)

  -- Set player image
  local success, playerImage = pcall(function()
    return game.Players:GetUserThumbnailAsync(historyData.tradedWithUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
  end)
  if success then
    historyFrame.PlayerImage1.Image = playerImage
  end

  -- Calculate and display values
  local gaveValue = calculateHistoryValue(historyData.given)
  local forValue = calculateHistoryValue(historyData.received)

  -- Set value displays (assuming these TextLabels exist in your HistoryFrame)
  if historyFrame:FindFirstChild("GaveValue") then
    historyFrame.GaveValue.Text = "Value: " .. formatNumber(gaveValue)
  end
  if historyFrame:FindFirstChild("ForValue") then
    historyFrame.ForValue.Text = "Value: " .. formatNumber(forValue)
  end

  -- Clear existing items
  for _, child in pairs(historyFrame.For:GetChildren()) do
    if child:IsA("TextButton") or child:IsA("ImageButton") then
      child:Destroy()
    end
  end
  for _, child in pairs(historyFrame.Gave:GetChildren()) do
    if child:IsA("TextButton") or child:IsA("ImageButton") then
      child:Destroy()
    end
  end

  -- Add received items (For)
  for _, itemData in pairs(historyData.received) do
    local itemButton = createItemButtonFromData(itemData)
    itemButton.AutoButtonColor = false
    itemButton.Parent = historyFrame.For
  end

  -- Add given items (Gave)
  for _, itemData in pairs(historyData.given) do
    local itemButton = createItemButtonFromData(itemData)
    itemButton.AutoButtonColor = false
    itemButton.Parent = historyFrame.Gave
  end

  return historyFrame
end



-- Add this function to update trade history display
local function updateTradeHistoryDisplay()
  -- Clear existing history entries
  for _, child in pairs(tradeHistoryScrollingFrame:GetChildren()) do
    if child.Name == "HistoryFrame" then
      child:Destroy()
    end
  end

  -- Request trade history from server
  re:FireServer("get trade history")
end

-- Add this to handle trade history response from server
re.OnClientEvent:Connect(function(instruction, data)
  if instruction == "trade history response" then
    local historyData = data

    -- Sort by timestamp (most recent first)
    table.sort(historyData, function(a, b)
      return a.timestamp > b.timestamp
    end)

    -- Create history entries
    for _, history in pairs(historyData) do
      local historyFrame = createHistoryEntry(history)
      historyFrame.Parent = tradeHistoryScrollingFrame
    end
  end
end)
local tradeHistoryButton = gui.SendTradesFrame.OpenHistory -- Add this button to your GUI
tradeHistoryButton.MouseButton1Click:Connect(function()
  if tradeHistoryFrame.Visible then
    tradeHistoryFrame.Visible = false
  else
    tradeHistoryFrame.Visible = true
    updateTradeHistoryDisplay()
  end
end)

local tradeHistoryCloseButton = tradeHistoryFrame:WaitForChild("CloseButton") -- Adjust the path if your close button has a different name/location
tradeHistoryCloseButton.MouseButton1Click:Connect(function()
  tradeHistoryFrame.Visible = false
end)
