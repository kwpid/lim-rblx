-- InventorySystem.lua
-- Client-side inventory display using DataStore data
-- LocalScript inside InventorySystem ScreenGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local gui = script.Parent
local buttons = {}

print("📋 Inventory System starting initialization...")

-- Get GUI elements
local handler = gui:WaitForChild("Handler", 5)
if not handler then
  warn("❌ INVENTORY ERROR: Handler not found in InventorySystem GUI!")
  return
end
print("✓ Found Handler")

local sample = script:FindFirstChild("Sample")
if not sample then
  warn("❌ INVENTORY ERROR: Sample template not found in InventorySystem script!")
  return
end
print("✓ Found Sample template")

local frame = gui:WaitForChild("Frame", 5)
if not frame then
  warn("❌ INVENTORY ERROR: Frame not found in InventorySystem GUI!")
  return
end
print("✓ Found Frame")

local searchBar = gui:FindFirstChild("SearchBar")
if searchBar then
  print("✓ Found SearchBar")
else
  print("⚠️ SearchBar not found (optional)")
end

-- Ensure Selected value exists (create as StringValue if needed)
local selected = handler:FindFirstChild("Selected")
if not selected then
  selected = Instance.new("StringValue")
  selected.Name = "Selected"
  selected.Parent = handler
  print("✓ Created Selected StringValue")
elseif not selected:IsA("StringValue") then
  -- If it exists but is wrong type (like ObjectValue), replace it
  warn("⚠️ Selected was wrong type (" .. selected.ClassName .. "), replacing with StringValue")
  selected:Destroy()
  selected = Instance.new("StringValue")
  selected.Name = "Selected"
  selected.Parent = handler
  print("✓ Created new Selected StringValue")
else
  print("✓ Found Selected StringValue")
end

-- Wait for RemoteEvents
print("⏳ Waiting for RemoteEvents...")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
  warn("❌ INVENTORY ERROR: RemoteEvents folder not found in ReplicatedStorage!")
  return
end
print("✓ Found RemoteEvents")

local getInventoryFunction = remoteEvents:WaitForChild("GetInventoryFunction", 10)
if not getInventoryFunction then
  warn("❌ INVENTORY ERROR: GetInventoryFunction not found in RemoteEvents!")
  warn("⚠️ Make sure PlayerDataHandler script has loaded on the server")
  return
end
print("✓ Found GetInventoryFunction")

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
  print("🔄 Starting inventory refresh...")
  
  -- Get inventory from server
  print("📡 Calling GetInventoryFunction:InvokeServer()...")
  
  local inventory
  local success, err = pcall(function()
    inventory = getInventoryFunction:InvokeServer()
  end)

  if not success then
    warn("❌ InvokeServer failed with error: " .. tostring(err))
    warn("⚠️ This usually means the server function errored or timed out")
    return
  end

  print("✓ InvokeServer completed successfully")

  if not inventory then
    warn("❌ Inventory is nil!")
    return
  end

  if type(inventory) ~= "table" then
    warn("❌ Invalid inventory data type: " .. type(inventory))
    return
  end
  
  print("📦 Refreshing inventory: " .. #inventory .. " items")
  
  if #inventory == 0 then
    print("⚠️ Inventory is empty (no items to display)")
  end

  -- Clear existing buttons
  for _, button in pairs(buttons) do
    button:Destroy()
  end
  buttons = {}

  -- Sort inventory by value (descending)
  table.sort(inventory, function(a, b)
    return a.Value > b.Value
  end)

  for i, item in ipairs(inventory) do
    print("🔨 Creating button for item " .. i .. ": " .. (item.Name or "Unknown"))
    
    local button = sample:Clone()
    button.Name = item.Name or "Item_" .. i
    button.LayoutOrder = i
    button.Visible = true
    button.Parent = handler
    
    print("✓ Button created and parented to Handler")

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
    print("✓ Item button fully configured: " .. item.Name)

    -- Click handler for item selection
    button.MouseButton1Click:Connect(function()
      print("🖱️ Clicked item: " .. item.Name)
      local itemNameText = frame:WaitForChild("ItemName")
      local itemValueText = frame:WaitForChild("Value")
      local totalValueText = frame:FindFirstChild("TotalValue")
      local imgFrame = frame:WaitForChild("ImageLabel")

      -- Update selected item display
      itemNameText.Text = item.Name
      selected.Value = item.Name

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
    end)
  end
  
  print("✅ Inventory refresh complete! " .. #buttons .. " buttons created")
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

-- Initial refresh
print("⏳ Waiting 1 second for DataStore to load...")
task.wait(1)
print("🚀 Starting initial inventory refresh...")
local success, err = pcall(refresh)
if not success then
  warn("❌ Initial inventory refresh failed: " .. tostring(err))
  warn("Stack trace: " .. debug.traceback())
else
  print("✅ Initial inventory refresh completed successfully")
end

-- Listen for inventory updates from server
local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
if inventoryUpdatedEvent then
  print("✓ Found InventoryUpdatedEvent, connecting listener")
  inventoryUpdatedEvent.OnClientEvent:Connect(function()
    print("📬 Received inventory update event from server")
    local refreshSuccess, refreshErr = pcall(refresh)
    if not refreshSuccess then
      warn("❌ Inventory update failed: " .. tostring(refreshErr))
    end
  end)
else
  warn("⚠️ InventoryUpdatedEvent not found (inventory won't auto-update)")
end

print("✅ Inventory System fully loaded and ready!")
