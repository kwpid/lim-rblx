-- DataStoreAPI.lua
-- Public API for other scripts to interact with player data
-- Use this module from other server scripts to modify player data

local DataStoreManager = require(script.Parent.DataStoreManager)

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
    print("➕ Added stock item to " .. player.Name .. "'s inventory: " .. itemData.Name .. " #" .. itemData.SerialNumber)
  else
    -- Regular item - check if already exists and stack
    local found = false
    for _, invItem in ipairs(data.Inventory) do
      -- Match by RobloxId and make sure it's not a stock item
      if invItem.RobloxId == itemData.RobloxId and not invItem.SerialNumber then
        -- Stack it
        invItem.Amount = (invItem.Amount or 1) + 1
        found = true
        print("➕ Stacked item for " .. player.Name .. ": " .. itemData.Name .. " (Amount: " .. invItem.Amount .. ")")
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
      print("➕ Added new item to " .. player.Name .. "'s inventory: " .. itemData.Name)
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
      print("➖ Removed item from " .. player.Name .. "'s inventory")
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

    print("💰 Added " .. amount .. " cash to " .. player.Name)
    return true
  end
  return false
end

-- Increment cases opened
function DataStoreAPI:IncrementCasesOpened(player)
  local data = self:GetPlayerData(player)
  if data then
    DataStoreManager:IncrementCasesOpened(data)

    -- Update leaderstats
    if player:FindFirstChild("leaderstats") then
      local casesOpened = player.leaderstats:FindFirstChild("Cases Opened")
      if casesOpened then
        casesOpened.Value = data.CasesOpened
      end
    end

    print("📦 " .. player.Name .. " opened a case! Total: " .. data.CasesOpened)
    return true
  end
  return false
end

-- Get player's inventory
function DataStoreAPI:GetInventory(player)
  local data = self:GetPlayerData(player)
  if data then
    return data.Inventory
  end
  return {}
end

-- Get player's cash
function DataStoreAPI:GetCash(player)
  local data = self:GetPlayerData(player)
  if data then
    return data.Cash
  end
  return 0
end

-- Get player's total cases opened
function DataStoreAPI:GetCasesOpened(player)
  local data = self:GetPlayerData(player)
  if data then
    return data.CasesOpened
  end
  return 0
end

return DataStoreAPI
