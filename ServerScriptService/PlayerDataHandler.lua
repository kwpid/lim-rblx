-- PlayerDataHandler.lua
-- Manages player data when they join/leave

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreManager = require(script.Parent.DataStoreManager)
local DataStoreAPI = require(script.Parent.DataStoreAPI)

-- Table to store active player data in memory
local PlayerData = {}

-- Auto-save interval (in seconds)
local AUTO_SAVE_INTERVAL = 120  -- Save every 2 minutes

-- When a player joins
Players.PlayerAdded:Connect(function(player)
  print("🎮 Player joined: " .. player.Name)

  -- Load their data
  local data = DataStoreManager:LoadData(player)
  PlayerData[player.UserId] = data

  -- Create leaderstats for display
  local leaderstats = Instance.new("Folder")
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player

  local cash = Instance.new("IntValue")
  cash.Name = "Cash"
  cash.Value = data.Cash
  cash.Parent = leaderstats

  local casesOpened = Instance.new("IntValue")
  casesOpened.Name = "Cases Opened"
  casesOpened.Value = data.CasesOpened
  casesOpened.Parent = leaderstats

  local invValue = Instance.new("IntValue")
  invValue.Name = "InvValue"
  invValue.Value = data.InvValue or 0
  invValue.Parent = leaderstats

  -- Listen for changes to update data
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

  -- Calculate initial inventory value
  task.defer(function()
    local totalValue = 0
    for _, item in ipairs(data.Inventory) do
      local itemValue = item.Value or 0
      local amount = item.Amount or 1
      totalValue += (itemValue * amount)
    end
    data.InvValue = totalValue
    invValue.Value = totalValue
  end)

  print("✅ Data loaded for " .. player.Name)
end)

-- When a player leaves
Players.PlayerRemoving:Connect(function(player)
  print("👋 Player leaving: " .. player.Name)

  local data = PlayerData[player.UserId]
  if data then
    -- Save their data
    DataStoreManager:SaveData(player, data)

    -- Remove from active memory
    PlayerData[player.UserId] = nil
  end
end)

-- Auto-save all player data periodically
task.spawn(function()
  while true do
    task.wait(AUTO_SAVE_INTERVAL)

    print("💾 Auto-saving all player data...")
    for _, player in pairs(Players:GetPlayers()) do
      local data = PlayerData[player.UserId]
      if data then
        DataStoreManager:SaveData(player, data)
      end
    end
  end
end)

-- Save all data when server is shutting down
game:BindToClose(function()
  print("🔴 Server shutting down, saving all data...")

  for _, player in pairs(Players:GetPlayers()) do
    local data = PlayerData[player.UserId]
    if data then
      DataStoreManager:SaveData(player, data)
    end
  end

  -- Wait a bit to ensure saves complete
  task.wait(3)
end)

-- Expose PlayerData table for other scripts to access
_G.PlayerData = PlayerData

-- Create RemoteEvents folder if it doesn't exist
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
end

-- Create RemoteFunction for getting inventory
local getInventoryFunction = Instance.new("RemoteFunction")
getInventoryFunction.Name = "GetInventoryFunction"
getInventoryFunction.Parent = remoteEventsFolder

-- Handle inventory requests
getInventoryFunction.OnServerInvoke = function(player)
  return DataStoreAPI:GetInventory(player)
end

-- Create RemoteEvent for inventory updates
local inventoryUpdatedEvent = Instance.new("RemoteEvent")
inventoryUpdatedEvent.Name = "InventoryUpdatedEvent"
inventoryUpdatedEvent.Parent = remoteEventsFolder

print("✅ PlayerDataHandler initialized!")
