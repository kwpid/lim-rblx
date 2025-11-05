local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AdminConfig = require(script.Parent.AdminConfig)
local ItemDatabase = require(script.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local WebhookHandler = require(script.Parent.WebhookHandler)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  local folder = Instance.new("Folder")
  folder.Name = "RemoteEvents"
  folder.Parent = ReplicatedStorage
  remoteEventsFolder = folder
end

local createItemEvent = Instance.new("RemoteEvent")
createItemEvent.Name = "CreateItemEvent"
createItemEvent.Parent = remoteEventsFolder

local giveItemEvent = Instance.new("RemoteEvent")
giveItemEvent.Name = "GiveItemEvent"
giveItemEvent.Parent = remoteEventsFolder

local deleteItemEvent = Instance.new("RemoteEvent")
deleteItemEvent.Name = "DeleteItemEvent"
deleteItemEvent.Parent = remoteEventsFolder

local checkAdminFunction = Instance.new("RemoteFunction")
checkAdminFunction.Name = "CheckAdminFunction"
checkAdminFunction.Parent = remoteEventsFolder

local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification")
if not notificationEvent then
  notificationEvent = Instance.new("RemoteEvent")
  notificationEvent.Name = "CreateNotification"
  notificationEvent.Parent = remoteEventsFolder
end

checkAdminFunction.OnServerInvoke = function(player)
  return AdminConfig:IsAdmin(player)
end

createItemEvent.OnServerEvent:Connect(function(player, robloxId, itemName, itemValue, itemStock, isLimited, offsaleTimer, isEditMode)
  if not AdminConfig:IsAdmin(player) then
    warn("non-admin " .. player.Name .. " attempted to create/edit item!")
    return
  end

  itemStock = itemStock or 0
  isLimited = isLimited or false
  offsaleTimer = offsaleTimer or 0
  isEditMode = isEditMode or false

  local success, result
  if isEditMode then
    success, result = ItemDatabase:EditItem(robloxId, itemName, itemValue, itemStock, isLimited, offsaleTimer)
    if success then
      createItemEvent:FireClient(player, true, "Item edited successfully!", result)

      local notificationData = {
        Type = "GIFT",
        Title = "Item Updated",
        Body = itemName .. " has been updated!",
        ImageId = robloxId
      }
      notificationEvent:FireAllClients(notificationData)
    else
      warn("failed to edit item: " .. result)
      createItemEvent:FireClient(player, false, result)
    end
  else
    success, result = ItemDatabase:AddItem(robloxId, itemName, itemValue, itemStock, isLimited, offsaleTimer)
    if success then
      createItemEvent:FireClient(player, true, "Item created successfully!", result)

      local notificationData = {
        Type = "GIFT",
        Title = "New Item",
        Body = itemName .. " is now available!",
        ImageId = robloxId
      }
      notificationEvent:FireAllClients(notificationData)

      if result.Rarity ~= "Limited" then
        task.spawn(function()
          local allItems = ItemDatabase:GetAllItems()
          local itemsWithPercentages = ItemRarityModule:CalculateAllRollPercentages(allItems)
          local rollPercentage = 0
          for _, itemData in ipairs(itemsWithPercentages) do
            if itemData.RobloxId == robloxId then
              rollPercentage = itemData.RollPercentage
              break
            end
          end
          WebhookHandler:SendItemRelease(result, rollPercentage)
        end)
      end
    else
      warn("failed to create item: " .. result)
      createItemEvent:FireClient(player, false, result)
    end
  end
end)

local function findPlayer(identifier)
  local playerByName = Players:FindFirstChild(identifier)
  if playerByName then return playerByName end
  local userId = tonumber(identifier)
  if userId then
    for _, player in ipairs(Players:GetPlayers()) do
      if player.UserId == userId then return player end
    end
  else
    local lowerIdentifier = string.lower(identifier)
    for _, player in ipairs(Players:GetPlayers()) do
      if string.lower(player.Name) == lowerIdentifier then return player end
    end
  end
  return nil
end

giveItemEvent.OnServerEvent:Connect(function(adminPlayer, giveItemId, giveAmount, playerIdentifier)
  if not AdminConfig:IsAdmin(adminPlayer) then
    warn("non-admin " .. adminPlayer.Name .. " attempted to give item!")
    giveItemEvent:FireClient(adminPlayer, false, "You are not an admin!")
    return
  end

  if not giveItemId or type(giveItemId) ~= "number" then
    giveItemEvent:FireClient(adminPlayer, false, "Invalid item ID!")
    return
  end

  if not giveAmount or giveAmount < 1 then
    giveItemEvent:FireClient(adminPlayer, false, "Amount must be at least 1!")
    return
  end

  if not playerIdentifier or playerIdentifier == "" then
    giveItemEvent:FireClient(adminPlayer, false, "Player ID/Username cannot be empty!")
    return
  end

  local targetPlayer = findPlayer(playerIdentifier)
  if not targetPlayer then
    giveItemEvent:FireClient(adminPlayer, false, "Player not found! Make sure they are in the game.")
    return
  end

  local item = ItemDatabase:GetItemByRobloxId(giveItemId)
  if not item then
    giveItemEvent:FireClient(adminPlayer, false, "Item with ID " .. giveItemId .. " does not exist!")
    return
  end

  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0

  if stock == 0 then
    for _ = 1, giveAmount do
      local itemToAdd = {
        RobloxId = item.RobloxId,
        Name = item.Name,
        Value = item.Value,
        Rarity = item.Rarity
      }
      DataStoreAPI:AddItem(targetPlayer, itemToAdd)
    end

    local adminNotification = {
      Type = "GIFT",
      Title = "Item Given!",
      Body = "Gave " .. giveAmount .. "x " .. item.Name .. " to " .. targetPlayer.Name,
      ImageId = item.RobloxId
    }
    notificationEvent:FireClient(adminPlayer, adminNotification)

    local playerNotification = {
      Type = "GIFT",
      Title = "Admin Gift!",
      Body = "You received " .. giveAmount .. "x " .. item.Name .. " from an admin!",
      ImageId = item.RobloxId
    }
    notificationEvent:FireClient(targetPlayer, playerNotification)
  else
    local itemsGiven = 0
    for i = 1, giveAmount do
      local serialNumber
      if currentStock < stock then
        serialNumber = ItemDatabase:IncrementStock(item)
        if serialNumber then currentStock += 1 end
      else
        serialNumber = ItemDatabase:IncreaseStockLimit(giveItemId, targetPlayer.UserId, targetPlayer.Name)
        if serialNumber then
          stock += 1
          currentStock += 1
        end
      end
      if serialNumber then
        local itemToAdd = {
          RobloxId = item.RobloxId,
          Name = item.Name,
          Value = item.Value,
          Rarity = item.Rarity,
          SerialNumber = serialNumber
        }
        DataStoreAPI:AddItem(targetPlayer, itemToAdd)
        itemsGiven += 1
      else
        warn("failed to give stock item " .. item.Name .. " #" .. i)
      end
    end

    if itemsGiven > 0 then
      local adminNotification = {
        Type = "GIFT",
        Title = "Item Given!",
        Body = "Gave " .. itemsGiven .. "x " .. item.Name .. " to " .. targetPlayer.Name,
        ImageId = item.RobloxId
      }
      notificationEvent:FireClient(adminPlayer, adminNotification)

      local playerNotification = {
        Type = "GIFT",
        Title = "Admin Gift!",
        Body = "You received " .. itemsGiven .. "x " .. item.Name .. " from an admin!",
        ImageId = item.RobloxId
      }
      notificationEvent:FireClient(targetPlayer, playerNotification)
    else
      giveItemEvent:FireClient(adminPlayer, false, "Failed to give stock items!")
    end
  end
end)

deleteItemEvent.OnServerEvent:Connect(function(adminPlayer, deleteItemId)
  if not AdminConfig:IsAdmin(adminPlayer) then
    warn("non-admin " .. adminPlayer.Name .. " attempted to delete item!")
    deleteItemEvent:FireClient(adminPlayer, false, "You are not an admin!")
    return
  end

  if not deleteItemId or type(deleteItemId) ~= "number" then
    deleteItemEvent:FireClient(adminPlayer, false, "Invalid item ID!")
    return
  end

  local item = ItemDatabase:GetItemByRobloxId(deleteItemId)
  if not item then
    deleteItemEvent:FireClient(adminPlayer, false, "Item with ID " .. deleteItemId .. " does not exist!")
    return
  end

  local success, message, deletedItemData = ItemDatabase:DeleteItem(deleteItemId)
  if not success then
    warn("failed to delete item: " .. message)
    deleteItemEvent:FireClient(adminPlayer, false, message)
    return
  end

  local playersUpdated, itemsRemoved = 0, 0
  for _, player in ipairs(Players:GetPlayers()) do
    local playerSuccess, playerError = pcall(function()
      local playerData = DataStoreAPI:GetPlayerData(player)
      if playerData and playerData.Inventory then
        local indicesToRemove = {}
        for i, invItem in ipairs(playerData.Inventory) do
          if invItem.RobloxId == deleteItemId then
            table.insert(indicesToRemove, i)
          end
        end

        for i = #indicesToRemove, 1, -1 do
          table.remove(playerData.Inventory, indicesToRemove[i])
          itemsRemoved += 1
        end

        if #indicesToRemove > 0 then
          playersUpdated += 1
          DataStoreAPI:UpdateInventoryValue(player)

          if playerData.EquippedItems then
            for i = #playerData.EquippedItems, 1, -1 do
              if playerData.EquippedItems[i] == deleteItemId then
                table.remove(playerData.EquippedItems, i)
              end
            end
          end

          local character = player.Character
          if character then
            for _, child in ipairs(character:GetChildren()) do
              if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
                local storedId = child:FindFirstChild("OriginalRobloxId")
                if storedId and storedId.Value == deleteItemId then
                  child:Destroy()
                end
              end
            end
          end

          local playerNotification = {
            Type = "ERROR",
            Title = "Item Removed",
            Body = deletedItemData.Name .. " was deleted from the game by an admin"
          }
          notificationEvent:FireClient(player, playerNotification)
        end
      end
    end)
    if not playerSuccess then
      warn("failed to cleanup item for player " .. player.Name .. ": " .. tostring(playerError))
    end
  end

  deleteItemEvent:FireClient(adminPlayer, true,
    "Deleted " .. deletedItemData.Name .. " from game and " .. playersUpdated .. " online players")
  local adminNotification = {
    Type = "VICTORY",
    Title = "Item Deleted!",
    Body = "Deleted " .. deletedItemData.Name .. " from " .. playersUpdated .. " online players",
    ImageId = deletedItemData.RobloxId
  }
  notificationEvent:FireClient(adminPlayer, adminNotification)
end)
