-- EquipSellHandler.lua
-- Handles equipping items to characters and selling items from inventory

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)

-- Create RemoteEvents folder if it doesn't exist
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
  print("✅ Created RemoteEvents folder")
end

-- Create RemoteEvents
local equipItemEvent = remoteEventsFolder:FindFirstChild("EquipItemEvent")
if not equipItemEvent then
  equipItemEvent = Instance.new("RemoteEvent")
  equipItemEvent.Name = "EquipItemEvent"
  equipItemEvent.Parent = remoteEventsFolder
  print("✅ Created EquipItemEvent")
end

local sellItemEvent = remoteEventsFolder:FindFirstChild("SellItemEvent")
if not sellItemEvent then
  sellItemEvent = Instance.new("RemoteEvent")
  sellItemEvent.Name = "SellItemEvent"
  sellItemEvent.Parent = remoteEventsFolder
  print("✅ Created SellItemEvent")
end

local sellAllItemEvent = remoteEventsFolder:FindFirstChild("SellAllItemEvent")
if not sellAllItemEvent then
  sellAllItemEvent = Instance.new("RemoteEvent")
  sellAllItemEvent.Name = "SellAllItemEvent"
  sellAllItemEvent.Parent = remoteEventsFolder
  print("✅ Created SellAllItemEvent")
end

-- Equip item to player's character
equipItemEvent.OnServerEvent:Connect(function(player, robloxId)
  print("🎽 " .. player.Name .. " attempting to equip item with RobloxId: " .. tostring(robloxId))
  
  if not robloxId or type(robloxId) ~= "number" then
    warn("❌ Invalid RobloxId provided: " .. tostring(robloxId))
    return
  end
  
  local character = player.Character
  if not character then
    warn("❌ Player has no character")
    return
  end
  
  -- Verify player owns this item
  local inventory = DataStoreAPI:GetInventory(player)
  local ownsItem = false
  for _, item in ipairs(inventory) do
    if item.RobloxId == robloxId then
      ownsItem = true
      break
    end
  end
  
  if not ownsItem then
    warn("❌ Player " .. player.Name .. " does not own item with RobloxId: " .. robloxId)
    return
  end
  
  -- Try to equip the item
  local success, result = pcall(function()
    local model = InsertService:LoadAsset(robloxId)
    if model then
      -- Find the accessory or tool in the loaded model
      local item = model:FindFirstChildOfClass("Accessory") or model:FindFirstChildOfClass("Tool") or model:FindFirstChildOfClass("Hat")
      
      if item then
        -- Clone it and parent to character
        local itemClone = item:Clone()
        itemClone.Parent = character
        print("✅ Equipped " .. itemClone.Name .. " to " .. player.Name)
      else
        -- If it's not an accessory/tool, try to just parent the whole model
        for _, child in ipairs(model:GetChildren()) do
          if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
            local itemClone = child:Clone()
            itemClone.Parent = character
            print("✅ Equipped " .. itemClone.Name .. " to " .. player.Name)
            break
          end
        end
      end
      
      model:Destroy()
    end
  end)
  
  if not success then
    warn("❌ Failed to equip item: " .. tostring(result))
  end
end)

-- Sell one copy of an item
sellItemEvent.OnServerEvent:Connect(function(player, robloxId, serialNumber)
  print("💵 " .. player.Name .. " attempting to sell item with RobloxId: " .. tostring(robloxId) .. ", Serial: " .. tostring(serialNumber))
  
  if not robloxId or type(robloxId) ~= "number" then
    warn("❌ Invalid RobloxId provided: " .. tostring(robloxId))
    return
  end
  
  local data = DataStoreAPI:GetPlayerData(player)
  if not data then
    warn("❌ No player data found for " .. player.Name)
    return
  end
  
  -- Find the specific item in inventory
  local itemIndex = nil
  local item = nil
  for i, invItem in ipairs(data.Inventory) do
    -- Match by RobloxId
    if invItem.RobloxId == robloxId then
      -- If serialNumber provided, must match exactly (for stock items)
      if serialNumber then
        if invItem.SerialNumber == serialNumber then
          itemIndex = i
          item = invItem
          break
        end
      else
        -- No serial number, match first non-stock item with this RobloxId
        if not invItem.SerialNumber then
          itemIndex = i
          item = invItem
          break
        end
      end
    end
  end
  
  if not item then
    warn("❌ Item not found in " .. player.Name .. "'s inventory with RobloxId: " .. robloxId)
    return
  end
  
  -- Calculate sell value (80% of item value)
  local sellValue = math.floor(item.Value * 0.8)
  
  -- Check if this is a stock item or regular item
  local isStockItem = item.SerialNumber ~= nil
  
  if isStockItem then
    -- Stock item - remove the entire entry and restore stock
    table.remove(data.Inventory, itemIndex)
    
    -- Decrement stock in ItemDatabase (making it rollable again)
    local restored = ItemDatabase:DecrementStock(item.RobloxId)
    if restored then
      print("📦 Restored stock for " .. item.Name .. " (now rollable again)")
    end
    
    -- Check if player still owns ANY items with this RobloxId
    local stillOwnsItem = false
    for _, invItem in ipairs(data.Inventory) do
      if invItem.RobloxId == item.RobloxId then
        stillOwnsItem = true
        break
      end
    end
    
    -- Only decrement owners if player no longer owns ANY copy
    if not stillOwnsItem then
      ItemDatabase:DecrementOwners(item.RobloxId)
      print("📊 Player no longer owns any copies of " .. item.Name .. ", decremented owner count")
    end
    
    print("💰 " .. player.Name .. " sold stock item: " .. item.Name .. " #" .. item.SerialNumber .. " for R$ " .. sellValue)
  else
    -- Regular item - decrease amount or remove if only 1
    local amount = item.Amount or 1
    if amount > 1 then
      -- Decrease stack
      item.Amount = amount - 1
      print("💰 " .. player.Name .. " sold 1x " .. item.Name .. " for R$ " .. sellValue .. " (" .. item.Amount .. " remaining)")
    else
      -- Remove entire entry - player no longer owns this item
      table.remove(data.Inventory, itemIndex)
      
      -- Decrement owners count (player no longer owns this item)
      ItemDatabase:DecrementOwners(item.RobloxId)
      
      print("💰 " .. player.Name .. " sold last " .. item.Name .. " for R$ " .. sellValue)
    end
  end
  
  -- Add cash to player
  DataStoreAPI:AddCash(player, sellValue)
  
  -- Update inventory value
  DataStoreAPI:UpdateInventoryValue(player)
end)

-- Sell all copies of an item
sellAllItemEvent.OnServerEvent:Connect(function(player, robloxId)
  print("💵💵 " .. player.Name .. " attempting to sell ALL items with RobloxId: " .. tostring(robloxId))
  
  if not robloxId or type(robloxId) ~= "number" then
    warn("❌ Invalid RobloxId provided: " .. tostring(robloxId))
    return
  end
  
  local data = DataStoreAPI:GetPlayerData(player)
  if not data then
    warn("❌ No player data found for " .. player.Name)
    return
  end
  
  -- Find all matching items in inventory (for stock items, there might be multiple with different serial numbers)
  local totalSellValue = 0
  local itemsToRemove = {}
  local itemsSold = 0
  local firstItem = nil
  local hasStockItems = false
  
  -- Find all items with this RobloxId
  for i, invItem in ipairs(data.Inventory) do
    if invItem.RobloxId == robloxId then
      if not firstItem then
        firstItem = invItem
      end
      
      local isStockItem = invItem.SerialNumber ~= nil
      local amount = invItem.Amount or 1
      
      if isStockItem then
        hasStockItems = true
      end
      
      -- Calculate sell value for this entry
      local sellValue = math.floor(invItem.Value * 0.8 * amount)
      totalSellValue = totalSellValue + sellValue
      
      -- Track items to remove
      table.insert(itemsToRemove, {index = i, item = invItem, isStock = isStockItem, amount = amount})
      
      itemsSold = itemsSold + amount
    end
  end
  
  if #itemsToRemove == 0 then
    warn("❌ No items found in " .. player.Name .. "'s inventory with RobloxId: " .. robloxId)
    return
  end
  
  -- Remove items in reverse order to preserve indices
  table.sort(itemsToRemove, function(a, b) return a.index > b.index end)
  
  for _, entry in ipairs(itemsToRemove) do
    if entry.isStock then
      -- Stock item - restore stock in database
      local restored = ItemDatabase:DecrementStock(entry.item.RobloxId)
      if restored then
        print("📦 Restored stock for " .. entry.item.Name)
      end
    end
    
    table.remove(data.Inventory, entry.index)
  end
  
  -- Player sold ALL copies of this item - decrement owners count once
  ItemDatabase:DecrementOwners(firstItem.RobloxId)
  print("📊 Player sold all copies of " .. firstItem.Name .. ", decremented owner count")
  
  -- Add cash to player
  DataStoreAPI:AddCash(player, totalSellValue)
  
  -- Update inventory value
  DataStoreAPI:UpdateInventoryValue(player)
  
  print("💰💰 " .. player.Name .. " sold " .. itemsSold .. "x " .. firstItem.Name .. " for R$ " .. totalSellValue)
end)

print("✅ EquipSellHandler ready!")
