local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local buttons = {}

local handler = gui:WaitForChild("Handler", 5)
if not handler then
  warn("❌ Handler not found in InventorySystem GUI")
  return
end

local sample = script:FindFirstChild("Sample")
if not sample then
  warn("❌ Sample template not found")
  return
end

-- Changed from "Frame" to "Popup"
local popup = gui:WaitForChild("Popup", 5)
if not popup then
  warn("❌ Popup not found in InventorySystem GUI")
  return
end

-- Set popup to invisible by default
popup.Visible = false

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
local equippedItems = {}
local sellConfirmation = false
local sellAllConfirmation = false

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
  warn("❌ RemoteEvents folder not found")
  return
end

local getInventoryFunction = remoteEvents:WaitForChild("GetInventoryFunction", 10)
if not getInventoryFunction then
  warn("❌ GetInventoryFunction not found")
  return
end

local equipItemEvent = remoteEvents:WaitForChild("EquipItemEvent", 10)
local sellItemEvent = remoteEvents:WaitForChild("SellItemEvent", 10)
local sellAllItemEvent = remoteEvents:WaitForChild("SellAllItemEvent", 10)
local getEquippedItemsFunction = remoteEvents:WaitForChild("GetEquippedItemsFunction", 10)

-- Rarity colors matching our 8-tier system (from ItemRarityModule)
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

-- Store the original popup position for animation
local popupOriginalPosition = popup.Position

function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

function showPopup()
  popup.Visible = true
  
  -- Start position (off-screen to the right)
  local startPos = UDim2.new(
    popupOriginalPosition.X.Scale + 0.5,
    popupOriginalPosition.X.Offset,
    popupOriginalPosition.Y.Scale,
    popupOriginalPosition.Y.Offset
  )
  
  popup.Position = startPos
  
  -- Tween to original position
  local tweenInfo = TweenInfo.new(
    0.3,
    Enum.EasingStyle.Quart,
    Enum.EasingDirection.Out
  )
  
  local tween = TweenService:Create(popup, tweenInfo, {Position = popupOriginalPosition})
  tween:Play()
end

function hidePopup()
  -- Tween out to the right
  local endPos = UDim2.new(
    popupOriginalPosition.X.Scale + 0.5,
    popupOriginalPosition.X.Offset,
    popupOriginalPosition.Y.Scale,
    popupOriginalPosition.Y.Offset
  )
  
  local tweenInfo = TweenInfo.new(
    0.2,
    Enum.EasingStyle.Quart,
    Enum.EasingDirection.In
  )
  
  local tween = TweenService:Create(popup, tweenInfo, {Position = endPos})
  tween:Play()
  
  tween.Completed:Connect(function()
    popup.Visible = false
  end)
end

function clearSelection()
  -- De-highlight the selected button
  if selectedButton then
    local contentFrame = selectedButton:FindFirstChild("Content")
    local content2Frame = selectedButton:FindFirstChild("content2")
    
    -- Get the item data from the button
    local itemRobloxId = selectedItemData and selectedItemData.RobloxId
    local isEquipped = itemRobloxId and equippedItems[itemRobloxId] or false
    
    -- Restore original border color
    if contentFrame then
      if isEquipped then
        contentFrame.BorderColor3 = Color3.fromRGB(255, 165, 0)
      else
        local itemRarity = selectedItemData and selectedItemData.Rarity
        local rarityColor = rarityColors[itemRarity] or Color3.new(1, 1, 1)
        contentFrame.BorderColor3 = rarityColor
      end
      -- Remove highlight effect
      contentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
    
    if content2Frame then
      if isEquipped then
        content2Frame.BorderColor3 = Color3.fromRGB(255, 165, 0)
      else
        local itemRarity = selectedItemData and selectedItemData.Rarity
        local rarityColor = rarityColors[itemRarity] or Color3.new(1, 1, 1)
        content2Frame.BorderColor3 = rarityColor
      end
      -- Remove highlight effect
      content2Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
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
    warn("⚠️ Failed to load inventory, will retry...")
    return false -- Return false to indicate failure
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

  -- Sort inventory: Equipped first, then by value (high to low)
  table.sort(inventory, function(a, b)
    local aEquipped = equippedItems[a.RobloxId] or false
    local bEquipped = equippedItems[b.RobloxId] or false

    if aEquipped ~= bEquipped then
      return aEquipped -- Equipped items come first
    end

    return a.Value > b.Value -- Then sort by value (highest to lowest)
  end)

  for i, item in ipairs(inventory) do
    local button = sample:Clone()
    button.Name = item.Name or "Item_" .. i
    button.LayoutOrder = i
    button.Visible = true
    button.Parent = handler

    local contentFrame = button:FindFirstChild("Content")
    local content2Frame = button:FindFirstChild("content2")

    local isEquipped = equippedItems[item.RobloxId] or false

    -- Set border colors (orange for equipped, rarity color for unequipped)
    if contentFrame then
      if isEquipped then
        contentFrame.BorderColor3 = Color3.fromRGB(255, 165, 0) -- Orange border for equipped
      else
        local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
        contentFrame.BorderColor3 = rarityColor
      end
    end
    if content2Frame then
      if isEquipped then
        content2Frame.BorderColor3 = Color3.fromRGB(255, 165, 0) -- Orange border for equipped
      else
        local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
        content2Frame.BorderColor3 = rarityColor
      end
    end

    -- Display quantity or serial number
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

    -- Display serial number in dedicated label (if stock item)
    local serialLabel = button:FindFirstChild("Serial")
    if serialLabel then
      if item.SerialNumber then
        serialLabel.Text = "#" .. item.SerialNumber
        serialLabel.Visible = true
      else
        serialLabel.Visible = false
      end
    end

    -- Display rarity (hide if Common)
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

    -- Hide t1 label if it doesn't exist on item
    local t1Label = button:FindFirstChild("t1")
    if t1Label then
      t1Label.Visible = false
    end

    -- Calculate the number of copies for rarity check
    local copiesCount = 0
    if item.Stock and item.Stock > 0 then
      -- Stock item: use CurrentStock (number of serials claimed)
      copiesCount = item.CurrentStock or 0
    else
      -- Regular item: use TotalCopies (total copies across all players)
      copiesCount = item.TotalCopies or 0
    end

    -- Show/hide RareText based on copies count (<= 25 = rare)
    local rareText = button:FindFirstChild("RareText")
    if rareText then
      if copiesCount > 0 and copiesCount <= 25 then
        rareText.Visible = true
      else
        rareText.Visible = false
      end
    end

    -- Show/hide LimText based on Limited status
    local limText = button:FindFirstChild("LimText")
    if limText then
      if item.Limited then
        limText.Visible = true
      else
        limText.Visible = false
      end
    end

    -- Display copies (stock items) or total copies (regular items)
    local copiesLabel = button:FindFirstChild("copies")
    if copiesLabel then
      local stockCount = item.Stock or 0

      if copiesCount > 0 then
        if stockCount > 0 then
          -- Stock item: show "X / Y copies" using CurrentStock
          copiesLabel.Text = copiesCount .. " / " .. stockCount .. " copies"
        else
          -- Regular item: show "X copies" using TotalCopies
          copiesLabel.Text = copiesCount .. " copies"
        end
        copiesLabel.Visible = true
      else
        copiesLabel.Visible = false
      end
    end

    -- Also update o2 label (Sample.Content.o2) to show copies count
    local o2Label = contentFrame and contentFrame:FindFirstChild("o2")
    if o2Label then
      if item.Stock and item.Stock > 0 then
        -- Stock items show "CurrentStock/Stock" format
        o2Label.Text = formatNumber(copiesCount) .. "/" .. formatNumber(item.Stock)
      else
        -- Regular items show just total copies count
        o2Label.Text = formatNumber(copiesCount)
      end
    end

    -- Display value
    local valueLabel = contentFrame and contentFrame:FindFirstChild("Value")
    if valueLabel then
      valueLabel.Text = "R$ " .. formatNumber(item.Value)
    end

    local v2Label = contentFrame and contentFrame:FindFirstChild("v2")
    if v2Label then
      v2Label.Text = formatNumber(item.Value)
    end

    -- Display name
    local nameLabel = content2Frame and content2Frame:FindFirstChild("name")
    if nameLabel then
      local displayName = item.Name
      if #displayName > 20 then
        displayName = string.sub(displayName, 1, 17) .. "..."
      end
      nameLabel.Text = displayName
    end

    -- Set item image using existing ImageLabel (Sample.Image)
    local img = button:FindFirstChild("Image")
    if img and img:IsA("ImageLabel") then
      img.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
    end

    table.insert(buttons, button)

    button.MouseButton1Click:Connect(function()
      -- Clear previous selection
      if selectedButton and selectedButton ~= button then
        local prevContentFrame = selectedButton:FindFirstChild("Content")
        local prevContent2Frame = selectedButton:FindFirstChild("content2")
        
        -- Remove highlight from previous button
        if prevContentFrame then
          prevContentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
        if prevContent2Frame then
          prevContent2Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
      end
      
      -- Highlight the selected button
      if contentFrame then
        contentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 150) -- Light yellow highlight
      end
      if content2Frame then
        content2Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 150) -- Light yellow highlight
      end
      
      selectedButton = button
      
      local itemNameText = popup:WaitForChild("ItemName")
      local itemValueText = popup:WaitForChild("Value")
      local totalValueText = popup:FindFirstChild("TotalValue")
      local imgFrame = popup:WaitForChild("ImageLabel")

      itemNameText.Text = item.Name
      selected.Value = item.Name
      selectedItemData = item

      itemValueText.Text = "R$ " .. formatNumber(item.Value)

      -- Calculate total value
      if totalValueText then
        local totalValue = item.Value * (item.Amount or 1)
        totalValueText.Text = "Total: R$ " .. formatNumber(totalValue)
      end

      -- Set the ImageLabel to show the selected item's image
      if imgFrame:IsA("ImageLabel") then
        -- If imgFrame itself is an ImageLabel, set its image directly
        imgFrame.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=420&h=420"
      else
        -- If imgFrame is a Frame containing an ImageLabel, update or create the image
        local existingImg = imgFrame:FindFirstChildOfClass("ImageLabel")
        
        if existingImg then
          -- Use existing ImageLabel
          existingImg.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=420&h=420"
        else
          -- Clear previous content and create new ImageLabel
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
      
      -- Show the popup with animation
      showPopup()
    end)
  end

  return true -- Return true to indicate successful load
end

-- Search bar functionality
if searchBar and searchBar:IsA("TextBox") then
  searchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local filterText = searchBar.Text:lower()
    for _, button in pairs(buttons) do
      local itemName = button.Name:lower()
      button.Visible = filterText == "" or itemName:find(filterText, 1, true) ~= nil
    end
  end)
end

-- Retry loading inventory with exponential backoff
local function loadInventoryWithRetry()
  local maxRetries = 10
  local retryDelay = 0.5

  for attempt = 1, maxRetries do
    task.wait(retryDelay)

    local success, result = pcall(refresh)
    -- Check both pcall success AND refresh return value
    if success and result == true then
      print("✅ Inventory loaded successfully on attempt " .. attempt)
      return
    end

    -- Exponential backoff: 0.5s, 1s, 2s, 4s, etc. (max 4s)
    retryDelay = math.min(retryDelay * 2, 4)
    warn(string.format("⏳ Inventory load attempt %d/%d failed, retrying in %.1fs...",
      attempt, maxRetries, retryDelay))
  end

  warn("❌ Failed to load inventory after " .. maxRetries .. " attempts")
end

task.spawn(loadInventoryWithRetry)

local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
if inventoryUpdatedEvent then
  inventoryUpdatedEvent.OnClientEvent:Connect(function()
    pcall(refresh)
  end)
end

-- Close button handler
local closeButton = popup:FindFirstChild("Close")
if closeButton then
  closeButton.MouseButton1Click:Connect(function()
    hidePopup()
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
