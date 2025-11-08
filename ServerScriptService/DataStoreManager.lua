local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- MATCH THIS WITH ITEM DATABASE!
local DATA_VERSION = "DataVersion.30"

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local DataStoreManager = {}

local DEFAULT_DATA = {
  Inventory = {},
  Rolls = 0,
  Cash = 0,
  InvValue = 0,
  EquippedItems = {},
  LockedItems = {},
  AutoRoll = false,
  TradeHistory = {},
  PendingNotifications = {},
  DataVersion = DATA_VERSION
}

function DataStoreManager:SaveData(player, data)
  local MAX_RETRIES = 3
  local RETRY_DELAY = 1
  
  for attempt = 1, MAX_RETRIES do
    local success, errorMessage = pcall(function()
      local jsonData = HttpService:JSONEncode(data)
      PlayerDataStore:SetAsync("Player_" .. player.UserId, jsonData)
    end)

    if success then
      return true
    else
      warn("failed to save data for " .. player.Name .. " (attempt " .. attempt .. "/" .. MAX_RETRIES .. "): " .. errorMessage)
      
      if attempt < MAX_RETRIES then
        task.wait(RETRY_DELAY * attempt)
      else
        warn("⚠️ CRITICAL: Failed to save data for " .. player.Name .. " after " .. MAX_RETRIES .. " attempts!")
        warn("⚠️ Player data may be lost on server restart/leave!")
      end
    end
  end

  return false
end

function DataStoreManager:LoadData(player)
  local MAX_RETRIES = 3
  local RETRY_DELAY = 1
  
  for attempt = 1, MAX_RETRIES do
    local data = nil
    local success, errorMessage = pcall(function()
      local jsonData = PlayerDataStore:GetAsync("Player_" .. player.UserId)

      if jsonData then
        data = HttpService:JSONDecode(jsonData)
      else
        data = self:GetDefaultData()
      end
    end)

    if success then
      if not data or type(data) ~= "table" then
        warn("invalid data structure loaded for " .. player.Name)
        return self:GetDefaultData()
      end

      if not data.Inventory then data.Inventory = {} end
      if not data.Rolls then data.Rolls = 0 end
      if not data.Cash then data.Cash = 0 end
      if not data.InvValue then data.InvValue = 0 end
      if not data.EquippedItems then data.EquippedItems = {} end
      if not data.LockedItems then data.LockedItems = {} end
      if data.AutoRoll == nil then data.AutoRoll = false end
      if not data.TradeHistory then data.TradeHistory = {} end
      if not data.PendingNotifications then data.PendingNotifications = {} end
      data.DataVersion = DATA_VERSION

      return data
    else
      warn("datastore error for " .. player.Name .. " (attempt " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(errorMessage))
      
      if attempt == MAX_RETRIES then
        warn("⚠️ CRITICAL: Failed to load data after " .. MAX_RETRIES .. " attempts")
        warn("solution: enable studio api access in game settings > security > studio access to api services")
        warn("without api access, leaderstats and inventory will not work properly")
        warn("⚠️ Using default data to prevent complete failure - player may lose progress!")
        return self:GetDefaultData()
      else
        task.wait(RETRY_DELAY * attempt)
      end
    end
  end
  
  return self:GetDefaultData()
end

function DataStoreManager:GetDefaultData()
  return {
    Inventory = {},
    Rolls = 0,
    Cash = 0,
    InvValue = 0,
    EquippedItems = {},
    LockedItems = {},
    AutoRoll = false,
    TradeHistory = {},
    PendingNotifications = {},
    DataVersion = DATA_VERSION
  }
end

function DataStoreManager:AddItemToInventory(playerData, itemData)
  table.insert(playerData.Inventory, itemData)
end

function DataStoreManager:RemoveItemFromInventory(playerData, index)
  if playerData.Inventory[index] then
    table.remove(playerData.Inventory, index)
    return true
  end
  return false
end

function DataStoreManager:AddCash(playerData, amount)
  playerData.Cash = playerData.Cash + amount
end

function DataStoreManager:IncrementRolls(playerData)
  playerData.Rolls = playerData.Rolls + 1
end

function DataStoreManager:SetInvValue(playerData, value)
  playerData.InvValue = value
end

return DataStoreManager
