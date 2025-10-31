-- InventorySystem.lua
-- Client-side inventory display using DataStore data
-- LocalScript inside InventorySystem ScreenGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local gui = script.Parent
local buttons = {}

-- Get GUI elements
local handler = gui:WaitForChild("Handler")
local sample = script.Sample
local frame = gui:WaitForChild("Frame")
local searchBar = gui:FindFirstChild("SearchBar")

-- Ensure Selected value exists
local selected = handler:FindFirstChild("Selected")
if not selected then
  selected = Instance.new("StringValue")
  selected.Name = "Selected"
  selected.Parent = handler
end

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local getInventoryFunction = remoteEvents:WaitForChild("GetInventoryFunction")

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
  -- Get inventory from server
  local success, inventory = pcall(function()
    return getInventoryFunction:InvokeServer()
  end)

  if not success then
    warn("❌ Failed to get inventory from server: " .. tostring(inventory))
    warn("⚠️ Make sure Studio API Access is enabled in Game Settings!")
    return
  end

  if not inventory or type(inventory) ~= "table" then
    warn("❌ Invalid inventory data received")
    return
  end
  
  print("📦 Refreshing inventory: " .. #inventory .. " items")

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
    local button = sample:Clone()
    button.Name = item.Name
    button.LayoutOrder = i
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

    -- Display copies (owners count)
    local copiesLabel = button:FindFirstChild("copies")
    if copiesLabel then
      local ownersCount = item.Owners or 0
      if ownersCount > 0 then
        copiesLabel.Text = "copies: " .. ownersCount
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

    -- Click handler for item selection
    button.MouseButton1Click:Connect(function()
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
task.wait(1)  -- Wait for DataStore to load
local success, err = pcall(refresh)
if not success then
  warn("❌ Initial inventory refresh failed: " .. tostring(err))
end

-- Listen for inventory updates from server
local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
if inventoryUpdatedEvent then
  inventoryUpdatedEvent.OnClientEvent:Connect(function()
    local refreshSuccess, refreshErr = pcall(refresh)
    if not refreshSuccess then
      warn("❌ Inventory update failed: " .. tostring(refreshErr))
    end
  end)
end

print("✅ Inventory System loaded")
