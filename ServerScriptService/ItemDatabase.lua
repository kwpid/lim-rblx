-- ItemDatabase.lua
-- Manages the global item database (all available items in the game)

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ItemDataStore = DataStoreService:GetDataStore("ItemDatabase_v1")
local ItemRarityModule = require(game.ReplicatedStorage.ItemRarityModule)

local ItemDatabase = {}
ItemDatabase.Items = {}

-- Load all items from DataStore
function ItemDatabase:LoadItems()
  local success, result = pcall(function()
    local jsonData = ItemDataStore:GetAsync("AllItems")
    if jsonData then
      self.Items = HttpService:JSONDecode(jsonData)

      -- Migrate legacy items (add Stock/CurrentStock/Owners if missing)
      for _, item in ipairs(self.Items) do
        if item.Stock == nil then
          item.Stock = 0
        end
        if item.CurrentStock == nil then
          item.CurrentStock = 0
        end
        if item.Owners == nil then
          item.Owners = 0
        end
      end

      print("📚 Loaded " .. #self.Items .. " items from database")
    else
      self.Items = {}
      print("📚 No items found, starting with empty database")
    end
  end)

  if not success then
    warn("❌ Failed to load items: " .. tostring(result))
    self.Items = {}
  end
end

-- Save all items to DataStore
function ItemDatabase:SaveItems()
  local success, errorMessage = pcall(function()
    local jsonData = HttpService:JSONEncode(self.Items)
    ItemDataStore:SetAsync("AllItems", jsonData)
  end)

  if success then
    print("✅ Saved " .. #self.Items .. " items to database")
    return true
  else
    warn("❌ Failed to save items: " .. errorMessage)
    return false
  end
end

-- Add a new item to the database
function ItemDatabase:AddItem(robloxId, itemName, itemValue, stock)
  -- Validate inputs
  if type(robloxId) ~= "number" then
    return false, "RobloxId must be a number"
  end

  if type(itemName) ~= "string" or itemName == "" then
    return false, "Item name cannot be empty"
  end

  if type(itemValue) ~= "number" or itemValue < 0 then
    return false, "Item value must be a positive number"
  end

  -- Validate stock (optional, 0 or nil = regular item, 1-100 = stock item)
  stock = stock or 0
  if type(stock) ~= "number" or stock < 0 or stock > 100 then
    return false, "Stock must be between 0 and 100"
  end

  -- Check if item already exists
  for _, item in ipairs(self.Items) do
    if item.RobloxId == robloxId then
      return false, "Item with this Roblox ID already exists"
    end
  end

  -- Get rarity from value
  local rarity = ItemRarityModule:GetRarity(itemValue)

  -- Create item
  local newItem = {
    RobloxId = robloxId,
    Name = itemName,
    Value = itemValue,
    Rarity = rarity,
    Stock = stock,  -- 0 = regular, 1-100 = stock item
    CurrentStock = 0,  -- How many have been rolled (starts at 0)
    Owners = 0,  -- How many players own this item
    CreatedAt = os.time()
  }

  table.insert(self.Items, newItem)

  -- Save to DataStore
  local saveSuccess = self:SaveItems()

  if saveSuccess then
    local stockText = stock > 0 and " [Stock: " .. stock .. "]" or ""
    print("✨ Added new item: " .. itemName .. " (" .. rarity .. ")" .. stockText)
    return true, newItem
  else
    -- Remove from memory if save failed
    table.remove(self.Items, #self.Items)
    return false, "Failed to save item to database"
  end
end

-- Get all items (only rollable ones - exclude sold out stock items)
function ItemDatabase:GetAllItems()
  return self.Items
end

-- Get all rollable items (exclude sold out stock items)
function ItemDatabase:GetRollableItems()
  local rollableItems = {}
  for _, item in ipairs(self.Items) do
    -- Default to 0 if nil (legacy data)
    local stock = item.Stock or 0
    local currentStock = item.CurrentStock or 0

    -- Include regular items (Stock = 0) or stock items that aren't sold out
    if stock == 0 or currentStock < stock then
      table.insert(rollableItems, item)
    end
  end
  return rollableItems
end

-- Increment stock for an item (when someone rolls it)
-- Returns serial number on success, nil if sold out or not a stock item
function ItemDatabase:IncrementStock(item)
  -- Default to 0 if nil (legacy data)
  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0

  if stock > 0 and currentStock < stock then
    item.CurrentStock = currentStock + 1
    self:SaveItems()
    return item.CurrentStock  -- Return the serial number
  end
  return nil
end

-- Check if item is sold out
function ItemDatabase:IsSoldOut(item)
  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0
  return stock > 0 and currentStock >= stock
end

-- Get item by Roblox ID
function ItemDatabase:GetItemByRobloxId(robloxId)
  for _, item in ipairs(self.Items) do
    if item.RobloxId == robloxId then
      return item
    end
  end
  return nil
end

-- Increment owners count for an item
function ItemDatabase:IncrementOwners(robloxId)
  local item = self:GetItemByRobloxId(robloxId)
  if item then
    item.Owners = (item.Owners or 0) + 1
    self:SaveItems()
    return item.Owners
  end
  return nil
end

-- Get owners count for an item
function ItemDatabase:GetOwners(robloxId)
  local item = self:GetItemByRobloxId(robloxId)
  if item then
    return item.Owners or 0
  end
  return 0
end

-- Initialize database
ItemDatabase:LoadItems()

return ItemDatabase
