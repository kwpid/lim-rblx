local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

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

local frame = gui:WaitForChild("Frame", 5)
if not frame then
  warn("❌ Frame not found in InventorySystem GUI")
  return
end

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

function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

function refresh()
  local inventory
  local success, err = pcall(function()
    inventory = getInventoryFunction:InvokeServer()
  end)

  if not success or not inventory or type(inventory) ~= "table" then
    return
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

    -- Set rarity colors
    if contentFrame then
      local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
      contentFrame.BorderColor3 = rarityColor
    end
    if content2Frame then
      local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
      content2Frame.BorderColor3 = rarityColor
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

    -- Display copies (owners count) with stock info for stock items
    local copiesLabel = button:FindFirstChild("copies")
    if copiesLabel then
      local ownersCount = item.Owners or 0
      local stockCount = item.Stock or 0
      
      if ownersCount > 0 then
        if stockCount > 0 then
          -- Stock item: show "copies: X / Y exist"
          copiesLabel.Text = "copies: " .. ownersCount .. " / " .. stockCount .. " exist"
        else
          -- Regular item: show "copies: X"
          copiesLabel.Text = "copies: " .. ownersCount
        end
        copiesLabel.Visible = true
      else
        copiesLabel.Visible = false
      end
    end
    
    -- Also update o2 label (Sample.Content.o2) for owner count
    local o2Label = contentFrame and contentFrame:FindFirstChild("o2")
    if o2Label then
      local ownersCount = item.Owners or 0
      if item.Stock and item.Stock > 0 then
        -- Stock items show "owners/stock" format
        o2Label.Text = formatNumber(ownersCount) .. "/" .. formatNumber(item.Stock)
      else
        -- Regular items show just owners count
        o2Label.Text = formatNumber(ownersCount)
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
      local itemNameText = frame:WaitForChild("ItemName")
      local itemValueText = frame:WaitForChild("Value")
      local totalValueText = frame:FindFirstChild("TotalValue")
      local imgFrame = frame:WaitForChild("ImageLabel")

      itemNameText.Text = item.Name
      selected.Value = item.Name
      selectedItemData = item

      itemValueText.Text = "R$ " .. formatNumber(item.Value)

      -- Calculate total value
      if totalValueText then
        local totalValue = item.Value * (item.Amount or 1)
        totalValueText.Text = "Total: R$ " .. formatNumber(totalValue)
      end

      -- Clear previous image
      for _, child in ipairs(imgFrame:GetChildren()) do
        child:Destroy()
      end

      -- Show item preview
      local previewImg = Instance.new("ImageLabel")
      previewImg.Size = UDim2.new(1, 0, 1, 0)
      previewImg.BackgroundTransparency = 1
      previewImg.BorderSizePixel = 0
      previewImg.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=420&h=420"
      previewImg.Parent = imgFrame
      
      sellConfirmation = false
      sellAllConfirmation = false
      
      local equipButton = frame:FindFirstChild("Equip")
      if equipButton then
        if equippedItems[item.RobloxId] then
          equipButton.Text = "Unequip"
        else
          equipButton.Text = "Equip"
        end
      end
      
      local sellButton = frame:FindFirstChild("Sell")
      local sellAllButton = frame:FindFirstChild("SellAll")
      
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
    end)
  end
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

task.wait(1)
pcall(refresh)

local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
if inventoryUpdatedEvent then
  inventoryUpdatedEvent.OnClientEvent:Connect(function()
    pcall(refresh)
  end)
end

local equipButton = frame:FindFirstChild("Equip")
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

local sellButton = frame:FindFirstChild("Sell")
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

local sellAllButton = frame:FindFirstChild("SellAll")
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
