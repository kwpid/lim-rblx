local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)

local BODY_PART_ENUM_MAP = {
  LeftArm = Enum.BodyPart.LeftArm,
  RightArm = Enum.BodyPart.RightArm,
  LeftLeg = Enum.BodyPart.LeftLeg,
  RightLeg = Enum.BodyPart.RightLeg,
  Torso = Enum.BodyPart.Torso,
  Head = Enum.BodyPart.Head
}

local function equipItemToCharacter(player, robloxId, bodyPartType)
  local character = player.Character
  if not character then return false end
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if not humanoid then return false end

  local success, result = pcall(function()
    if bodyPartType and BODY_PART_ENUM_MAP[bodyPartType] then
      for _, obj in pairs(character:GetChildren()) do
        if obj:IsA("CharacterMesh") and obj.BodyPart == BODY_PART_ENUM_MAP[bodyPartType] then
          local storedId = obj:FindFirstChild("OriginalRobloxId")
          if storedId and storedId.Value == robloxId then
            return
          end
          obj:Destroy()
        end
      end
      
      local model = InsertService:LoadAsset(robloxId)
      if model then
        local meshId = robloxId
        local textureId = 0
        
        local bodyPartObj = model:FindFirstChild(bodyPartType) or model:FindFirstChildWhichIsA("MeshPart")
        if bodyPartObj and bodyPartObj:IsA("MeshPart") then
          if bodyPartObj.MeshId and bodyPartObj.MeshId ~= "" then
            meshId = tonumber(bodyPartObj.MeshId:match("%d+")) or robloxId
          end
          if bodyPartObj.TextureID and bodyPartObj.TextureID ~= "" then
            textureId = tonumber(bodyPartObj.TextureID:match("%d+")) or 0
          end
        else
          for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("SpecialMesh") or child:IsA("FileMesh") then
              if child.MeshId and child.MeshId ~= "" then
                meshId = tonumber(child.MeshId:match("%d+")) or robloxId
              end
              if child.TextureId and child.TextureId ~= "" then
                textureId = tonumber(child.TextureId:match("%d+")) or 0
              end
              break
            end
          end
        end
        
        model:Destroy()
        
        local characterMesh = Instance.new("CharacterMesh")
        characterMesh.BodyPart = BODY_PART_ENUM_MAP[bodyPartType]
        characterMesh.MeshId = meshId
        characterMesh.BaseTextureId = textureId
        local idValue = Instance.new("IntValue")
        idValue.Name = "OriginalRobloxId"
        idValue.Value = robloxId
        idValue.Parent = characterMesh
        characterMesh.Parent = character
        
        -- For R6 body parts (arms, legs, torso), character needs to be refreshed
        -- Head is excluded as it's handled differently
        local needsCharacterRefresh = (bodyPartType == "LeftArm" or bodyPartType == "RightArm" or 
                                       bodyPartType == "LeftLeg" or bodyPartType == "RightLeg" or 
                                       bodyPartType == "Torso")
        
        if needsCharacterRefresh then
          -- Save current position
          local rootPart = character:FindFirstChild("HumanoidRootPart")
          local currentPosition = rootPart and rootPart.CFrame or CFrame.new(0, 5, 0)
          
          -- Reload character
          player:LoadCharacter()
          
          -- Wait for new character and restore position
          task.wait(0.5)
          local newCharacter = player.Character
          if newCharacter then
            local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 3)
            if newRootPart then
              newRootPart.CFrame = currentPosition
            end
          end
        else
          task.wait(0.1)
          local desc = humanoid:GetAppliedDescription()
          humanoid:ApplyDescription(desc)
        end
      end
    else
      local productInfo
      pcall(function()
        productInfo = game:GetService("MarketplaceService"):GetProductInfo(robloxId)
      end)
      local isHeadless = productInfo and productInfo.Name and productInfo.Name:lower():find("headless")

      if isHeadless then
        local head = character:FindFirstChild("Head")
        if head then
          head.Transparency = 1
          local face = head:FindFirstChildOfClass("Decal")
          if face then face.Transparency = 1 end
          local idValue = head:FindFirstChild("HeadlessRobloxId") or Instance.new("IntValue")
          idValue.Name = "HeadlessRobloxId"
          idValue.Value = robloxId
          idValue.Parent = head
        end
      else
        local model = InsertService:LoadAsset(robloxId)
        if model then
          local item = model:FindFirstChildOfClass("Accessory") or model:FindFirstChildOfClass("Tool") or
          model:FindFirstChildOfClass("Hat")
          if not item then
            for _, child in ipairs(model:GetChildren()) do
              if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
                item = child
                break
              end
            end
          end
          if item then
            local itemClone = item:Clone()
            local idValue = Instance.new("IntValue")
            idValue.Name = "OriginalRobloxId"
            idValue.Value = robloxId
            idValue.Parent = itemClone
            if itemClone:IsA("Tool") then
              itemClone.Parent = player.Backpack
            else
              itemClone.Parent = character
              if itemClone:IsA("Accessory") then
                humanoid:AddAccessory(itemClone)
              end
            end
          end
          model:Destroy()
        end
      end
    end
  end)
  return success, result
end

local function unequipItemFromCharacter(player, robloxId)
  local character = player.Character
  if not character then return 0 end
  local itemsRemoved = 0
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  local needsRefresh = false
  
  local head = character:FindFirstChild("Head")
  if head then
    local headlessId = head:FindFirstChild("HeadlessRobloxId")
    if headlessId and headlessId.Value == robloxId then
      head.Transparency = 0
      local face = head:FindFirstChildOfClass("Decal")
      if face then face.Transparency = 0 end
      headlessId:Destroy()
      itemsRemoved = itemsRemoved + 1
    end
  end
  
  for _, child in ipairs(character:GetChildren()) do
    if child:IsA("CharacterMesh") then
      local storedId = child:FindFirstChild("OriginalRobloxId")
      if storedId and storedId.Value == robloxId then
        child:Destroy()
        itemsRemoved = itemsRemoved + 1
        needsRefresh = true
      end
    elseif child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
      local storedId = child:FindFirstChild("OriginalRobloxId")
      if storedId and storedId.Value == robloxId then
        child:Destroy()
        itemsRemoved = itemsRemoved + 1
      end
    end
  end
  
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
  
  if needsRefresh and humanoid then
    task.wait(0.1)
    local desc = humanoid:GetAppliedDescription()
    humanoid:ApplyDescription(desc)
  end
  
  return itemsRemoved
end

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
remoteEventsFolder.Name = "RemoteEvents"
remoteEventsFolder.Parent = ReplicatedStorage

local equipItemEvent = remoteEventsFolder:FindFirstChild("EquipItemEvent") or Instance.new("RemoteEvent")
equipItemEvent.Name = "EquipItemEvent"
equipItemEvent.Parent = remoteEventsFolder

local sellItemEvent = remoteEventsFolder:FindFirstChild("SellItemEvent") or Instance.new("RemoteEvent")
sellItemEvent.Name = "SellItemEvent"
sellItemEvent.Parent = remoteEventsFolder

local sellAllItemEvent = remoteEventsFolder:FindFirstChild("SellAllItemEvent") or Instance.new("RemoteEvent")
sellAllItemEvent.Name = "SellAllItemEvent"
sellAllItemEvent.Parent = remoteEventsFolder

local sellByRarityEvent = remoteEventsFolder:FindFirstChild("SellByRarityEvent") or Instance.new("RemoteEvent")
sellByRarityEvent.Name = "SellByRarityEvent"
sellByRarityEvent.Parent = remoteEventsFolder

local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification") or Instance.new("RemoteEvent")
notificationEvent.Name = "CreateNotification"
notificationEvent.Parent = remoteEventsFolder

local getEquippedItemsFunction = remoteEventsFolder:FindFirstChild("GetEquippedItemsFunction") or
Instance.new("RemoteFunction")
getEquippedItemsFunction.Name = "GetEquippedItemsFunction"
getEquippedItemsFunction.Parent = remoteEventsFolder

getEquippedItemsFunction.OnServerInvoke = function(player)
  local data = DataStoreAPI:GetPlayerData(player)
  if data and data.EquippedItems then
    return data.EquippedItems
  end
  return {}
end

equipItemEvent.OnServerEvent:Connect(function(player, robloxId, shouldUnequip)
  if typeof(robloxId) ~= "number" then return end
  local inventory = DataStoreAPI:GetInventory(player)
  local ownsItem, itemName, bodyPartType = false, "Item", nil
  for _, item in ipairs(inventory) do
    if item.RobloxId == robloxId then
      ownsItem, itemName = true, item.Name
      bodyPartType = item.BodyPartType
      break
    end
  end
  if not ownsItem then return end
  local data = DataStoreAPI:GetPlayerData(player)
  if not data then return end
  data.EquippedItems = data.EquippedItems or {}
  if shouldUnequip then
    unequipItemFromCharacter(player, robloxId)
    for i = #data.EquippedItems, 1, -1 do
      if data.EquippedItems[i] == robloxId then
        table.remove(data.EquippedItems, i)
      end
    end
    notificationEvent:FireClient(player,
      { Type = "UNEQUIP", Title = "Item Unequipped", Body = itemName .. " was unequipped", ImageId = robloxId })
    local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
    if inventoryUpdatedEvent then inventoryUpdatedEvent:FireClient(player) end
  else
    local success = equipItemToCharacter(player, robloxId, bodyPartType)
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
      notificationEvent:FireClient(player,
        { Type = "EQUIP", Title = "Item Equipped!", Body = itemName .. " is now equipped", ImageId = robloxId })
      local inventoryUpdatedEvent = remoteEventsFolder:FindFirstChild("InventoryUpdatedEvent")
      if inventoryUpdatedEvent then inventoryUpdatedEvent:FireClient(player) end
    end
  end
end)

sellItemEvent.OnServerEvent:Connect(function(player, robloxId, serialNumber)
  if typeof(robloxId) ~= "number" then return end
  local data = DataStoreAPI:GetPlayerData(player)
  if not data then return end
  local itemIndex, item
  for i, invItem in ipairs(data.Inventory) do
    if invItem.RobloxId == robloxId and ((serialNumber and invItem.SerialNumber == serialNumber) or (not serialNumber and not invItem.SerialNumber)) then
      itemIndex, item = i, invItem
      break
    end
  end
  if not item then return end
  
  if DataStoreAPI:IsItemLocked(player, robloxId, serialNumber) then
    notificationEvent:FireClient(player, { Type = "ERROR", Title = "Cannot Sell", Body = "This item is locked! Unlock it first to sell." })
    return
  end
  
  if item.Rarity == "Vanity" then
    notificationEvent:FireClient(player, { Type = "ERROR", Title = "Cannot Sell", Body = "Vanity items cannot be sold!" })
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
    if not stillOwnsItem then ItemDatabase:DecrementOwners(item.RobloxId) end
  else
    local amount = item.Amount or 1
    if amount > 1 then
      item.Amount = item.Amount - 1
    else
      table.remove(data.Inventory, itemIndex)
      ItemDatabase:DecrementOwners(item.RobloxId)
    end
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
  notificationEvent:FireClient(player,
    { Type = "SELL", Title = "Item Sold!", Body = "Sold " .. item.Name .. " for R$ " .. sellValue, ImageId = item
    .RobloxId })
end)

sellAllItemEvent.OnServerEvent:Connect(function(player, robloxId)
  if typeof(robloxId) ~= "number" then return end
  local data = DataStoreAPI:GetPlayerData(player)
  if not data then return end
  local totalSellValue, itemsToRemove, itemsSold, firstItem, totalCopiesRemoved = 0, {}, 0, nil, 0
  for i, invItem in ipairs(data.Inventory) do
    if invItem.RobloxId == robloxId then
      firstItem = firstItem or invItem
      
      if DataStoreAPI:IsItemLocked(player, invItem.RobloxId, invItem.SerialNumber) then
        notificationEvent:FireClient(player, { Type = "ERROR", Title = "Cannot Sell", Body = "Some items are locked! Unlock them first to sell." })
        return
      end
      
      if invItem.Rarity == "Vanity" then
        notificationEvent:FireClient(player, { Type = "ERROR", Title = "Cannot Sell", Body = "Vanity items cannot be sold!" })
        return
      end
      
      local isStockItem = invItem.SerialNumber ~= nil
      local amount = invItem.Amount or 1
      local sellValue = math.floor(invItem.Value * 0.8 * amount)
      totalSellValue = totalSellValue + sellValue
      table.insert(itemsToRemove, { index = i, item = invItem, isStock = isStockItem, amount = amount })
      itemsSold = itemsSold + amount
    end
  end
  if #itemsToRemove == 0 then return end
  table.sort(itemsToRemove, function(a, b) return a.index > b.index end)
  for _, entry in ipairs(itemsToRemove) do
    if entry.isStock then
      ItemDatabase:DecrementStock(entry.item.RobloxId)
    else
      totalCopiesRemoved = totalCopiesRemoved + entry.amount
    end
    table.remove(data.Inventory, entry.index)
  end
  if totalCopiesRemoved > 0 then ItemDatabase:DecrementTotalCopies(firstItem.RobloxId, totalCopiesRemoved) end
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
  notificationEvent:FireClient(player,
    { Type = "SELL", Title = "Items Sold!", Body = "Sold " ..
    itemsSold .. "x " .. firstItem.Name .. " for R$ " .. totalSellValue, ImageId = firstItem.RobloxId })
end)

sellByRarityEvent.OnServerEvent:Connect(function(player, rarity)
  if typeof(rarity) ~= "string" then return end
  local validRarities = {
    ["Common"] = true,
    ["Uncommon"] = true,
    ["Rare"] = true,
    ["Ultra Rare"] = true
  }
  if not validRarities[rarity] then return end
  
  local data = DataStoreAPI:GetPlayerData(player)
  if not data then return end
  
  local totalSellValue, itemsToRemove, itemsSold, totalCopiesPerItem = 0, {}, 0, {}
  
  for i, invItem in ipairs(data.Inventory) do
    local isStockItem = invItem.SerialNumber ~= nil
    if not isStockItem and invItem.Rarity == rarity then
      if not DataStoreAPI:IsItemLocked(player, invItem.RobloxId, invItem.SerialNumber) then
        local amount = invItem.Amount or 1
        local sellValue = math.floor(invItem.Value * 0.8 * amount)
        totalSellValue = totalSellValue + sellValue
        itemsSold = itemsSold + amount
        
        table.insert(itemsToRemove, { index = i, item = invItem, amount = amount })
        
        -- Track total copies per RobloxId for database updates
        if not totalCopiesPerItem[invItem.RobloxId] then
          totalCopiesPerItem[invItem.RobloxId] = 0
        end
        totalCopiesPerItem[invItem.RobloxId] = totalCopiesPerItem[invItem.RobloxId] + amount
      end
    end
  end
  
  if #itemsToRemove == 0 then return end
  
  -- Sort in reverse order to remove from the end first
  table.sort(itemsToRemove, function(a, b) return a.index > b.index end)
  
  -- Track which items we need to decrement owners for
  local ownerDecrements = {}
  for _, entry in ipairs(itemsToRemove) do
    table.remove(data.Inventory, entry.index)
    
    if not ownerDecrements[entry.item.RobloxId] then
      ownerDecrements[entry.item.RobloxId] = true
    end
    
    -- Unequip items
    unequipItemFromCharacter(player, entry.item.RobloxId)
    if data.EquippedItems then
      for i = #data.EquippedItems, 1, -1 do
        if data.EquippedItems[i] == entry.item.RobloxId then
          table.remove(data.EquippedItems, i)
        end
      end
    end
  end
  
  -- Update ItemDatabase
  for robloxId, totalCopies in pairs(totalCopiesPerItem) do
    ItemDatabase:DecrementTotalCopies(robloxId, totalCopies)
    if ownerDecrements[robloxId] then
      ItemDatabase:DecrementOwners(robloxId)
    end
  end
  
  DataStoreAPI:AddCash(player, totalSellValue)
  DataStoreAPI:UpdateInventoryValue(player)
  
  notificationEvent:FireClient(player, {
    Type = "SELL",
    Title = "Items Sold!",
    Body = "Sold " .. itemsSold .. " " .. rarity .. " items for R$ " .. totalSellValue
  })
end)

local function autoEquipItems(player)
  task.wait(1)
  local character = player.Character
  if not character then return end
  local humanoid = character:WaitForChild("Humanoid", 5)
  if not humanoid then return end
  local data = DataStoreAPI:GetPlayerData(player)
  if not data or not data.EquippedItems then return end
  local inventory = DataStoreAPI:GetInventory(player)
  local ownedItems, itemsToRemove = {}, {}
  for _, item in ipairs(inventory) do
    ownedItems[item.RobloxId] = item
  end
  for i, robloxId in ipairs(data.EquippedItems) do
    if ownedItems[robloxId] then
      local bodyPartType = ownedItems[robloxId].BodyPartType
      equipItemToCharacter(player, robloxId, bodyPartType)
    else
      table.insert(itemsToRemove, i)
    end
  end
  for i = #itemsToRemove, 1, -1 do
    table.remove(data.EquippedItems, itemsToRemove[i])
  end
end

Players.PlayerAdded:Connect(function(player)
  player.CharacterAdded:Connect(function()
    autoEquipItems(player)
  end)
  if player.Character then
    autoEquipItems(player)
  end
end)

for _, player in pairs(Players:GetPlayers()) do
  player.CharacterAdded:Connect(function()
    autoEquipItems(player)
  end)
  if player.Character then
    autoEquipItems(player)
  end
end
