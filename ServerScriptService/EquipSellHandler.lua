local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)

local function equipItemToCharacter(player, robloxId)
  local character = player.Character
  if not character then
    return false, "No character"
  end
  
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if not humanoid then
    return false, "No humanoid"
  end

  local success, result = pcall(function()
    -- Check if this is a headless item (contains "headless" in the name when fetched)
    local productInfo
    pcall(function()
      productInfo = game:GetService("MarketplaceService"):GetProductInfo(robloxId)
    end)
    
    local isHeadless = productInfo and productInfo.Name and productInfo.Name:lower():find("headless")
    
    if isHeadless then
      -- Handle headless by making head and face transparent
      local head = character:FindFirstChild("Head")
      if head then
        head.Transparency = 1
        
        -- Make face transparent
        local face = head:FindFirstChildOfClass("Decal")
        if face then
          face.Transparency = 1
        end
        
        -- Tag the head so we know headless is equipped
        local idValue = head:FindFirstChild("HeadlessRobloxId")
        if not idValue then
          idValue = Instance.new("IntValue")
          idValue.Name = "HeadlessRobloxId"
          idValue.Parent = head
        end
        idValue.Value = robloxId
      end
    else
      -- Handle normal accessories, hats, and tools
      local model = InsertService:LoadAsset(robloxId)
      if model then
        local item = model:FindFirstChildOfClass("Accessory") or model:FindFirstChildOfClass("Tool") or
        model:FindFirstChildOfClass("Hat")

        if item then
          local itemClone = item:Clone()
          local idValue = Instance.new("IntValue")
          idValue.Name = "OriginalRobloxId"
          idValue.Value = robloxId
          idValue.Parent = itemClone
          
          -- Handle tools differently - they go in Backpack, not Character
          if itemClone:IsA("Tool") then
            itemClone.Parent = player.Backpack
          else
            -- Accessories and Hats go to character
            itemClone.Parent = character
            
            -- Force the humanoid to add the accessory (ensures it attaches properly)
            if itemClone:IsA("Accessory") and humanoid then
              humanoid:AddAccessory(itemClone)
            end
          end
        else
          -- Fallback: search children
          for _, child in ipairs(model:GetChildren()) do
            if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
              local itemClone = child:Clone()
              local idValue = Instance.new("IntValue")
              idValue.Name = "OriginalRobloxId"
              idValue.Value = robloxId
              idValue.Parent = itemClone
              
              -- Handle tools differently - they go in Backpack, not Character
              if itemClone:IsA("Tool") then
                itemClone.Parent = player.Backpack
              else
                -- Accessories and Hats go to character
                itemClone.Parent = character
                
                -- Force the humanoid to add the accessory
                if itemClone:IsA("Accessory") and humanoid then
                  humanoid:AddAccessory(itemClone)
                end
              end
              break
            end
          end
        end
        model:Destroy()
      end
    end
  end)

  return success, result
end

local function unequipItemFromCharacter(player, robloxId)
  local character = player.Character
  if not character then
    return 0
  end

  local itemsRemoved = 0
  
  -- Check if this is a headless item being unequipped
  local head = character:FindFirstChild("Head")
  if head then
    local headlessId = head:FindFirstChild("HeadlessRobloxId")
    if headlessId and headlessId.Value == robloxId then
      -- Restore head and face visibility
      head.Transparency = 0
      
      local face = head:FindFirstChildOfClass("Decal")
      if face then
        face.Transparency = 0
      end
      
      -- Remove the tag
      headlessId:Destroy()
      itemsRemoved = itemsRemoved + 1
    end
  end
  
  -- Handle accessories and hats in character
  for _, child in ipairs(character:GetChildren()) do
    if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
      local storedId = child:FindFirstChild("OriginalRobloxId")
      if storedId and storedId.Value == robloxId then
        child:Destroy()
        itemsRemoved = itemsRemoved + 1
      end
    end
  end
  
  -- Also check Backpack for tools
  local backpack = player:FindFirstChild("Backpack")
  if backpack then
    for _, child in ipairs(backpack:GetChildren()) do
      if child:IsA("Tool") then
        local storedId = child:FindFirstChild("OriginalRobloxId")
        if storedId and storedId.Value == robloxId then
          child:Destroy()
          itemsRemoved = itemsRemoved + 1
        end
      end
    end
  end

  return itemsRemoved
end

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
end

local equipItemEvent = remoteEventsFolder:FindFirstChild("EquipItemEvent")
if not equipItemEvent then
  equipItemEvent = Instance.new("RemoteEvent")
  equipItemEvent.Name = "EquipItemEvent"
  equipItemEvent.Parent = remoteEventsFolder
end

local sellItemEvent = remoteEventsFolder:FindFirstChild("SellItemEvent")
if not sellItemEvent then
  sellItemEvent = Instance.new("RemoteEvent")
  sellItemEvent.Name = "SellItemEvent"
  sellItemEvent.Parent = remoteEventsFolder
end

local sellAllItemEvent = remoteEventsFolder:FindFirstChild("SellAllItemEvent")
if not sellAllItemEvent then
  sellAllItemEvent = Instance.new("RemoteEvent")
  sellAllItemEvent.Name = "SellAllItemEvent"
  sellAllItemEvent.Parent = remoteEventsFolder
end

local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification")
if not notificationEvent then
  notificationEvent = Instance.new("RemoteEvent")
  notificationEvent.Name = "CreateNotification"
  notificationEvent.Parent = remoteEventsFolder
end

local getEquippedItemsFunction = remoteEventsFolder:FindFirstChild("GetEquippedItemsFunction")
if not getEquippedItemsFunction then
  getEquippedItemsFunction = Instance.new("RemoteFunction")
  getEquippedItemsFunction.Name = "GetEquippedItemsFunction"
  getEquippedItemsFunction.Parent = remoteEventsFolder
end

getEquippedItemsFunction.OnServerInvoke = function(player)
  local data = DataStoreAPI:GetPlayerData(player)
  if data and data.EquippedItems then
    return data.EquippedItems
  end
  return {}
end

equipItemEvent.OnServerEvent:Connect(function(player, robloxId, shouldUnequip)
  if not robloxId or type(robloxId) ~= "number" then
    return
  end

  local inventory = DataStoreAPI:GetInventory(player)
  local ownsItem = false
  local itemName = "Item"
  for _, item in ipairs(inventory) do
    if item.RobloxId == robloxId then
      ownsItem = true
      itemName = item.Name
      break
    end
  end

  if not ownsItem then
    return
  end

  local data = DataStoreAPI:GetPlayerData(player)
  if not data then
    return
  end

  if not data.EquippedItems then
    data.EquippedItems = {}
  end

  if shouldUnequip then
    unequipItemFromCharacter(player, robloxId)

    for i = #data.EquippedItems, 1, -1 do
      if data.EquippedItems[i] == robloxId then
        table.remove(data.EquippedItems, i)
      end
    end

    local notificationData = {
      Type = "UNEQUIP",
      Title = "Item Unequipped",
      Body = itemName .. " was unequipped",
      ImageId = robloxId
    }
    notificationEvent:FireClient(player, notificationData)
    
    -- Refresh inventory to update sorting and borders
    local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
    if inventoryUpdatedEvent then
      inventoryUpdatedEvent:FireClient(player)
    end
  else
    local success, result = equipItemToCharacter(player, robloxId)

    if success then
      local alreadyEquipped = false
      for _, equippedId in ipairs(data.EquippedItems) do
        if equippedId == robloxId then
          alreadyEquipped = true
          break
        end
      end

      if not alreadyEquipped then
        table.insert(data.EquippedItems, robloxId)
      end

      local notificationData = {
        Type = "EQUIP",
        Title = "Item Equipped!",
        Body = itemName .. " is now equipped",
        ImageId = robloxId
      }
      notificationEvent:FireClient(player, notificationData)
      
      -- Refresh inventory to update sorting and borders
      local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
      if inventoryUpdatedEvent then
        inventoryUpdatedEvent:FireClient(player)
      end
    end
  end
end)

sellItemEvent.OnServerEvent:Connect(function(player, robloxId, serialNumber)
  if not robloxId or type(robloxId) ~= "number" then
    return
  end

  local data = DataStoreAPI:GetPlayerData(player)
  if not data then
    return
  end

  local itemIndex = nil
  local item = nil
  for i, invItem in ipairs(data.Inventory) do
    if invItem.RobloxId == robloxId then
      if serialNumber then
        if invItem.SerialNumber == serialNumber then
          itemIndex = i
          item = invItem
          break
        end
      else
        if not invItem.SerialNumber then
          itemIndex = i
          item = invItem
          break
        end
      end
    end
  end

  if not item then
    return
  end

  local sellValue = math.floor(item.Value * 0.8)
  local isStockItem = item.SerialNumber ~= nil

  if isStockItem then
    table.remove(data.Inventory, itemIndex)
    ItemDatabase:DecrementStock(item.RobloxId)

    local stillOwnsItem = false
    for _, invItem in ipairs(data.Inventory) do
      if invItem.RobloxId == item.RobloxId then
        stillOwnsItem = true
        break
      end
    end

    if not stillOwnsItem then
      ItemDatabase:DecrementOwners(item.RobloxId)
    end
  else
    local amount = item.Amount or 1
    if amount > 1 then
      item.Amount = amount - 1
    else
      table.remove(data.Inventory, itemIndex)
      ItemDatabase:DecrementOwners(item.RobloxId)
    end
    -- Decrement total copies for regular items
    ItemDatabase:DecrementTotalCopies(item.RobloxId, 1)
  end

  local stillOwnsItem = false
  for _, invItem in ipairs(data.Inventory) do
    if invItem.RobloxId == robloxId then
      stillOwnsItem = true
      break
    end
  end

  if not stillOwnsItem then
    unequipItemFromCharacter(player, robloxId)

    if data.EquippedItems then
      for i = #data.EquippedItems, 1, -1 do
        if data.EquippedItems[i] == robloxId then
          table.remove(data.EquippedItems, i)
        end
      end
    end
  end

  DataStoreAPI:AddCash(player, sellValue)
  DataStoreAPI:UpdateInventoryValue(player)

  local notificationData = {
    Type = "SELL",
    Title = "Item Sold!",
    Body = "Sold " .. item.Name .. " for R$ " .. sellValue,
    ImageId = item.RobloxId
  }
  notificationEvent:FireClient(player, notificationData)
end)

sellAllItemEvent.OnServerEvent:Connect(function(player, robloxId)
  if not robloxId or type(robloxId) ~= "number" then
    return
  end

  local data = DataStoreAPI:GetPlayerData(player)
  if not data then
    return
  end

  local totalSellValue = 0
  local itemsToRemove = {}
  local itemsSold = 0
  local firstItem = nil
  local hasStockItems = false

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

      local sellValue = math.floor(invItem.Value * 0.8 * amount)
      totalSellValue = totalSellValue + sellValue

      table.insert(itemsToRemove, { index = i, item = invItem, isStock = isStockItem, amount = amount })
      itemsSold = itemsSold + amount
    end
  end

  if #itemsToRemove == 0 then
    return
  end

  table.sort(itemsToRemove, function(a, b) return a.index > b.index end)

  local totalCopiesRemoved = 0
  for _, entry in ipairs(itemsToRemove) do
    if entry.isStock then
      ItemDatabase:DecrementStock(entry.item.RobloxId)
    else
      totalCopiesRemoved = totalCopiesRemoved + entry.amount
    end
    table.remove(data.Inventory, entry.index)
  end

  -- Decrement total copies for regular items
  if totalCopiesRemoved > 0 then
    ItemDatabase:DecrementTotalCopies(firstItem.RobloxId, totalCopiesRemoved)
  end

  ItemDatabase:DecrementOwners(firstItem.RobloxId)
  unequipItemFromCharacter(player, robloxId)

  if data.EquippedItems then
    for i = #data.EquippedItems, 1, -1 do
      if data.EquippedItems[i] == robloxId then
        table.remove(data.EquippedItems, i)
      end
    end
  end

  DataStoreAPI:AddCash(player, totalSellValue)
  DataStoreAPI:UpdateInventoryValue(player)

  local notificationData = {
    Type = "SELL",
    Title = "Items Sold!",
    Body = "Sold " .. itemsSold .. "x " .. firstItem.Name .. " for R$ " .. totalSellValue,
    ImageId = firstItem.RobloxId
  }
  notificationEvent:FireClient(player, notificationData)
end)

local function autoEquipItems(player)
  -- Wait for character to fully load
  task.wait(1)
  
  local character = player.Character
  if not character then
    return
  end
  
  -- Wait for humanoid
  local humanoid = character:WaitForChild("Humanoid", 5)
  if not humanoid then
    return
  end

  local data = DataStoreAPI:GetPlayerData(player)
  if not data or not data.EquippedItems then
    return
  end

  local inventory = DataStoreAPI:GetInventory(player)
  local ownedRobloxIds = {}
  for _, item in ipairs(inventory) do
    ownedRobloxIds[item.RobloxId] = true
  end

  local itemsToRemove = {}
  for i, robloxId in ipairs(data.EquippedItems) do
    if ownedRobloxIds[robloxId] then
      local success, err = equipItemToCharacter(player, robloxId)
      if not success then
        warn("⚠️ Failed to auto-equip item " .. robloxId .. " for " .. player.Name .. ": " .. tostring(err))
      end
    else
      table.insert(itemsToRemove, i)
    end
  end

  -- Remove items that are no longer owned
  for i = #itemsToRemove, 1, -1 do
    table.remove(data.EquippedItems, itemsToRemove[i])
  end
  
  if #data.EquippedItems > 0 then
    print("✅ Auto-equipped " .. #data.EquippedItems .. " items for " .. player.Name)
  end
end

Players.PlayerAdded:Connect(function(player)
  player.CharacterAdded:Connect(function(character)
    autoEquipItems(player)
  end)

  if player.Character then
    autoEquipItems(player)
  end
end)

for _, player in pairs(Players:GetPlayers()) do
  player.CharacterAdded:Connect(function(character)
    autoEquipItems(player)
  end)

  if player.Character then
    autoEquipItems(player)
  end
end
