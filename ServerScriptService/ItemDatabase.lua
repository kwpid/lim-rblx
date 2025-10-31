-- ItemDatabase.lua
-- Manages the global item database (all available items in the game)

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ItemDataStore = DataStoreService:GetDataStore("ItemDatabase_v1")
local ItemRarityModule = require(game.ReplicatedStorage.ItemRarityModule)

-- 🔑 DATA VERSION - Must match DataStoreManager.lua to keep data in sync
local DATA_VERSION = "DataVersion.15"

local ItemDatabase = {}
ItemDatabase.Items = {}
ItemDatabase.DataVersion = DATA_VERSION

-- Load all items from DataStore
function ItemDatabase:LoadItems()
  local success, result = pcall(function()
    local jsonData = ItemDataStore:GetAsync("AllItems")
    if jsonData then
      local data = HttpService:JSONDecode(jsonData)

      -- Check if this is old format (just array) or new format (with version)
      local items
      local savedVersion

      if data.Items then
        -- New format with version
        items = data.Items
        savedVersion = data.DataVersion
      else
        -- Old format (just array of items)
        items = data
        savedVersion = nil
      end

      self.Items = items

      -- Check if data version matches
      if savedVersion ~= DATA_VERSION then
        -- Reset stock and owners for all items
        for _, item in ipairs(self.Items) do
          item.CurrentStock = 0
          item.Owners = 0
        end

        -- Save with new version
        self.DataVersion = DATA_VERSION
        self:SaveItems()
      else
        self.DataVersion = savedVersion
      end

      -- Migrate legacy items (add Stock/CurrentStock/Owners/SerialOwners if missing)
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
        if item.SerialOwners == nil then
          item.SerialOwners = {}
        end
      end
    else
      self.Items = {}
      self.DataVersion = DATA_VERSION
    end
  end)

  if not success then
    warn("❌ Failed to load items: " .. tostring(result))
    self.Items = {}
    self.DataVersion = DATA_VERSION
  end
end

-- Save all items to DataStore
function ItemDatabase:SaveItems()
  local success, errorMessage = pcall(function()
    -- Save with data version
    local dataToSave = {
      Items = self.Items,
      DataVersion = self.DataVersion or DATA_VERSION
    }
    local jsonData = HttpService:JSONEncode(dataToSave)
    ItemDataStore:SetAsync("AllItems", jsonData)
  end)

  if success then
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
    Stock = stock,     -- 0 = regular, 1-100 = stock item
    CurrentStock = 0,  -- How many have been rolled (starts at 0)
    Owners = 0,        -- How many players own this item
    SerialOwners = {}, -- Array of {UserId, SerialNumber, Username} for stock items
    CreatedAt = os.time()
  }

  table.insert(self.Items, newItem)

  -- Save to DataStore
  local saveSuccess = self:SaveItems()

  if saveSuccess then
    local stockText = stock > 0 and " [Stock: " .. stock .. "]" or ""

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
    return item.CurrentStock -- Return the serial number
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
  -- Convert to number to handle both string and number inputs
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:GetItemByRobloxId - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  for _, item in ipairs(self.Items) do
    if item.RobloxId == numericId then
      return item
    end
  end

  warn("⚠️ ItemDatabase:GetItemByRobloxId - No item found with RobloxId: " .. numericId)
  return nil
end

-- Increment owners count for an item
function ItemDatabase:IncrementOwners(robloxId)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:IncrementOwners - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if item then
    local oldOwners = item.Owners or 0
    item.Owners = oldOwners + 1
    self:SaveItems()
    return item.Owners
  else
    return nil
  end
end

-- Get owners count for an item
function ItemDatabase:GetOwners(robloxId)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:GetOwners - Invalid RobloxId: " .. tostring(robloxId))
    return 0
  end

  local item = self:GetItemByRobloxId(numericId)
  if item then
    return item.Owners or 0
  end
  return 0
end

-- Decrement owners count for an item (when a player sells/removes it)
function ItemDatabase:DecrementOwners(robloxId)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:DecrementOwners - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if item then
    local oldOwners = item.Owners or 0
    item.Owners = math.max(0, oldOwners - 1) -- Don't go below 0
    self:SaveItems()

    return item.Owners
  else
    warn("❌ ItemDatabase:DecrementOwners - Item not found for RobloxId: " .. numericId)
    return nil
  end
end

-- Decrement stock for an item (when someone sells a stock item)
-- Returns true on success, nil if not a stock item or already at 0
function ItemDatabase:DecrementStock(robloxId)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:DecrementStock - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:DecrementStock - Item not found for RobloxId: " .. numericId)
    return nil
  end

  -- Default to 0 if nil (legacy data)
  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0

  if stock > 0 and currentStock > 0 then
    item.CurrentStock = currentStock - 1
    self:SaveItems()
    return true
  end

  return nil
end

-- Increase stock limit for an item (when admin gives a sold-out stock item)
-- Increases both Stock and CurrentStock by 1, returns the new serial number
function ItemDatabase:IncreaseStockLimit(robloxId, userId, username)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:IncreaseStockLimit - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:IncreaseStockLimit - Item not found for RobloxId: " .. numericId)
    return nil
  end

  -- Default to 0 if nil (legacy data)
  local stock = item.Stock or 0

  if stock > 0 then
    -- Increase stock limit by 1
    item.Stock = stock + 1
    item.CurrentStock = (item.CurrentStock or 0) + 1

    -- Record the owner of this new serial
    if userId and username then
      if not item.SerialOwners then
        item.SerialOwners = {}
      end
      table.insert(item.SerialOwners, {
        UserId = userId,
        SerialNumber = item.CurrentStock,
        Username = username
      })
    end

    self:SaveItems()
    print("📈 Increased stock limit for " .. item.Name .. " from " .. stock .. " to " .. item.Stock)
    return item.CurrentStock -- Return the new serial number
  end

  return nil
end

-- Record owner for a serial number (when stock item is claimed)
function ItemDatabase:RecordSerialOwner(robloxId, userId, username, serialNumber)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:RecordSerialOwner - Invalid RobloxId: " .. tostring(robloxId))
    return false
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:RecordSerialOwner - Item not found for RobloxId: " .. numericId)
    return false
  end

  -- Initialize SerialOwners if it doesn't exist
  if not item.SerialOwners then
    item.SerialOwners = {}
  end

  -- Check if this serial number is already recorded
  for _, owner in ipairs(item.SerialOwners) do
    if owner.SerialNumber == serialNumber then
      -- Serial already recorded, update if needed
      owner.UserId = userId
      owner.Username = username
      self:SaveItems()
      return true
    end
  end

  -- Add new serial owner record
  table.insert(item.SerialOwners, {
    UserId = userId,
    SerialNumber = serialNumber,
    Username = username
  })

  self:SaveItems()
  return true
end

-- Get all owners of a stock item (sorted by serial number)
function ItemDatabase:GetSerialOwners(robloxId)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:GetSerialOwners - Invalid RobloxId: " .. tostring(robloxId))
    return {}
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:GetSerialOwners - Item not found for RobloxId: " .. numericId)
    return {}
  end

  -- Return empty if not a stock item or no owners
  if not item.SerialOwners or #item.SerialOwners == 0 then
    return {}
  end

  -- Sort by serial number (lowest first)
  local sorted = {}
  for _, owner in ipairs(item.SerialOwners) do
    table.insert(sorted, {
      UserId = owner.UserId,
      SerialNumber = owner.SerialNumber,
      Username = owner.Username
    })
  end

  table.sort(sorted, function(a, b)
    return a.SerialNumber < b.SerialNumber
  end)

  return sorted
end

-- Delete an item from the database
-- Returns success (true/false), message, itemData (deleted item info)
function ItemDatabase:DeleteItem(robloxId)
  -- Convert to number to ensure proper lookup
  local numericId = tonumber(robloxId)
  if not numericId then
    return false, "Invalid RobloxId: " .. tostring(robloxId), nil
  end

  -- Find the item index
  local itemIndex = nil
  local itemData = nil
  for i, item in ipairs(self.Items) do
    if item.RobloxId == numericId then
      itemIndex = i
      itemData = item
      break
    end
  end

  if not itemIndex then
    return false, "Item with ID " .. numericId .. " does not exist", nil
  end

  -- Remove item from database
  table.remove(self.Items, itemIndex)

  -- Save to DataStore
  local saveSuccess = self:SaveItems()

  if saveSuccess then
    print("🗑️ Deleted item: " .. itemData.Name .. " (RobloxId: " .. numericId .. ")")
    return true, "Item deleted successfully", itemData
  else
    -- Restore item if save failed (failsafe)
    table.insert(self.Items, itemIndex, itemData)
    return false, "Failed to save deletion to database", nil
  end
end

-- Initialize database
ItemDatabase:LoadItems()

-- Set up RemoteFunction for clients to get all items
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents folder if it doesn't exist
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
end

-- Create RemoteFunction if it doesn't exist
local getAllItemsFunction = remoteEventsFolder:FindFirstChild("GetAllItemsFunction")
if not getAllItemsFunction then
  getAllItemsFunction = Instance.new("RemoteFunction")
  getAllItemsFunction.Name = "GetAllItemsFunction"
  getAllItemsFunction.Parent = remoteEventsFolder
end

-- Set up the function to return all items to clients
getAllItemsFunction.OnServerInvoke = function(player)
  -- Return a copy of all items
  local itemsCopy = {}
  for i, item in ipairs(ItemDatabase.Items) do
    itemsCopy[i] = {
      RobloxId = item.RobloxId,
      Name = item.Name,
      Value = item.Value,
      Rarity = item.Rarity,
      Stock = item.Stock or 0,
      CurrentStock = item.CurrentStock or 0,
      Owners = item.Owners or 0,
      CreatedAt = item.CreatedAt
    }
  end

  return itemsCopy
end

-- Create RemoteFunction for getting item owners
local getItemOwnersFunction = remoteEventsFolder:FindFirstChild("GetItemOwnersFunction")
if not getItemOwnersFunction then
  getItemOwnersFunction = Instance.new("RemoteFunction")
  getItemOwnersFunction.Name = "GetItemOwnersFunction"
  getItemOwnersFunction.Parent = remoteEventsFolder
end

-- Set up the function to return item owners to clients
getItemOwnersFunction.OnServerInvoke = function(player, robloxId)
  return ItemDatabase:GetSerialOwners(robloxId)
end

return ItemDatabase
