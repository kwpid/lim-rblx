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
    local model = InsertService:LoadAsset(robloxId)
    if model then
      local item = model:FindFirstChildOfClass("Accessory") or model:FindFirstChildOfClass("Tool") or
      model:FindFirstChildOfClass("Hat") or model:FindFirstChildOfClass("MeshPart") or model:FindFirstChildOfClass("Part")

      -- Check if this is a head item (more strict detection)
      local isHeadItem = false
      if item then
        -- Check if it's explicitly named "Head" or has SpecialMesh with Head MeshType
        if item.Name == "Head" or item.Name:lower() == "head" then
          isHeadItem = true
        elseif item:FindFirstChildOfClass("SpecialMesh") then
          local mesh = item:FindFirstChildOfClass("SpecialMesh")
          if mesh.MeshType == Enum.MeshType.Head then
            isHeadItem = true
          end
        end
      end

      if isHeadItem then
        -- Handle head replacement
        local currentHead = character:FindFirstChild("Head")
        if currentHead then
          -- Store the original head position
          local headCFrame = currentHead.CFrame
          
          -- Find the neck joint from Torso (R6) or UpperTorso (R15)
          local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
          local neckJoint = torso and torso:FindFirstChild("Neck")
          local neckC0, neckC1
          
          if neckJoint then
            neckC0 = neckJoint.C0
            neckC1 = neckJoint.C1
            neckJoint:Destroy()
          end
          
          -- Clone the new head
          local newHead = item:Clone()
          newHead.Name = "Head"
          
          -- Tag it so we can unequip it later
          local idValue = Instance.new("IntValue")
          idValue.Name = "OriginalRobloxId"
          idValue.Value = robloxId
          idValue.Parent = newHead
          
          -- Copy face if exists
          local face = currentHead:FindFirstChildOfClass("Decal")
          if face then
            face:Clone().Parent = newHead
          end
          
          -- Remove old head first
          currentHead:Destroy()
          
          -- Add the new head
          newHead.Parent = character
          newHead.CFrame = headCFrame
          
          -- Recreate neck connection
          if torso then
            local neck = Instance.new("Motor6D")
            neck.Name = "Neck"
            neck.Part0 = torso
            neck.Part1 = newHead
            
            -- Use stored values or defaults for R6/R15
            if neckC0 then
              neck.C0 = neckC0
              neck.C1 = neckC1
            else
              -- R6 default neck values
              neck.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
              neck.C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
            end
            
            neck.Parent = torso
          end
        end
      elseif item then
        -- Handle normal accessories, hats, and tools
        local itemClone = item:Clone()
        local idValue = Instance.new("IntValue")
        idValue.Name = "OriginalRobloxId"
        idValue.Value = robloxId
        idValue.Parent = itemClone
        
        -- Parent to character - this works for all accessory types
        itemClone.Parent = character
        
        -- Force the humanoid to add the accessory (ensures it attaches properly)
        if itemClone:IsA("Accessory") and humanoid then
          humanoid:AddAccessory(itemClone)
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
            itemClone.Parent = character
            
            -- Force the humanoid to add the accessory
            if itemClone:IsA("Accessory") and humanoid then
              humanoid:AddAccessory(itemClone)
            end
            break
          elseif child.Name == "Head" or child.Name:lower() == "head" then
            -- Handle head from children using same logic
            local currentHead = character:FindFirstChild("Head")
            if currentHead then
              local headCFrame = currentHead.CFrame
              local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
              local neckJoint = torso and torso:FindFirstChild("Neck")
              local neckC0, neckC1
              
              if neckJoint then
                neckC0 = neckJoint.C0
                neckC1 = neckJoint.C1
                neckJoint:Destroy()
              end
              
              local newHead = child:Clone()
              newHead.Name = "Head"
              
              local idValue = Instance.new("IntValue")
              idValue.Name = "OriginalRobloxId"
              idValue.Value = robloxId
              idValue.Parent = newHead
              
              local face = currentHead:FindFirstChildOfClass("Decal")
              if face then
                face:Clone().Parent = newHead
              end
              
              currentHead:Destroy()
              
              newHead.Parent = character
              newHead.CFrame = headCFrame
              
              if torso then
                local neck = Instance.new("Motor6D")
                neck.Name = "Neck"
                neck.Part0 = torso
                neck.Part1 = newHead
                
                if neckC0 then
                  neck.C0 = neckC0
                  neck.C1 = neckC1
                else
                  neck.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
                  neck.C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
                end
                
                neck.Parent = torso
              end
            end
            break
          end
        end
      end
      model:Destroy()
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
  
  -- Check if the head is equipped with this robloxId
  local head = character:FindFirstChild("Head")
  if head then
    local storedId = head:FindFirstChild("OriginalRobloxId")
    if storedId and storedId.Value == robloxId then
      -- Restore default head
      local success, result = pcall(function()
        -- Find the torso (R6 or R15)
        local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        local neckJoint = torso and torso:FindFirstChild("Neck")
        local neckC0, neckC1
        local headCFrame = head.CFrame
        
        if neckJoint then
          neckC0 = neckJoint.C0
          neckC1 = neckJoint.C1
          neckJoint:Destroy()
        end
        
        -- Destroy the equipped head
        head:Destroy()
        
        -- Create a default Roblox head
        local newHead = Instance.new("Part")
        newHead.Name = "Head"
        newHead.Size = Vector3.new(2, 1, 1)
        newHead.TopSurface = Enum.SurfaceType.Smooth
        newHead.BottomSurface = Enum.SurfaceType.Smooth
        newHead.BrickColor = BrickColor.new("Bright yellow")
        
        -- Add default face
        local face = Instance.new("Decal")
        face.Name = "face"
        face.Texture = "rbxasset://textures/face.png"
        face.Face = Enum.NormalId.Front
        face.Parent = newHead
        
        -- Position and parent the new head
        newHead.Parent = character
        newHead.CFrame = headCFrame
        
        -- Recreate neck connection
        if torso then
          local neck = Instance.new("Motor6D")
          neck.Name = "Neck"
          neck.Part0 = torso
          neck.Part1 = newHead
          
          if neckC0 then
            neck.C0 = neckC0
            neck.C1 = neckC1
          else
            -- R6 default neck values
            neck.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
            neck.C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
          end
          
          neck.Parent = torso
        end
        
        itemsRemoved = itemsRemoved + 1
      end)
      
      if not success then
        warn("Failed to restore default head:", result)
      end
    end
  end
  
  -- Handle accessories, tools, and hats
  for _, child in ipairs(character:GetChildren()) do
    if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
      local storedId = child:FindFirstChild("OriginalRobloxId")
      if storedId and storedId.Value == robloxId then
        child:Destroy()
        itemsRemoved = itemsRemoved + 1
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

  for _, entry in ipairs(itemsToRemove) do
    if entry.isStock then
      ItemDatabase:DecrementStock(entry.item.RobloxId)
    end
    table.remove(data.Inventory, entry.index)
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
  task.wait(0.5)

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
      equipItemToCharacter(player, robloxId)
    else
      table.insert(itemsToRemove, i)
    end
  end

  for i = #itemsToRemove, 1, -1 do
    table.remove(data.EquippedItems, itemsToRemove[i])
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
