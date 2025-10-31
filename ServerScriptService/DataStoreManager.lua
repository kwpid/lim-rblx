-- DataStoreManager.lua
-- Handles all data storage operations for player data

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- 🔑 DATA VERSION - Change this to wipe all player data (e.g., "DataVersion.11")
local DATA_VERSION = "DataVersion.13"

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

local DataStoreManager = {}

-- Default data structure for new players
local DEFAULT_DATA = {
  Inventory = {}, -- Will store item data as table
  CasesOpened = 0,
  Cash = 0,
  InvValue = 0,       -- Total inventory value
  EquippedItems = {}, -- Array of RobloxIds of equipped items
  DataVersion = DATA_VERSION
}

-- Save player data
function DataStoreManager:SaveData(player, data)
  local success, errorMessage = pcall(function()
    local jsonData = HttpService:JSONEncode(data)
    PlayerDataStore:SetAsync("Player_" .. player.UserId, jsonData)
  end)

  if success then
    print("Successfully saved data for " .. player.Name)
    return true
  else
    warn("❌ Failed to save data for " .. player.Name .. ": " .. errorMessage)
    return false
  end
end

-- Load player data
function DataStoreManager:LoadData(player)
  local data = nil
  local success, errorMessage = pcall(function()
    local jsonData = PlayerDataStore:GetAsync("Player_" .. player.UserId)

    if jsonData then
      -- Decode JSON string back to table
      data = HttpService:JSONDecode(jsonData)

      -- Check if data version matches current version
      if data.DataVersion ~= DATA_VERSION then
        data = self:GetDefaultData()
      else
      end
    else
      -- New player, use default data
      data = self:GetDefaultData()
    end
  end)

  if not success then
    warn("❌ DataStore Error for " .. player.Name .. ": " .. tostring(errorMessage))
    warn("⚠️ SOLUTION: Enable Studio API Access in Game Settings > Security > Studio Access to API Services")
    warn("⚠️ Without API access, leaderstats and inventory will not work properly!")
    -- Return default data on error to prevent data loss
    return self:GetDefaultData()
  end

  -- Validate data structure
  if not data or type(data) ~= "table" then
    warn("❌ Invalid data structure loaded for " .. player.Name)
    return self:GetDefaultData()
  end

  -- Ensure all required fields exist
  if not data.Inventory then data.Inventory = {} end
  if not data.CasesOpened then data.CasesOpened = 0 end
  if not data.Cash then data.Cash = 0 end
  if not data.InvValue then data.InvValue = 0 end
  if not data.EquippedItems then data.EquippedItems = {} end
  if not data.DataVersion then data.DataVersion = DATA_VERSION end

  return data
end

-- Get a copy of default data
function DataStoreManager:GetDefaultData()
  local defaultCopy = {
    Inventory = {},
    CasesOpened = 0,
    Cash = 0,
    InvValue = 0,
    EquippedItems = {},
    DataVersion = DATA_VERSION
  }
  return defaultCopy
end

-- Add item to player's inventory
function DataStoreManager:AddItemToInventory(playerData, itemData)
  table.insert(playerData.Inventory, itemData)
end

-- Remove item from inventory by index
function DataStoreManager:RemoveItemFromInventory(playerData, index)
  if playerData.Inventory[index] then
    table.remove(playerData.Inventory, index)
    return true
  end
  return false
end

-- Add cash to player
function DataStoreManager:AddCash(playerData, amount)
  playerData.Cash += amount
end

-- Increment cases opened
function DataStoreManager:IncrementCasesOpened(playerData)
  playerData.CasesOpened += 1
end

-- Set inventory value
function DataStoreManager:SetInvValue(playerData, value)
  playerData.InvValue = value
end

return DataStoreManager
