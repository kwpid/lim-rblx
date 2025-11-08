local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local gui = script.Parent -- This is now the "Inventory" Frame inside MainUI
local buttons = {}

local mainFrame = gui

local handler = gui:WaitForChild("Handler", 5)
if not handler then
  warn("handler not found in inventory gui")
  return
end

local sample = script:FindFirstChild("Sample")
if not sample then
  warn("sample template not found")
  return
end

local popup = script.Parent.Popout
if not popup then
  warn("popup not found in inventory gui")
  return
end

popup.Visible = true

local searchBar = gui:FindFirstChild("SearchBar")

local selected = handler:FindFirstChild("Selected")
if not selected then
  selected = Instance.new("StringValue")
  selected.Name = "Selected"
  selected.Parent = handler
elseif not selected:IsA("StringValue") then
  selected:Destroy()
  selected = Instance.new("StringValue")
  selected.Name = "Selected"
  selected.Parent = handler
end

local selectedItemData = nil
local selectedButton = nil
local selectedItemId = nil
local equippedItems = {}
local sellConfirmation = false
local sellAllConfirmation = false
local rarityCounts = {
  ["Common"] = 0,
  ["Uncommon"] = 0,
  ["Rare"] = 0,
  ["Ultra Rare"] = 0
}

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
  warn("remoteevents folder not found")
  return
end

local getInventoryFunction = remoteEvents:WaitForChild("GetInventoryFunction", 10)
if not getInventoryFunction then
  warn("getinventoryfunction not found")
  return
end

local equipItemEvent = remoteEvents:WaitForChild("EquipItemEvent", 10)
local sellItemEvent = remoteEvents:WaitForChild("SellItemEvent", 10)
local sellAllItemEvent = remoteEvents:WaitForChild("SellAllItemEvent", 10)
local sellByRarityEvent = remoteEvents:FindFirstChild("SellByRarityEvent") or Instance.new("RemoteEvent")
sellByRarityEvent.Name = "SellByRarityEvent"
sellByRarityEvent.Parent = remoteEvents
local getEquippedItemsFunction = remoteEvents:WaitForChild("GetEquippedItemsFunction", 10)
local createListingEvent = remoteEvents:WaitForChild("CreateListingEvent", 10)
local validateGamepassFunction = remoteEvents:WaitForChild("ValidateGamepassFunction", 10)

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

function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

function clearSelection()
  if selectedButton then
    local uiStroke = selectedButton:FindFirstChildOfClass("UIStroke")
    if uiStroke then
      uiStroke.Thickness = 5.5
    end
    selectedButton = nil
  end

  selectedItemData = nil
  selected.Value = ""
  sellConfirmation = false
  sellAllConfirmation = false
end

function refresh()
  local inventory
  local success, err = pcall(function()
    inventory = getInventoryFunction:InvokeServer()
  end)

  if not success or not inventory or type(inventory) ~= "table" then
    warn("failed to load inventory, will retry")
    return false
  end

  if getEquippedItemsFunction then
    local equippedSuccess, equippedResult = pcall(function()
      return getEquippedItemsFunction:InvokeServer()
    end)

    if equippedSuccess and equippedResult then
      equippedItems = {}
      for _, robloxId in ipairs(equippedResult) do
        equippedItems[robloxId] = true
      end
    end
  end

  for _, button in pairs(buttons) do
    button:Destroy()
  end
  buttons = {}

  -- Reset rarity counts
  rarityCounts["Common"] = 0
  rarityCounts["Uncommon"] = 0
  rarityCounts["Rare"] = 0
  rarityCounts["Ultra Rare"] = 0

  -- Calculate rarity counts (excluding stock items)
  for _, item in ipairs(inventory) do
    local isStockItem = item.Stock and item.Stock > 0
    if not isStockItem then
      local rarity = item.Rarity
      if rarity == "Common" or rarity == "Uncommon" or rarity == "Rare" or rarity == "Ultra Rare" then
        local amount = item.Amount or 1
        rarityCounts[rarity] = rarityCounts[rarity] + amount
      end
    end
  end

  -- Update bulk sell buttons
  local sellCommonsBtn = gui:FindFirstChild("SellCommons")
  local sellUncommonsBtn = gui:FindFirstChild("SellUncommons")
  local sellRaresBtn = gui:FindFirstChild("SellRares")
  local sellUltraRaresBtn = gui:FindFirstChild("SellUltraRares")

  if sellCommonsBtn then
    sellCommonsBtn.Text = "Sell Commons (" .. rarityCounts["Common"] .. ")"
  end
  if sellUncommonsBtn then
    sellUncommonsBtn.Text = "Sell Uncommons (" .. rarityCounts["Uncommon"] .. ")"
  end
  if sellRaresBtn then
    sellRaresBtn.Text = "Sell Rares (" .. rarityCounts["Rare"] .. ")"
  end
  if sellUltraRaresBtn then
    sellUltraRaresBtn.Text = "Sell Ultra Rares (" .. rarityCounts["Ultra Rare"] .. ")"
  end

  table.sort(inventory, function(a, b)
    local aEquipped = equippedItems[a.RobloxId] or false
    local bEquipped = equippedItems[b.RobloxId] or false

    if aEquipped ~= bEquipped then
      return aEquipped
    end

    local aVanity = a.Rarity == "Vanity"
    local bVanity = b.Rarity == "Vanity"

    if aVanity ~= bVanity then
      return aVanity
    end

    return a.Value > b.Value
  end)

  for i, item in ipairs(inventory) do
    local button = sample:Clone()
    button.Name = item.Name or "Item_" .. i
    button.LayoutOrder = i
    button.Visible = true
    button.Parent = handler

    local uiStroke = button:FindFirstChildOfClass("UIStroke")
    if uiStroke then
      local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
      uiStroke.Color = rarityColor
      uiStroke.Thickness = 5.5
    end

    local qtyLabel = button:FindFirstChild("Qty")
    if qtyLabel then
      local amount = item.Amount or 1
      if amount > 1 then
        qtyLabel.Text = tostring(amount)
        qtyLabel.Visible = true
      else
        qtyLabel.Visible = false
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
      if item.Rarity == "Limited" then
        limText.Visible = true
      else
        limText.Visible = false
      end
    end

    if button:IsA("ImageButton") then
      button.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
    end

    table.insert(buttons, button)

    button.MouseButton1Click:Connect(function()
      if selectedButton and selectedButton ~= button then
        local prevStroke = selectedButton:FindFirstChildOfClass("UIStroke")
        if prevStroke then
          prevStroke.Thickness = 5.5
        end
      end

      local currentStroke = button:FindFirstChildOfClass("UIStroke")
      if currentStroke then
        currentStroke.Thickness = 9
      end

      selectedButton = button
      selectedItemId = item.RobloxId

      local itemNameText = popup:WaitForChild("ItemName")
      local itemValueText = popup:WaitForChild("Value")
      local totalValueText = popup:FindFirstChild("TotalValue")
      local imgFrame = popup:WaitForChild("ImageLabel")

      itemNameText.Text = item.Name
      selected.Value = item.Name
      selectedItemData = item

      itemValueText.Text = "R$ " .. formatNumber(item.Value)

      if totalValueText then
        local totalValue = item.Value * (item.Amount or 1)
        totalValueText.Text = "Total: R$ " .. formatNumber(totalValue)
      end

      if imgFrame:IsA("ImageLabel") then
        imgFrame.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=420&h=420"
      else
        local existingImg = imgFrame:FindFirstChildOfClass("ImageLabel")

        if existingImg then
          existingImg.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=420&h=420"
        else
          for _, child in ipairs(imgFrame:GetChildren()) do
            child:Destroy()
          end

          local previewImg = Instance.new("ImageLabel")
          previewImg.Size = UDim2.new(1, 0, 1, 0)
          previewImg.BackgroundTransparency = 1
          previewImg.BorderSizePixel = 0
          previewImg.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=420&h=420"
          previewImg.Parent = imgFrame
        end
      end

      sellConfirmation = false
      sellAllConfirmation = false

      local equipButton = popup:FindFirstChild("Equip")
      if equipButton then
        if equippedItems[item.RobloxId] then
          equipButton.Text = "Unequip"
        else
          equipButton.Text = "Equip"
        end
      end

      local sellButton = popup:FindFirstChild("Sell")
      local sellAllButton = popup:FindFirstChild("SellAll")

      if sellButton then
        sellButton.Text = "Sell"
      end
      if sellAllButton then
        sellAllButton.Text = "Sell All"
      end

      local isStockItem = item.Stock and item.Stock > 0
      if sellButton then
        sellButton.Visible = not isStockItem
      end
      if sellAllButton then
        sellAllButton.Visible = not isStockItem
      end

      local serialOwnerText = popup:FindFirstChild("SerialOwner")
      if serialOwnerText then
        if item.SerialNumber and item.OriginalOwner then
          serialOwnerText.Visible = true
          serialOwnerText.Text = "Original Owner: @" .. item.OriginalOwner
        else
          serialOwnerText.Visible = false
        end
      end
      
      local marketSellBtn = popup:FindFirstChild("MarketSellBtn")
      if marketSellBtn then
        if item.Value >= 250000 then
          marketSellBtn.Visible = true
        else
          marketSellBtn.Visible = false
        end
      end
    end)
    
    if selectedItemId and item.RobloxId == selectedItemId then
      selectedButton = button
      local currentStroke = button:FindFirstChildOfClass("UIStroke")
      if currentStroke then
        currentStroke.Thickness = 9
      end
    end
  end

  return true
end

if searchBar and searchBar:IsA("TextBox") then
  searchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local filterText = searchBar.Text:lower()
    for _, button in pairs(buttons) do
      local itemName = button.Name:lower()
      button.Visible = filterText == "" or itemName:find(filterText, 1, true) ~= nil
    end
  end)
end

local function loadInventoryWithRetry()
  local maxRetries = 10
  local retryDelay = 0.5

  for attempt = 1, maxRetries do
    task.wait(retryDelay)

    local success, result = pcall(refresh)
    if success and result == true then
      return
    end

    retryDelay = math.min(retryDelay * 2, 4)
    warn(string.format("inventory load attempt %d/%d failed, retrying in %.1fs",
      attempt, maxRetries, retryDelay))
  end

  warn("failed to load inventory after " .. maxRetries .. " attempts")
end

task.spawn(loadInventoryWithRetry)

local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
if inventoryUpdatedEvent then
  inventoryUpdatedEvent.OnClientEvent:Connect(function()
    pcall(refresh)
  end)
end

gui:GetPropertyChangedSignal("Visible"):Connect(function()
  if gui.Visible then
    pcall(refresh)
  end
end)

local closeButton = popup:FindFirstChild("Close")
if closeButton then
  closeButton.MouseButton1Click:Connect(function()
    clearSelection()
  end)
end

local equipButton = popup:FindFirstChild("Equip")
if equipButton and equipItemEvent then
  equipButton.MouseButton1Click:Connect(function()
    if selectedItemData and selectedItemData.RobloxId then
      local isEquipped = equippedItems[selectedItemData.RobloxId]

      if isEquipped then
        equipItemEvent:FireServer(selectedItemData.RobloxId, true)
        equippedItems[selectedItemData.RobloxId] = nil
        equipButton.Text = "Equip"
      else
        equipItemEvent:FireServer(selectedItemData.RobloxId, false)
        equippedItems[selectedItemData.RobloxId] = true
        equipButton.Text = "Unequip"
      end

      task.wait(0.1)
      pcall(refresh)
    end
  end)
end

local sellButton = popup:FindFirstChild("Sell")
if sellButton and sellItemEvent then
  sellButton.MouseButton1Click:Connect(function()
    if selectedItemData and selectedItemData.RobloxId then
      if not sellConfirmation then
        sellConfirmation = true
        sellButton.Text = "Are you sure?"

        task.delay(3, function()
          if sellConfirmation then
            sellConfirmation = false
            sellButton.Text = "Sell"
          end
        end)
      else
        sellItemEvent:FireServer(selectedItemData.RobloxId, selectedItemData.SerialNumber)
        sellConfirmation = false
        sellButton.Text = "Sell"
      end
    end
  end)
end

local sellAllButton = popup:FindFirstChild("SellAll")
if sellAllButton and sellAllItemEvent then
  sellAllButton.MouseButton1Click:Connect(function()
    if selectedItemData and selectedItemData.RobloxId then
      if not sellAllConfirmation then
        sellAllConfirmation = true
        sellAllButton.Text = "Are you sure?"

        task.delay(3, function()
          if sellAllConfirmation then
            sellAllConfirmation = false
            sellAllButton.Text = "Sell All"
          end
        end)
      else
        sellAllItemEvent:FireServer(selectedItemData.RobloxId)
        sellAllConfirmation = false
        sellAllButton.Text = "Sell All"
      end
    end
  end)
end

-- Bulk sell by rarity functionality
local sellConfirmFrame = gui:FindFirstChild("SellConfirm")
local currentRarityForSell = nil
local confirmConnection = nil
local cancelConnection = nil

local function showSellConfirm(rarity, count, totalValue)
  if not sellConfirmFrame then return end
  
  local pop = sellConfirmFrame:FindFirstChild("Pop")
  if not pop then return end
  
  local text1 = pop:FindFirstChild("Text1")
  local sellPrice = pop:FindFirstChild("SellPrice")
  local confirmBtn = pop:FindFirstChild("Confirm")
  local cancelBtn = pop:FindFirstChild("Cancel")
  
  if text1 then
    text1.Text = "Are you sure you want to sell all " .. rarity .. "?"
  end
  
  if sellPrice then
    local cashValue = math.floor(totalValue * 0.8)
    sellPrice.Text = "You will sell " .. count .. " " .. rarity .. " for R$ " .. formatNumber(cashValue)
  end
  
  currentRarityForSell = rarity
  sellConfirmFrame.Visible = true
  
  -- Disconnect old connections
  if confirmConnection then
    confirmConnection:Disconnect()
    confirmConnection = nil
  end
  if cancelConnection then
    cancelConnection:Disconnect()
    cancelConnection = nil
  end
  
  if confirmBtn then
    confirmConnection = confirmBtn.MouseButton1Click:Connect(function()
      sellByRarityEvent:FireServer(currentRarityForSell)
      sellConfirmFrame.Visible = false
      task.wait(0.1)
      pcall(refresh)
    end)
  end
  
  if cancelBtn then
    cancelConnection = cancelBtn.MouseButton1Click:Connect(function()
      sellConfirmFrame.Visible = false
    end)
  end
end

local function calculateRarityValue(inventory, rarity)
  local totalValue = 0
  for _, item in ipairs(inventory) do
    local isStockItem = item.Stock and item.Stock > 0
    if not isStockItem and item.Rarity == rarity then
      local amount = item.Amount or 1
      totalValue = totalValue + (item.Value * amount)
    end
  end
  return totalValue
end

local sellCommonsBtn = gui:FindFirstChild("SellCommons")
if sellCommonsBtn then
  sellCommonsBtn.MouseButton1Click:Connect(function()
    if rarityCounts["Common"] > 0 then
      local inventory = getInventoryFunction:InvokeServer()
      if inventory then
        local totalValue = calculateRarityValue(inventory, "Common")
        showSellConfirm("Common", rarityCounts["Common"], totalValue)
      end
    end
  end)
end

local sellUncommonsBtn = gui:FindFirstChild("SellUncommons")
if sellUncommonsBtn then
  sellUncommonsBtn.MouseButton1Click:Connect(function()
    if rarityCounts["Uncommon"] > 0 then
      local inventory = getInventoryFunction:InvokeServer()
      if inventory then
        local totalValue = calculateRarityValue(inventory, "Uncommon")
        showSellConfirm("Uncommon", rarityCounts["Uncommon"], totalValue)
      end
    end
  end)
end

local sellRaresBtn = gui:FindFirstChild("SellRares")
if sellRaresBtn then
  sellRaresBtn.MouseButton1Click:Connect(function()
    if rarityCounts["Rare"] > 0 then
      local inventory = getInventoryFunction:InvokeServer()
      if inventory then
        local totalValue = calculateRarityValue(inventory, "Rare")
        showSellConfirm("Rare", rarityCounts["Rare"], totalValue)
      end
    end
  end)
end

local sellUltraRaresBtn = gui:FindFirstChild("SellUltraRares")
if sellUltraRaresBtn then
  sellUltraRaresBtn.MouseButton1Click:Connect(function()
    if rarityCounts["Ultra Rare"] > 0 then
      local inventory = getInventoryFunction:InvokeServer()
      if inventory then
        local totalValue = calculateRarityValue(inventory, "Ultra Rare")
        showSellConfirm("Ultra Rare", rarityCounts["Ultra Rare"], totalValue)
      end
    end
  end)
end

-- Marketplace sell functionality
local marketSellBtn = popup:FindFirstChild("MarketSellBtn")
local marketConfirm = script.Parent:FindFirstChild("MarketConfirm")

if marketSellBtn and marketConfirm then
  marketSellBtn.MouseButton1Click:Connect(function()
    if not selectedItemData then return end
    
    if selectedItemData.Value < 250000 then
      return
    end
    
    marketConfirm.Visible = true
    
    local pop = marketConfirm:FindFirstChild("Pop")
    if not pop then return end
    
    local itemInfo = pop:FindFirstChild("ItemInfo")
    if itemInfo then
      local itemPhoto = itemInfo:FindFirstChild("ItemPhoto")
      local itemName = itemInfo:FindFirstChild("ItemName")
      local itemValue = itemInfo:FindFirstChild("ItemValue")
      local itemSerial = itemInfo:FindFirstChild("ItemSerial")
      
      if itemPhoto then
        itemPhoto.Image = "rbxthumb://type=Asset&id=" .. selectedItemData.RobloxId .. "&w=150&h=150"
      end
      
      if itemName then
        itemName.Text = selectedItemData.Name
      end
      
      if itemValue then
        itemValue.Text = "R$ " .. formatNumber(selectedItemData.Value)
      end
      
      if itemSerial then
        if selectedItemData.SerialNumber then
          itemSerial.Visible = true
          itemSerial.Text = "#" .. selectedItemData.SerialNumber
        else
          itemSerial.Visible = false
        end
      end
    end
    
    local gamepassIdBox = pop:FindFirstChild("GamepassID")
    local cashAmountBox = pop:FindFirstChild("CashAmount")
    local sellPriceLabel = pop:FindFirstChild("SellPrice")
    
    if gamepassIdBox then gamepassIdBox.Text = "" end
    if cashAmountBox then cashAmountBox.Text = "" end
    if sellPriceLabel then sellPriceLabel.Text = "Enter cash amount or gamepass ID" end
  end)
  
  local pop = marketConfirm:FindFirstChild("Pop")
  if pop then
    local gamepassIdBox = pop:FindFirstChild("GamepassID")
    local cashAmountBox = pop:FindFirstChild("CashAmount")
    local sellPriceLabel = pop:FindFirstChild("SellPrice")
    local confirmBtn = pop:FindFirstChild("Confirm")
    local cancelBtn = pop:FindFirstChild("Cancel")
    
    local function updateSellPrice()
      if not gamepassIdBox or not cashAmountBox or not sellPriceLabel then return end
      
      local gamepassId = gamepassIdBox.Text
      local cashAmount = cashAmountBox.Text
      
      if gamepassId ~= "" and cashAmount ~= "" then
        sellPriceLabel.Text = "Error: Choose either cash OR gamepass, not both"
        sellPriceLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        return
      end
      
      if gamepassId ~= "" then
        local validGamepass, robuxPrice = validateGamepassFunction:InvokeServer(gamepassId)
        
        if validGamepass and robuxPrice > 0 then
          local sellerReceives = math.floor(robuxPrice * 0.70)
          sellPriceLabel.Text = "You will receive R$" .. formatNumber(sellerReceives) .. " upon sale (30% Tax)"
          sellPriceLabel.TextColor3 = Color3.fromRGB(111, 218, 40)
        else
          sellPriceLabel.Text = "Invalid gamepass ID"
          sellPriceLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
      elseif cashAmount ~= "" then
        local cash = tonumber(cashAmount)
        
        if cash and cash >= 1 and cash <= 1000000000 then
          sellPriceLabel.Text = "You will receive $" .. formatNumber(cash) .. " upon sale"
          sellPriceLabel.TextColor3 = Color3.fromRGB(111, 218, 40)
        else
          sellPriceLabel.Text = "Cash must be between $1 and $1,000,000,000"
          sellPriceLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
      else
        sellPriceLabel.Text = "Enter cash amount or gamepass ID"
        sellPriceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      end
    end
    
    if gamepassIdBox then
      gamepassIdBox:GetPropertyChangedSignal("Text"):Connect(updateSellPrice)
    end
    
    if cashAmountBox then
      cashAmountBox:GetPropertyChangedSignal("Text"):Connect(updateSellPrice)
    end
    
    if confirmBtn then
      confirmBtn.MouseButton1Click:Connect(function()
        if not selectedItemData then return end
        
        local gamepassId = gamepassIdBox and gamepassIdBox.Text or ""
        local cashAmount = cashAmountBox and cashAmountBox.Text or ""
        
        if gamepassId ~= "" and cashAmount ~= "" then
          return
        end
        
        if gamepassId ~= "" then
          createListingEvent:FireServer(selectedItemData, "robux", 0, gamepassId)
        elseif cashAmount ~= "" then
          local cash = tonumber(cashAmount)
          if cash and cash >= 1 and cash <= 1000000000 then
            createListingEvent:FireServer(selectedItemData, "cash", cash, nil)
          else
            return
          end
        else
          return
        end
        
        marketConfirm.Visible = false
        task.wait(0.2)
        pcall(refresh)
      end)
    end
    
    if cancelBtn then
      cancelBtn.MouseButton1Click:Connect(function()
        marketConfirm.Visible = false
      end)
    end
  end
end
