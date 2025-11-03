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
  AutoRoll = false,
  TradeHistory = {},
  DataVersion = DATA_VERSION
}

function DataStoreManager:SaveData(player, data)
  local success, errorMessage = pcall(function()
    local jsonData = HttpService:JSONEncode(data)
    PlayerDataStore:SetAsync("Player_" .. player.UserId, jsonData)
  end)

  if not success then
    warn("failed to save data for " .. player.Name .. ": " .. errorMessage)
    return false
  end

  return true
end

function DataStoreManager:LoadData(player)
  local data = nil
  local success, errorMessage = pcall(function()
    local jsonData = PlayerDataStore:GetAsync("Player_" .. player.UserId)

    if jsonData then
      data = HttpService:JSONDecode(jsonData)
    else
      data = self:GetDefaultData()
    end
  end)

  if not success then
    warn("datastore error for " .. player.Name .. ": " .. tostring(errorMessage))
    warn("solution: enable studio api access in game settings > security > studio access to api services")
    warn("without api access, leaderstats and inventory will not work properly")
    return self:GetDefaultData()
  end

  if not data or type(data) ~= "table" then
    warn("invalid data structure loaded for " .. player.Name)
    return self:GetDefaultData()
  end

  if not data.Inventory then data.Inventory = {} end
  if not data.Rolls then data.Rolls = 0 end
  if not data.Cash then data.Cash = 0 end
  if not data.InvValue then data.InvValue = 0 end
  if not data.EquippedItems then data.EquippedItems = {} end
  if data.AutoRoll == nil then data.AutoRoll = false end
  if not data.TradeHistory then data.TradeHistory = {} end
  data.DataVersion = DATA_VERSION

  return data
end

function DataStoreManager:GetDefaultData()
  return {
    Inventory = {},
    Rolls = 0,
    Cash = 0,
    InvValue = 0,
    EquippedItems = {},
    AutoRoll = false,
    TradeHistory = {},
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
