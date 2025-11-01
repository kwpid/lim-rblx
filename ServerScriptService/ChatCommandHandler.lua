-- ChatCommandHandler.lua
-- Handles chat commands for admins

local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local AdminConfig = require(script.Parent.AdminConfig)
local EventSystem = require(script.Parent.EventSystem)

-- Listen for chat messages
TextChatService.MessageReceived:Connect(function(message)
  local player = Players:GetPlayerByUserId(message.TextSource.UserId)
  if not player then return end
  
  -- Check if player is admin
  if not AdminConfig:IsAdmin(player) then
    return
  end
  
  local text = message.Text
  
  -- Check for event spawn command: /spawn event_[event_name]
  if text:sub(1, 13) == "/spawn event_" then
    local eventName = text:sub(14)
    
    -- Try to start the event
    local success = EventSystem:StartEvent(eventName)
    
    if success then
      -- Send confirmation message to admin
      TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(
        "[ADMIN] Started event: " .. eventName
      )
    else
      TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(
        "[ADMIN] Failed to start event: " .. eventName .. " (not found or already running)"
      )
    end
  end
end)

print("✅ ChatCommandHandler initialized")
