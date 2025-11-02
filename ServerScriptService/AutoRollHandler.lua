local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreAPI = require(script.Parent.DataStoreAPI)

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
end

local setAutoRollEvent = remoteEventsFolder:FindFirstChild("SetAutoRollEvent")
if not setAutoRollEvent then
  setAutoRollEvent = Instance.new("RemoteEvent")
  setAutoRollEvent.Name = "SetAutoRollEvent"
  setAutoRollEvent.Parent = remoteEventsFolder
end

local getAutoRollFunction = remoteEventsFolder:FindFirstChild("GetAutoRollFunction")
if not getAutoRollFunction then
  getAutoRollFunction = Instance.new("RemoteFunction")
  getAutoRollFunction.Name = "GetAutoRollFunction"
  getAutoRollFunction.Parent = remoteEventsFolder
end

local serverShutdownEvent = remoteEventsFolder:FindFirstChild("ServerShutdownEvent")
if not serverShutdownEvent then
  serverShutdownEvent = Instance.new("RemoteEvent")
  serverShutdownEvent.Name = "ServerShutdownEvent"
  serverShutdownEvent.Parent = remoteEventsFolder
end

local setHideRollsEvent = remoteEventsFolder:FindFirstChild("SetHideRollsEvent")
if not setHideRollsEvent then
  setHideRollsEvent = Instance.new("RemoteEvent")
  setHideRollsEvent.Name = "SetHideRollsEvent"
  setHideRollsEvent.Parent = remoteEventsFolder
end

local getHideRollsFunction = remoteEventsFolder:FindFirstChild("GetHideRollsFunction")
if not getHideRollsFunction then
  getHideRollsFunction = Instance.new("RemoteFunction")
  getHideRollsFunction.Name = "GetHideRollsFunction"
  getHideRollsFunction.Parent = remoteEventsFolder
end

setAutoRollEvent.OnServerEvent:Connect(function(player, enabled)
  if type(enabled) ~= "boolean" then
    return
  end

  DataStoreAPI:SetAutoRoll(player, enabled)
end)

getAutoRollFunction.OnServerInvoke = function(player)
  return DataStoreAPI:GetAutoRoll(player)
end

setHideRollsEvent.OnServerEvent:Connect(function(player, enabled)
  if type(enabled) ~= "boolean" then
    return
  end

  DataStoreAPI:SetHideRolls(player, enabled)
end)

getHideRollsFunction.OnServerInvoke = function(player)
  return DataStoreAPI:GetHideRolls(player)
end

game:BindToClose(function()
  print("Server is shutting down - enabling AutoRoll for all players")
  
  for _, player in pairs(Players:GetPlayers()) do
    DataStoreAPI:SetAutoRoll(player, true)
    
    pcall(function()
      serverShutdownEvent:FireClient(player)
    end)
  end
  
  wait(1)
end)

print("AutoRollHandler (with HideRolls) loaded successfully")
