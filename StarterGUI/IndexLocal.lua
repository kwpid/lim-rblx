-- IndexLocal.lua
-- Displays all items in the game from ItemDatabase
-- LocalScript inside Index ScreenGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local items = {}
local buttons = {}

print("📋 Index System starting initialization...")

-- Rarity colors matching the 8-tier system
local rarityColors = {
  ["Common"] = Color3.fromRGB(170, 170, 170),      -- Gray
  ["Uncommon"] = Color3.fromRGB(85, 170, 85),      -- Green
  ["Rare"] = Color3.fromRGB(85, 85, 255),          -- Blue
  ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),   -- Purple
  ["Epic"] = Color3.fromRGB(255, 170, 0),          -- Orange
  ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),     -- Red-Orange
  ["Mythic"] = Color3.fromRGB(255, 0, 0),          -- Red
  ["Insane"] = Color3.fromRGB(255, 0, 255)         -- Magenta
}

-- Store connections to clean them up when refreshing
local itemConnections = {}

-- Wait for RemoteEvents
print("⏳ Waiting for RemoteEvents...")
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEventsFolder then
  warn("❌ INDEX ERROR: RemoteEvents folder not found in ReplicatedStorage!")
  return
end
print("✓ Found RemoteEvents")

local getAllItemsFunction = remoteEventsFolder:WaitForChild("GetAllItemsFunction", 10)
if not getAllItemsFunction then
  warn("❌ INDEX ERROR: GetAllItemsFunction not found in RemoteEvents!")
  warn("⚠️ Make sure ItemDatabase script has loaded on the server")
  return
end
print("✓ Found GetAllItemsFunction")

-- Listen for inventory updates to refresh owner counts
local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
if inventoryUpdatedEvent then
  inventoryUpdatedEvent.OnClientEvent:Connect(function()
    print("🔄 Inventory updated, refreshing index...")
    indexRefresh()
  end)
end

function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

-- Function to clean up old connections
function cleanupConnections()
  for _, connection in pairs(itemConnections) do
    if connection then
      connection:Disconnect()
    end
  end
  itemConnections = {}
end

function fetchItems()
  print("📡 Fetching all items from server...")
  
  local success, result = pcall(function()
    return getAllItemsFunction:InvokeServer()
  end)
  
  if not success then
    warn("❌ Failed to fetch items: " .. tostring(result))
    return {}
  end
  
  if not result or type(result) ~= "table" then
    warn("❌ Invalid response from server")
    return {}
  end
  
  print("✅ Fetched " .. #result .. " items from database")
  return result
end

function refresh()
  print("🔄 Refreshing index display...")
  
  -- Clean up old connections before refreshing
  cleanupConnections()
  
  -- Fetch items from server
  local allItems = fetchItems()
  
  if not allItems or #allItems == 0 then
    print("⚠️ No items to display")
    return
  end
  
  -- Sort by value (highest first), then by rarity, then by name
  table.sort(allItems, function(a, b)
    if a.Value ~= b.Value then
      return a.Value > b.Value
    end
    if a.Rarity ~= b.Rarity then
      -- Define rarity order for sorting
      local rarityOrder = {
        ["Insane"] = 8,
        ["Mythic"] = 7,
        ["Ultra Epic"] = 6,
        ["Epic"] = 5,
        ["Ultra Rare"] = 4,
        ["Rare"] = 3,
        ["Uncommon"] = 2,
        ["Common"] = 1
      }
      local aOrder = rarityOrder[a.Rarity] or 0
      local bOrder = rarityOrder[b.Rarity] or 0
      return aOrder > bOrder
    end
    return a.Name < b.Name
  end)
  
  -- Clear existing buttons
  for _, v in pairs(buttons) do
    v:Destroy()
  end
  buttons = {}
  
  -- Create buttons for each item
  for i, item in ipairs(allItems) do
    local button = script.Sample:Clone()
    button.Name = item.Name
    button.LayoutOrder = i
    button.Parent = script.Parent.Handler
    
    -- Find all the UI elements
    local contentFrame = button:FindFirstChild("Content")
    local content2Frame = button:FindFirstChild("content2")
    local rarityLabel = contentFrame and contentFrame:FindFirstChild("Rarity")
    local oLabel = contentFrame and contentFrame:FindFirstChild("o")
    local o2Label = contentFrame and contentFrame:FindFirstChild("o2")
    local vLabel = contentFrame and contentFrame:FindFirstChild("v")
    local v2Label = contentFrame and contentFrame:FindFirstChild("v2")
    local sLabel = contentFrame and contentFrame:FindFirstChild("s")
    local s2Label = contentFrame and contentFrame:FindFirstChild("s2")
    local nameLabel = content2Frame and content2Frame:FindFirstChild("name")
    
    -- Set text values
    if rarityLabel then
      rarityLabel.Text = item.Rarity
      rarityLabel.TextColor3 = rarityColors[item.Rarity] or Color3.fromRGB(255, 255, 255)
    end
    
    if o2Label then
      if item.Stock and item.Stock > 0 then
        -- Stock items show "owners/stock" format
        o2Label.Text = formatNumber(item.Owners) .. "/" .. formatNumber(item.Stock)
      else
        -- Regular items show just owners count
        o2Label.Text = formatNumber(item.Owners)
      end
    end
    
    if v2Label then
      v2Label.Text = formatNumber(item.Value)
    end
    
    if s2Label then
      if item.Stock and item.Stock > 0 then
        -- Show current stock / total stock
        s2Label.Text = formatNumber(item.CurrentStock) .. "/" .. formatNumber(item.Stock)
        if sLabel then sLabel.Visible = true end
        s2Label.Visible = true
      else
        -- Hide stock label for regular items
        if sLabel then sLabel.Visible = false end
        s2Label.Visible = false
      end
    end
    
    if nameLabel then
      -- Truncate name if longer than 20 characters
      if #item.Name > 20 then
        nameLabel.Text = string.sub(item.Name, 1, 17) .. "..."
      else
        nameLabel.Text = item.Name
      end
    end
    
    -- Add rare badge for low stock items
    local rareText = button:FindFirstChild("RareText")
    if rareText then
      if item.Stock and item.Stock > 0 then
        local remaining = item.Stock - item.CurrentStock
        if remaining <= 3 and remaining > 0 then
          rareText.Text = "✨"
          rareText.Visible = true
        elseif remaining <= 10 and remaining > 0 then
          rareText.Text = "💎"
          rareText.Visible = true
        else
          rareText.Visible = false
        end
      else
        rareText.Visible = false
      end
    end
    
    -- Set item image using existing Image element in Sample
    local img = button:FindFirstChild("Image")
    if img and img:IsA("ImageLabel") then
      img.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
    end
    
    table.insert(buttons, button)
  end
  
  print("✅ Displayed " .. #allItems .. " items")
end

-- Search bar functionality
local searchBar = script.Parent:FindFirstChild("SearchBar")
if searchBar and searchBar:IsA("TextBox") then
  searchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local filterText = searchBar.Text:lower()
    for _, button in pairs(buttons) do
      local itemName = button.Name:lower()
      button.Visible = filterText == "" or itemName:find(filterText, 1, true) ~= nil
    end
  end)
  print("✓ Search bar connected")
end

function indexRefresh()
  refresh()
end

-- Initial load
print("🚀 Starting initial index load...")
indexRefresh()

-- Refresh when new items are created
local createItemEvent = remoteEventsFolder:FindFirstChild("CreateItemEvent")
if createItemEvent then
  createItemEvent.OnClientEvent:Connect(function(success, message)
    if success then
      print("🔄 New item created, refreshing index...")
      task.wait(0.5) -- Wait for server to save
      indexRefresh()
    end
  end)
end

-- Clean up connections when the script is destroyed
script.AncestryChanged:Connect(function()
  if not script.Parent then
    cleanupConnections()
  end
end)

print("✅ Index System initialized successfully")
