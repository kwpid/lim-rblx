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

-- Get or create notification event
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

-- Function to setup a player (used for both PlayerAdded and existing players)
local function setupPlayer(player)
  print("🎮 Setting up player: " .. player.Name)

  -- Load their data
  local data = DataStoreManager:LoadData(player)
  
  local dataLoadFailed = false
  if not data then
    warn("❌ CRITICAL: Failed to load data for " .. player.Name)
    warn("⚠️ Check if Studio API Access is enabled in Game Settings > Security")
    data = DataStoreManager:GetDefaultData()
    dataLoadFailed = true
  end
  
  PlayerData[player.UserId] = data

  -- Create leaderstats for display
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

  print("✅ Data loaded for " .. player.Name .. " (Cash: " .. data.Cash .. ", Cases: " .. data.CasesOpened .. ", Inventory: " .. #data.Inventory .. " items)")
  
  -- Send notification after a short delay to ensure client is ready
  task.delay(2, function()
    if dataLoadFailed then
      -- Send error notification
      local notificationData = {
        Type = "DATA_ERROR",
        Title = "Data Load Error",
        Body = "Failed to load your data. Using defaults.",
      }
      notificationEvent:FireClient(player, notificationData)
    else
      -- Send success notification
      local notificationData = {
        Type = "DATA_LOADED",
        Title = "Welcome Back!",
        Body = "Your data loaded successfully",
      }
      notificationEvent:FireClient(player, notificationData)
    end
  end)
end

-- When a player joins
Players.PlayerAdded:Connect(function(player)
  setupPlayer(player)
end)

-- Handle players who joined before the script loaded
for _, player in pairs(Players:GetPlayers()) do
  task.spawn(function()
    setupPlayer(player)
  end)
end

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
local getInventoryFunction = remoteEventsFolder:FindFirstChild("GetInventoryFunction")
if not getInventoryFunction then
  getInventoryFunction = Instance.new("RemoteFunction")
  getInventoryFunction.Name = "GetInventoryFunction"
  getInventoryFunction.Parent = remoteEventsFolder
  print("✅ Created GetInventoryFunction RemoteFunction")
else
  print("✅ GetInventoryFunction already exists")
end

-- Handle inventory requests
getInventoryFunction.OnServerInvoke = function(player)
  print("🔔 OnServerInvoke CALLED!")
  print("📥 GetInventory request from: " .. player.Name)
  
  -- Wait a moment if player data isn't ready yet
  local attempts = 0
  while not _G.PlayerData[player.UserId] and attempts < 10 do
    attempts = attempts + 1
    print("⏳ Waiting for player data... attempt " .. attempts)
    task.wait(0.1)
  end
  
  local success, result = pcall(function()
    return DataStoreAPI:GetInventory(player)
  end)
  
  if not success then
    warn("❌ GetInventory failed for " .. player.Name .. ": " .. tostring(result))
    return {}
  end
  
  if not result then
    warn("❌ GetInventory returned nil for " .. player.Name)
    return {}
  end
  
  print("📤 Sending inventory to " .. player.Name .. ": " .. #result .. " items")
  return result
end

print("✅ GetInventoryFunction.OnServerInvoke is now set!")

-- Create RemoteEvent for inventory updates
local inventoryUpdatedEvent = Instance.new("RemoteEvent")
inventoryUpdatedEvent.Name = "InventoryUpdatedEvent"
inventoryUpdatedEvent.Parent = remoteEventsFolder

print("✅ PlayerDataHandler initialized!")
