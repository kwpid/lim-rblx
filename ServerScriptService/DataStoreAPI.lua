-- DataStoreAPI.lua
-- Public API for other scripts to interact with player data
-- Use this module from other server scripts to modify player data

local DataStoreManager = require(script.Parent.DataStoreManager)
local ItemDatabase = require(script.Parent.ItemDatabase)

local DataStoreAPI = {}

-- Get player's data
function DataStoreAPI:GetPlayerData(player)
  return _G.PlayerData[player.UserId]
end

-- Add item to player's inventory
-- itemData should include: {RobloxId, Name, Value, Rarity, SerialNumber (optional)}
function DataStoreAPI:AddItem(player, itemData)
  local data = self:GetPlayerData(player)
  if not data then
    return false
  end

  local isNewOwner = false

  -- Check if this is a stock item (has SerialNumber) or regular item
  if itemData.SerialNumber then
    -- Stock item - add as unique item with serial number
    table.insert(data.Inventory, {
      RobloxId = itemData.RobloxId,
      Name = itemData.Name,
      Value = itemData.Value,
      Rarity = itemData.Rarity,
      SerialNumber = itemData.SerialNumber,
      ObtainedAt = os.time()
    })
    isNewOwner = true -- Stock items always count as new owner
    
    -- Record the owner of this serial number in the ItemDatabase
    ItemDatabase:RecordSerialOwner(
      itemData.RobloxId,
      player.UserId,
      player.Name,
      itemData.SerialNumber
    )
  else
    -- Regular item - check if already exists and stack
    local found = false
    for _, invItem in ipairs(data.Inventory) do
      -- Match by RobloxId and make sure it's not a stock item
      if invItem.RobloxId == itemData.RobloxId and not invItem.SerialNumber then
        -- Stack it
        invItem.Amount = (invItem.Amount or 1) + 1
        found = true

        break
      end
    end

    -- If not found, add new entry
    if not found then
      table.insert(data.Inventory, {
        RobloxId = itemData.RobloxId,
        Name = itemData.Name,
        Value = itemData.Value,
        Rarity = itemData.Rarity,
        Amount = 1,
        ObtainedAt = os.time()
      })
      isNewOwner = true -- First time getting this regular item
    end
  end

  -- Update inventory value
  self:UpdateInventoryValue(player)

  -- Increment owners count only if this is a new owner
  if isNewOwner then
    local newOwnerCount = ItemDatabase:IncrementOwners(itemData.RobloxId)
    if not newOwnerCount then
      warn("⚠️ Failed to increment owners for item: " ..
      itemData.Name .. " (RobloxId: " .. tostring(itemData.RobloxId) .. ")")
    else
    end
  end

  return true
end

-- Remove item from inventory by index
function DataStoreAPI:RemoveItem(player, inventoryIndex)
  local data = self:GetPlayerData(player)
  if data then
    local success = DataStoreManager:RemoveItemFromInventory(data, inventoryIndex)
    if success then
      -- Update inventory value
      self:UpdateInventoryValue(player)
    end
    return success
  end
  return false
end

-- Add cash to player
function DataStoreAPI:AddCash(player, amount)
  local data = self:GetPlayerData(player)
  if data then
    DataStoreManager:AddCash(data, amount)

    -- Update leaderstats
    if player:FindFirstChild("leaderstats") then
      local cash = player.leaderstats:FindFirstChild("Cash")
      if cash then
        cash.Value = data.Cash
      end
    end


    return true
  end
  return false
end

-- Increment rolls
function DataStoreAPI:IncrementRolls(player)
  local data = self:GetPlayerData(player)
  if data then
    DataStoreManager:IncrementRolls(data)

    -- Update leaderstats
    if player:FindFirstChild("leaderstats") then
      local rolls = player.leaderstats:FindFirstChild("Rolls")
      if rolls then
        rolls.Value = data.Rolls
      end
    end

    return true
  end
  return false
end

-- Get player's inventory (with Owners count added to each item)
function DataStoreAPI:GetInventory(player)
  local data = self:GetPlayerData(player)
  if not data then
    warn("⚠️ No player data found for " .. player.Name)
    return {}
  end



  -- Add Owners count and Stock info to each item from ItemDatabase
  local inventoryWithOwners = {}
  for i, item in ipairs(data.Inventory) do
    local success, itemCopy = pcall(function()
      return table.clone(item)
    end)

    if not success then
      warn("❌ Failed to clone item " .. i .. ": " .. tostring(itemCopy))
      -- Create a manual copy instead
      itemCopy = {
        RobloxId = item.RobloxId,
        Name = item.Name,
        Value = item.Value,
        Rarity = item.Rarity,
        Amount = item.Amount,
        SerialNumber = item.SerialNumber,
        ObtainedAt = item.ObtainedAt
      }
    end

    -- Get item from database to retrieve owners, stock info, and current stock
    local dbItemSuccess, dbItem = pcall(function()
      return ItemDatabase:GetItemByRobloxId(item.RobloxId)
    end)

    if dbItemSuccess and dbItem then
      itemCopy.Owners = dbItem.Owners or 0
      itemCopy.Stock = dbItem.Stock or 0
      itemCopy.CurrentStock = dbItem.CurrentStock or 0
    else
      warn("⚠️ Failed to get database item for " .. (item.Name or "item"))
      itemCopy.Owners = 0
      itemCopy.Stock = 0
      itemCopy.CurrentStock = 0
    end

    table.insert(inventoryWithOwners, itemCopy)
  end


  return inventoryWithOwners
end

-- Get player's cash
function DataStoreAPI:GetCash(player)
  local data = self:GetPlayerData(player)
  if data then
    return data.Cash
  end
  return 0
end

-- Calculate total inventory value
function DataStoreAPI:CalculateInventoryValue(player)
  local data = self:GetPlayerData(player)
  if not data then
    return 0
  end

  local totalValue = 0
  for _, item in ipairs(data.Inventory) do
    local itemValue = item.Value or 0
    local amount = item.Amount or 1
    totalValue = totalValue + (itemValue * amount)
  end

  return totalValue
end

-- Update player's inventory value (recalculate and update leaderstats)
function DataStoreAPI:UpdateInventoryValue(player)
  local data = self:GetPlayerData(player)
  if not data then
    return false
  end

  local totalValue = self:CalculateInventoryValue(player)
  DataStoreManager:SetInvValue(data, totalValue)

  -- Update leaderstats
  if player:FindFirstChild("leaderstats") then
    local invValue = player.leaderstats:FindFirstChild("InvValue")
    if invValue then
      invValue.Value = totalValue
    end
  end

  -- Notify client that inventory was updated
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
  if remoteEvents then
    local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
    if inventoryUpdatedEvent then
      inventoryUpdatedEvent:FireClient(player)
    end
  end

  return true
end

return DataStoreAPI
