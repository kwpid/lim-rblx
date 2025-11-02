local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local AdminConfig = require(script.Parent.AdminConfig)
local EventSystem = require(script.Parent.EventSystem)

local function handleCommand(player, text)
  if not AdminConfig:IsAdmin(player) then
    return
  end
  
  if text:sub(1, 13) == "/spawn event_" then
    local eventName = text:sub(14)
    
    print("🔧 Admin command received from " .. player.Name .. ": /spawn event_" .. eventName)
    
    local success = EventSystem:StartEvent(eventName)
    
    if success then
      print("✅ Event started successfully: " .. eventName)
    else
      warn("❌ Failed to start event: " .. eventName)
    end
    
    return true
  end
  
  return false
end

-- Support for new TextChatService
local textChatSuccess = pcall(function()
  if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(message)
      local player = Players:GetPlayerByUserId(message.TextSource.UserId)
      if not player then return end
      
      handleCommand(player, message.Text)
    end)
    print("✅ ChatCommandHandler initialized (TextChatService)")
  end
end)

-- Support for legacy chat system
if not textChatSuccess then
  Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
      handleCommand(player, message)
    end)
  end)
  
  for _, player in ipairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
      handleCommand(player, message)
    end)
  end
  
  print("✅ ChatCommandHandler initialized (Legacy Chat)")
end
