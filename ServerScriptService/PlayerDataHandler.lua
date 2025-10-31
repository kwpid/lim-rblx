local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreManager = require(script.Parent.DataStoreManager)
local DataStoreAPI = require(script.Parent.DataStoreAPI)

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
  
  PlayerData[player.UserId] = data

  local leaderstats = Instance.new("Folder")
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player

  local cash = Instance.new("IntValue")
  cash.Name = "Cash"
  cash.Value = data.Cash or 0
  cash.Parent = leaderstats

  local casesOpened = Instance.new("IntValue")
  casesOpened.Name = "Cases Opened"
  casesOpened.Value = data.CasesOpened or 0
  casesOpened.Parent = leaderstats

  local invValue = Instance.new("IntValue")
  invValue.Name = "InvValue"
  invValue.Value = data.InvValue or 0
  invValue.Parent = leaderstats

  cash.Changed:Connect(function(newValue)
    if PlayerData[player.UserId] then
      PlayerData[player.UserId].Cash = newValue
    end
  end)

  casesOpened.Changed:Connect(function(newValue)
    if PlayerData[player.UserId] then
      PlayerData[player.UserId].CasesOpened = newValue
    end
  end)

  invValue.Changed:Connect(function(newValue)
    if PlayerData[player.UserId] then
      PlayerData[player.UserId].InvValue = newValue
    end
  end)

  local totalValue = 0
  if data.Inventory then
    for _, item in ipairs(data.Inventory) do
      local itemValue = item.Value or 0
      local amount = item.Amount or 1
      totalValue += (itemValue * amount)
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
