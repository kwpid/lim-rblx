local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreManager = require(script.Parent.DataStoreManager)
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)

local PlayerData = {}
local AUTO_SAVE_INTERVAL = 120

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
end

local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification")
if not notificationEvent then
  notificationEvent = Instance.new("RemoteEvent")
  notificationEvent.Name = "CreateNotification"
  notificationEvent.Parent = remoteEventsFolder
end

local function setupPlayer(player)
  local data = DataStoreManager:LoadData(player)

  local dataLoadFailed = false
  if not data then
    warn("❌ Failed to load data for " .. player.Name)
    warn("⚠️ Check Studio API Access in Game Settings > Security")
    data = DataStoreManager:GetDefaultData()
    dataLoadFailed = true
  end

  -- ═══════════════════════════════════════════════════
  -- DATA CLEANUP: Remove items that no longer exist in ItemDatabase
  -- This handles cases where items were deleted while player was offline
  -- ═══════════════════════════════════════════════════
  if data.Inventory then
    local itemsToRemove = {}
    local removedItemNames = {}
    
    for i, invItem in ipairs(data.Inventory) do
      -- Check if this item still exists in ItemDatabase
      local itemExists = ItemDatabase:GetItemByRobloxId(invItem.RobloxId)
      if not itemExists then
        -- Item was deleted from database - mark for removal
        table.insert(itemsToRemove, i)
        table.insert(removedItemNames, invItem.Name or "Unknown Item")
      end
    end
    
    -- Remove items in reverse order to maintain indices
    for i = #itemsToRemove, 1, -1 do
      table.remove(data.Inventory, itemsToRemove[i])
    end
    
    -- Also clean up EquippedItems array
    if data.EquippedItems then
      local equippedToRemove = {}
      for i, robloxId in ipairs(data.EquippedItems) do
        local itemExists = ItemDatabase:GetItemByRobloxId(robloxId)
        if not itemExists then
          table.insert(equippedToRemove, i)
        end
      end
      
      for i = #equippedToRemove, 1, -1 do
        table.remove(data.EquippedItems, equippedToRemove[i])
      end
    end
    
    -- Log and notify player if items were removed
    if #itemsToRemove > 0 then
      print("🧹 Cleaned up " .. #itemsToRemove .. " deleted items from " .. player.Name .. "'s inventory")
      
      -- Send notification to player about removed items
      task.delay(3, function()
        local itemsList = ""
        for i, itemName in ipairs(removedItemNames) do
          if i <= 3 then
            itemsList = itemsList .. itemName
            if i < math.min(#removedItemNames, 3) then
              itemsList = itemsList .. ", "
            end
          end
        end
        
        if #removedItemNames > 3 then
          itemsList = itemsList .. " and " .. (#removedItemNames - 3) .. " more"
        end
        
        local notificationData = {
          Type = "ERROR",
          Title = "Items Removed",
          Body = itemsList .. " were removed (deleted by admin)"
        }
        notificationEvent:FireClient(player, notificationData)
      end)
    end
  end

  -- ═══════════════════════════════════════════════════
  -- REPAIR SERIAL OWNERS: Fix missing SerialOwner records in ItemDatabase
  -- This handles cases where stock items exist in player inventory but
  -- aren't tracked in the ItemDatabase's SerialOwners array (e.g., migrated data)
  -- ═══════════════════════════════════════════════════
  if data.Inventory and ItemDatabase.IsReady then
    local repairedCount = 0
    
    for _, invItem in ipairs(data.Inventory) do
      -- Only process stock items (items with SerialNumber)
      if invItem.SerialNumber then
        local dbItem = ItemDatabase:GetItemByRobloxId(invItem.RobloxId)
        
        if dbItem and dbItem.SerialOwners then
          -- Check if this serial number is already recorded
          local serialExists = false
          for _, owner in ipairs(dbItem.SerialOwners) do
            if owner.SerialNumber == invItem.SerialNumber and owner.UserId == player.UserId then
              serialExists = true
              break
            end
          end
          
          -- If serial not found, add it
          if not serialExists then
            local success = ItemDatabase:RecordSerialOwner(
              invItem.RobloxId,
              player.UserId,
              player.Name,
              invItem.SerialNumber
            )
            
            if success then
              repairedCount = repairedCount + 1
              print(string.format("🔧 Repaired SerialOwner: %s #%d for %s", 
                invItem.Name, invItem.SerialNumber, player.Name))
            end
          end
        end
      end
    end
    
    if repairedCount > 0 then
      print(string.format("✅ Repaired %d missing SerialOwner records for %s", repairedCount, player.Name))
    end
  end

  PlayerData[player.UserId] = data
  
  -- Set player Luck attribute (default 1.0 if not in data)
  local luck = data.Luck or 1.0
  player:SetAttribute("Luck", luck)

  local leaderstats = Instance.new("Folder")
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player

  -- Order: InvValue, Rolls, Cash
  local invValue = Instance.new("IntValue")
  invValue.Name = "InvValue"
  invValue.Value = data.InvValue or 0
  invValue.Parent = leaderstats

  local rolls = Instance.new("IntValue")
  rolls.Name = "Rolls"
  rolls.Value = data.Rolls or 0
  rolls.Parent = leaderstats

  local cash = Instance.new("IntValue")
  cash.Name = "Cash"
  cash.Value = data.Cash or 0
  cash.Parent = leaderstats

  invValue.Changed:Connect(function(newValue)
    if PlayerData[player.UserId] then
      PlayerData[player.UserId].InvValue = newValue
    end
  end)

  rolls.Changed:Connect(function(newValue)
    if PlayerData[player.UserId] then
      PlayerData[player.UserId].Rolls = newValue
    end
  end)

  cash.Changed:Connect(function(newValue)
    if PlayerData[player.UserId] then
      PlayerData[player.UserId].Cash = newValue
    end
  end)

  local totalValue = 0
  if data.Inventory then
    for _, item in ipairs(data.Inventory) do
      local itemValue = item.Value or 0
      local amount = item.Amount or 1
      totalValue = totalValue + (itemValue * amount)
    end
  end
  data.InvValue = totalValue
  invValue.Value = totalValue

  task.delay(2, function()
    if dataLoadFailed then
      local notificationData = {
        Type = "DATA_ERROR",
        Title = "Data Load Error",
        Body = "Failed to load your data. Using defaults.",
      }
      notificationEvent:FireClient(player, notificationData)
    else
      local notificationData = {
        Type = "DATA_LOADED",
        Title = "Welcome Back!",
        Body = "Your data loaded successfully",
      }
      notificationEvent:FireClient(player, notificationData)
    end
  end)
end

Players.PlayerAdded:Connect(function(player)
  setupPlayer(player)
end)

for _, player in pairs(Players:GetPlayers()) do
  task.spawn(function()
    setupPlayer(player)
  end)
end

Players.PlayerRemoving:Connect(function(player)
  local data = PlayerData[player.UserId]
  if data then
    DataStoreManager:SaveData(player, data)
    PlayerData[player.UserId] = nil
  end
end)

task.spawn(function()
  while true do
    task.wait(AUTO_SAVE_INTERVAL)
    for _, player in pairs(Players:GetPlayers()) do
      local data = PlayerData[player.UserId]
      if data then
        DataStoreManager:SaveData(player, data)
      end
    end
  end
end)

game:BindToClose(function()
  for _, player in pairs(Players:GetPlayers()) do
    local data = PlayerData[player.UserId]
    if data then
      DataStoreManager:SaveData(player, data)
    end
  end
  task.wait(3)
end)

_G.PlayerData = PlayerData

local getInventoryFunction = remoteEventsFolder:FindFirstChild("GetInventoryFunction")
if not getInventoryFunction then
  getInventoryFunction = Instance.new("RemoteFunction")
  getInventoryFunction.Name = "GetInventoryFunction"
  getInventoryFunction.Parent = remoteEventsFolder
end

getInventoryFunction.OnServerInvoke = function(player)
  local attempts = 0
  while not _G.PlayerData[player.UserId] and attempts < 10 do
    attempts = attempts + 1
    task.wait(0.1)
  end

  local success, result = pcall(function()
    return DataStoreAPI:GetInventory(player)
  end)

  if not success then
    warn("❌ GetInventory failed for " .. player.Name)
    return {}
  end

  if not result then
    return {}
  end

  return result
end

local inventoryUpdatedEvent = Instance.new("RemoteEvent")
inventoryUpdatedEvent.Name = "InventoryUpdatedEvent"
inventoryUpdatedEvent.Parent = remoteEventsFolder

-- Remote function to get another player's inventory (for viewing other players)
local getPlayerInventoryFunction = remoteEventsFolder:FindFirstChild("GetPlayerInventoryFunction")
if not getPlayerInventoryFunction then
  getPlayerInventoryFunction = Instance.new("RemoteFunction")
  getPlayerInventoryFunction.Name = "GetPlayerInventoryFunction"
  getPlayerInventoryFunction.Parent = remoteEventsFolder
end

getPlayerInventoryFunction.OnServerInvoke = function(player, targetUserId)
  -- Verify targetUserId is a number
  if type(targetUserId) ~= "number" then
    warn("❌ GetPlayerInventoryFunction: targetUserId must be a number")
    return { success = false, error = "Invalid user ID" }
  end

  -- Wait for target player data to load (with bounded retries)
  local attempts = 0
  while not _G.PlayerData[targetUserId] and attempts < 10 do
    attempts = attempts + 1
    task.wait(0.1)
  end

  -- Check if player data was never loaded
  if not _G.PlayerData[targetUserId] then
    warn("⚠️ GetPlayerInventory: Player data not loaded for UserId " .. tostring(targetUserId))
    return { success = false, error = "Player data not loaded" }
  end

  -- Get the target player's inventory
  local success, result = pcall(function()
    return DataStoreAPI:GetPlayerInventoryByUserId(targetUserId)
  end)

  if not success then
    warn("❌ GetPlayerInventory failed for UserId " .. tostring(targetUserId) .. ": " .. tostring(result))
    return { success = false, error = "Failed to retrieve inventory" }
  end

  if not result then
    warn("⚠️ GetPlayerInventory returned nil for UserId " .. tostring(targetUserId))
    return { success = false, error = "Inventory not available" }
  end

  return { success = true, inventory = result }
end
