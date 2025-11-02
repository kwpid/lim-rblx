local DataStoreManager = require(script.Parent.DataStoreManager)
local ItemDatabase = require(script.Parent.ItemDatabase)

local DataStoreAPI = {}

function DataStoreAPI:GetPlayerData(player)
  return _G.PlayerData[player.UserId]
end

function DataStoreAPI:AddItem(player, itemData)
  local data = self:GetPlayerData(player)
  if not data then return false end

  local isNewOwner = false
  local amountToAdd = itemData.Amount or 1

  if itemData.SerialNumber then
    table.insert(data.Inventory, {
      RobloxId = itemData.RobloxId,
      Name = itemData.Name,
      Value = itemData.Value,
      Rarity = itemData.Rarity,
      SerialNumber = itemData.SerialNumber,
      ObtainedAt = os.time()
    })
    isNewOwner = true

    ItemDatabase:RecordSerialOwner(
      itemData.RobloxId,
      player.UserId,
      player.Name,
      itemData.SerialNumber
    )
  else
    local found = false
    for _, invItem in ipairs(data.Inventory) do
      if invItem.RobloxId == itemData.RobloxId and not invItem.SerialNumber then
        invItem.Amount = (invItem.Amount or 1) + amountToAdd
        found = true
        break
      end
    end

    if not found then
      table.insert(data.Inventory, {
        RobloxId = itemData.RobloxId,
        Name = itemData.Name,
        Value = itemData.Value,
        Rarity = itemData.Rarity,
        Amount = amountToAdd,
        ObtainedAt = os.time()
      })
      isNewOwner = true
    end
  end

  self:UpdateInventoryValue(player)

  if isNewOwner then
    local newOwnerCount = ItemDatabase:IncrementOwners(itemData.RobloxId)
    if not newOwnerCount then
      warn("Failed to increment owners for item: " ..
        itemData.Name .. " (RobloxId: " .. tostring(itemData.RobloxId) .. ")")
    end
  end

  if not itemData.SerialNumber then
    ItemDatabase:IncrementTotalCopies(itemData.RobloxId, amountToAdd)
  end

  return true
end

function DataStoreAPI:RemoveItem(player, inventoryIndex)
  local data = self:GetPlayerData(player)
  if not data then return false end

  local success = DataStoreManager:RemoveItemFromInventory(data, inventoryIndex)
  if success then
    self:UpdateInventoryValue(player)
  end
  return success
end

function DataStoreAPI:AddCash(player, amount)
  local data = self:GetPlayerData(player)
  if not data then return false end

  DataStoreManager:AddCash(data, amount)

  if player:FindFirstChild("leaderstats") then
    local cash = player.leaderstats:FindFirstChild("Cash")
    if cash then
      cash.Value = data.Cash
    end
  end

  return true
end

function DataStoreAPI:IncrementRolls(player)
  local data = self:GetPlayerData(player)
  if not data then return false end

  DataStoreManager:IncrementRolls(data)

  if player:FindFirstChild("leaderstats") then
    local rolls = player.leaderstats:FindFirstChild("Rolls")
    if rolls then
      rolls.Value = data.Rolls
    end
  end

  return true
end

function DataStoreAPI:GetInventory(player)
  local data = self:GetPlayerData(player)
  if not data then
    warn("No player data found for " .. player.Name)
    return {}
  end

  local inventoryWithOwners = {}
  for i, item in ipairs(data.Inventory) do
    local success, itemCopy = pcall(function()
      return table.clone(item)
    end)

    if not success then
      warn("failed to clone item " .. i .. ": " .. tostring(itemCopy))
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

    local dbItemSuccess, dbItem = pcall(function()
      return ItemDatabase:GetItemByRobloxId(item.RobloxId)
    end)

    if dbItemSuccess and dbItem then
      itemCopy.Owners = dbItem.Owners or 0
      itemCopy.TotalCopies = dbItem.TotalCopies or 0
      itemCopy.Stock = dbItem.Stock or 0
      itemCopy.CurrentStock = dbItem.CurrentStock or 0

      if item.SerialNumber and dbItem.SerialOwners then
        for _, owner in ipairs(dbItem.SerialOwners) do
          if owner.SerialNumber == item.SerialNumber then
            itemCopy.OriginalOwner = owner.Username or "null"
            break
          end
        end
      end

      if item.SerialNumber and not itemCopy.OriginalOwner then
        itemCopy.OriginalOwner = "null"
      end
    else
      warn("failed to get database item for " .. (item.Name or "item"))
      itemCopy.Owners = 0
      itemCopy.TotalCopies = 0
      itemCopy.Stock = 0
      itemCopy.CurrentStock = 0

      if item.SerialNumber then
        itemCopy.OriginalOwner = "null"
      end
    end

    table.insert(inventoryWithOwners, itemCopy)
  end

  return inventoryWithOwners
end

function DataStoreAPI:GetCash(player)
  local data = self:GetPlayerData(player)
  return data and data.Cash or 0
end

function DataStoreAPI:CalculateInventoryValue(player)
  local data = self:GetPlayerData(player)
  if not data then return 0 end

  local totalValue = 0
  for _, item in ipairs(data.Inventory) do
    totalValue = totalValue + ((item.Value or 0) * (item.Amount or 1))
  end
  return totalValue
end

function DataStoreAPI:UpdateInventoryValue(player)
  local data = self:GetPlayerData(player)
  if not data then return false end

  local totalValue = self:CalculateInventoryValue(player)
  DataStoreManager:SetInvValue(data, totalValue)

  if player:FindFirstChild("leaderstats") then
    local invValue = player.leaderstats:FindFirstChild("InvValue")
    if invValue then
      invValue.Value = totalValue
    end
  end

  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
  if remoteEvents then
    local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
    if inventoryUpdatedEvent then
      print("📢 Firing InventoryUpdatedEvent to: " .. player.Name .. " (UserId: " .. player.UserId .. ")")
      inventoryUpdatedEvent:FireClient(player)
    end
  end

  return true
end

function DataStoreAPI:SetAutoRoll(player, enabled)
  local data = self:GetPlayerData(player)
  if not data then return false end
  data.AutoRoll = enabled
  return true
end

function DataStoreAPI:GetAutoRoll(player)
  local data = self:GetPlayerData(player)
  return data and (data.AutoRoll or false) or false
end

function DataStoreAPI:GetPlayerInventoryByUserId(userId)
  local playerData = _G.PlayerData[userId]
  if not playerData then return nil end

  local inventoryWithOwners = {}
  for i, item in ipairs(playerData.Inventory) do
    local success, itemCopy = pcall(function()
      return table.clone(item)
    end)

    if not success then
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

    local dbItemSuccess, dbItem = pcall(function()
      return ItemDatabase:GetItemByRobloxId(item.RobloxId)
    end)

    if dbItemSuccess and dbItem then
      itemCopy.Owners = dbItem.Owners or 0
      itemCopy.TotalCopies = dbItem.TotalCopies or 0
      itemCopy.Stock = dbItem.Stock or 0
      itemCopy.CurrentStock = dbItem.CurrentStock or 0

      if item.SerialNumber and dbItem.SerialOwners then
        for _, owner in ipairs(dbItem.SerialOwners) do
          if owner.SerialNumber == item.SerialNumber then
            itemCopy.OriginalOwner = owner.Username or "null"
            break
          end
        end
      end

      if item.SerialNumber and not itemCopy.OriginalOwner then
        itemCopy.OriginalOwner = "null"
      end
    else
      itemCopy.Owners = 0
      itemCopy.TotalCopies = 0
      itemCopy.Stock = 0
      itemCopy.CurrentStock = 0

      if item.SerialNumber then
        itemCopy.OriginalOwner = "null"
      end
    end

    table.insert(inventoryWithOwners, itemCopy)
  end

  return inventoryWithOwners
end

return DataStoreAPI
