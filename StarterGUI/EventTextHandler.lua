local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mainUI = playerGui:WaitForChild("MainUI", 10)
if not mainUI then
  warn("mainui not found")
  return
end

local eventText = mainUI:WaitForChild("EventText", 10)
if not eventText then
  warn("eventtext not found in mainui")
  return
end

eventText.Visible = false

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
  warn("remoteevents folder not found")
  return
end

local notificationEvent = remoteEvents:WaitForChild("CreateNotification", 10)
if not notificationEvent then
  warn("createnotification event not found")
  return
end

notificationEvent.OnClientEvent:Connect(function(notificationData)
  if notificationData.Type == "EVENT_START" then
    local eventName = notificationData.Title or "Event"
    eventText.Text = eventName .. " Ongoing!"
    eventText.Visible = true
  elseif notificationData.Type == "EVENT_END" then
    eventText.Visible = false
  end
end)
