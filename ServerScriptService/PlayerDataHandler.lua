local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreManager = require(script.Parent.DataStoreManager)
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemDatabase = require(script.Parent.ItemDatabase)

local PlayerData = {}
local AUTO_SAVE_INTERVAL = 120

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
remoteEventsFolder.Name = "RemoteEvents"
remoteEventsFolder.Parent = ReplicatedStorage

local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification") or Instance.new("RemoteEvent")
notificationEvent.Name = "CreateNotification"
notificationEvent.Parent = remoteEventsFolder

local function setupPlayer(player)
  local data = DataStoreManager:LoadData(player)
  local dataLoadFailed = false

  if not data then
    data = DataStoreManager:GetDefaultData()
    dataLoadFailed = true
  end

  if data.Inventory then
    local itemsToRemove, removedItemNames = {}, {}

    for i, invItem in ipairs(data.Inventory) do
      local itemExists = ItemDatabase:GetItemByRobloxId(invItem.RobloxId)
      if not itemExists then
        table.insert(itemsToRemove, i)
        table.insert(removedItemNames, invItem.Name or "Unknown Item")
      end
    end

    for i = #itemsToRemove, 1, -1 do
      table.remove(data.Inventory, itemsToRemove[i])
    end

    if data.EquippedItems then
      local equippedToRemove = {}
      for i, robloxId in ipairs(data.EquippedItems) do
        if not ItemDatabase:GetItemByRobloxId(robloxId) then
          table.insert(equippedToRemove, i)
        end
      end
      for i = #equippedToRemove, 1, -1 do
        table.remove(data.EquippedItems, equippedToRemove[i])
      end
    end

    if #itemsToRemove > 0 then
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
        notificationEvent:FireClient(player, {
          Type = "ERROR",
          Title = "Items Removed",
          Body = itemsList .. " were removed (deleted by admin)"
        })
      end)
    end
  end

  local MAX_REGULAR_ITEM_STACK = 100
  local function shouldHaveStackLimit(rarity)
    local limitedRarities = { Common = true, Uncommon = true, Rare = true, ["Ultra Rare"] = true }
    return limitedRarities[rarity] == true
  end

  if data.Inventory then
    local totalAutoSellValue, itemsAutoSold = 0, {}
    for _, invItem in ipairs(data.Inventory) do
      if not invItem.SerialNumber and shouldHaveStackLimit(invItem.Rarity) then
        local currentAmount = invItem.Amount or 1
        if currentAmount > MAX_REGULAR_ITEM_STACK then
          local excessAmount = currentAmount - MAX_REGULAR_ITEM_STACK
          local sellValue = math.floor(invItem.Value * 0.8 * excessAmount)
          invItem.Amount = MAX_REGULAR_ITEM_STACK
          totalAutoSellValue += sellValue
          ItemDatabase:DecrementTotalCopies(invItem.RobloxId, excessAmount)
          table.insert(itemsAutoSold, { name = invItem.Name, amount = excessAmount, value = sellValue })
        end
      end
    end

    if totalAutoSellValue > 0 then
      data.Cash = (data.Cash or 0) + totalAutoSellValue
      task.delay(3, function()
        local itemsList = ""
        for i, item in ipairs(itemsAutoSold) do
          if i <= 3 then
            itemsList = itemsList .. item.amount .. "x " .. item.name
            if i < math.min(#itemsAutoSold, 3) then
              itemsList = itemsList .. ", "
            end
          end
        end
        if #itemsAutoSold > 3 then
          itemsList = itemsList .. " and " .. (#itemsAutoSold - 3) .. " more"
        end
        notificationEvent:FireClient(player, {
          Type = "SELL",
          Title = "Auto-Sold Excess Items",
          Body = itemsList .. " (max 100 per item)\nReceived R$" .. totalAutoSellValue
        })
      end)
    end
  end

  PlayerData[player.UserId] = data

  local leaderstats = Instance.new("Folder")
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player

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

  invValue.Changed:Connect(function(v)
    if PlayerData[player.UserId] then PlayerData[player.UserId].InvValue = v end
  end)
  rolls.Changed:Connect(function(v)
    if PlayerData[player.UserId] then PlayerData[player.UserId].Rolls = v end
  end)
  cash.Changed:Connect(function(v)
    if PlayerData[player.UserId] then PlayerData[player.UserId].Cash = v end
  end)

  local totalValue = 0
  if data.Inventory then
    for _, item in ipairs(data.Inventory) do
      totalValue += (item.Value or 0) * (item.Amount or 1)
    end
  end
  data.InvValue, invValue.Value = totalValue, totalValue

  task.delay(2, function()
    local msg = dataLoadFailed and {
      Type = "DATA_ERROR",
      Title = "Data Load Error",
      Body = "Failed to load your data. Using defaults."
    } or {
      Type = "DATA_LOADED",
      Title = "Welcome Back!",
      Body = "Your data loaded successfully"
    }
    notificationEvent:FireClient(player, msg)
  end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in pairs(Players:GetPlayers()) do task.spawn(function() setupPlayer(player) end) end

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
      if data then DataStoreManager:SaveData(player, data) end
    end
  end
end)

game:BindToClose(function()
  for _, player in pairs(Players:GetPlayers()) do
    local data = PlayerData[player.UserId]
    if data then DataStoreManager:SaveData(player, data) end
  end
  task.wait(3)
end)

_G.PlayerData = PlayerData

local getInventoryFunction = remoteEventsFolder:FindFirstChild("GetInventoryFunction") or Instance.new("RemoteFunction")
getInventoryFunction.Name = "GetInventoryFunction"
getInventoryFunction.Parent = remoteEventsFolder

getInventoryFunction.OnServerInvoke = function(player)
  local attempts = 0
  while not _G.PlayerData[player.UserId] and attempts < 10 do
    attempts += 1
    task.wait(0.1)
  end

  local success, result = pcall(function()
    return DataStoreAPI:GetInventory(player)
  end)
  if not success or not result then return {} end
  return result
end

local inventoryUpdatedEvent = Instance.new("RemoteEvent")
inventoryUpdatedEvent.Name = "InventoryUpdatedEvent"
inventoryUpdatedEvent.Parent = remoteEventsFolder

local getPlayerInventoryFunction = remoteEventsFolder:FindFirstChild("GetPlayerInventoryFunction") or
Instance.new("RemoteFunction")
getPlayerInventoryFunction.Name = "GetPlayerInventoryFunction"
getPlayerInventoryFunction.Parent = remoteEventsFolder

getPlayerInventoryFunction.OnServerInvoke = function(player, targetUserId)
  if type(targetUserId) ~= "number" then
    return { success = false, error = "Invalid user ID" }
  end
  local attempts = 0
  while not _G.PlayerData[targetUserId] and attempts < 10 do
    attempts += 1
    task.wait(0.1)
  end
  if not _G.PlayerData[targetUserId] then
    return { success = false, error = "Player data not loaded" }
  end
  local success, result = pcall(function()
    return DataStoreAPI:GetPlayerInventoryByUserId(targetUserId)
  end)
  if not success or not result then
    return { success = false, error = "Failed to retrieve inventory" }
  end
  return { success = true, inventory = result }
end
