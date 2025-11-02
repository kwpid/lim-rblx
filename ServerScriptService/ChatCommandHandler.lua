local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local AdminConfig = require(script.Parent.AdminConfig)
local EventSystem = require(script.Parent.EventSystem)

TextChatService.MessageReceived:Connect(function(message)
  local player = Players:GetPlayerByUserId(message.TextSource.UserId)
  if not player then return end
  
  if not AdminConfig:IsAdmin(player) then
    return
  end
  
  local text = message.Text
  
  if text:sub(1, 13) == "/spawn event_" then
    local eventName = text:sub(14)
    
    local success = EventSystem:StartEvent(eventName)
    
    if success then
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
