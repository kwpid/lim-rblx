-- DataStoreManager.lua
-- Handles all data storage operations for player data

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

local DataStoreManager = {}

-- Default data structure for new players
local DEFAULT_DATA = {
  Inventory = {},  -- Will store item data as table
  CasesOpened = 0,
  Cash = 0,
  InvValue = 0  -- Total inventory value
}

-- Save player data
function DataStoreManager:SaveData(player, data)
  local success, errorMessage = pcall(function()
    local jsonData = HttpService:JSONEncode(data)
    PlayerDataStore:SetAsync("Player_" .. player.UserId, jsonData)
  end)

  if success then
    print("✅ Successfully saved data for " .. player.Name)
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
      print("📂 Loaded existing data for " .. player.Name)
    else
      -- New player, use default data
      data = self:GetDefaultData()
      print("🆕 Created new data for " .. player.Name)
    end
  end)

  if success then
    return data
  else
    warn("❌ Failed to load data for " .. player.Name .. ": " .. errorMessage)
    -- Return default data on error to prevent data loss
    return self:GetDefaultData()
  end
end

-- Get a copy of default data
function DataStoreManager:GetDefaultData()
  local defaultCopy = {
    Inventory = {},
    CasesOpened = 0,
    Cash = 0,
    InvValue = 0
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
