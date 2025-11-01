-- ServerShutdownHandler.lua
-- Handles server shutdown with auto-rejoin for players

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Configuration
local PLACE_ID = game.PlaceId -- Current game's place ID

-- Function to teleport all players back to the game
local function teleportPlayersOnShutdown()
  local players = Players:GetPlayers()
  
  if #players > 0 then
    print("🔄 Server shutting down - Auto-rejoining " .. #players .. " players...")
    
    -- Create teleport options for better UX
    local teleportOptions = Instance.new("TeleportOptions")
    teleportOptions.ShouldReserveServer = false -- Don't reserve a server, join any available
    
    -- Teleport all players back to the same place (they'll rejoin a new server)
    local success, errorMessage = pcall(function()
      TeleportService:TeleportAsync(PLACE_ID, players, teleportOptions)
    end)
    
    if success then
      print("✅ Players teleported successfully for auto-rejoin")
    else
      warn("⚠️ Failed to teleport players on shutdown: " .. tostring(errorMessage))
      
      -- Fallback: Try teleporting players individually
      for _, player in ipairs(players) do
        local individualSuccess = pcall(function()
          TeleportService:Teleport(PLACE_ID, player)
        end)
        
        if individualSuccess then
          print("✅ " .. player.Name .. " teleported individually")
        else
          warn("⚠️ Failed to teleport " .. player.Name)
        end
      end
    end
    
    -- Wait for teleports to process
    task.wait(5)
  else
    print("ℹ️ No players to teleport on shutdown")
  end
end

-- Bind to server shutdown
game:BindToClose(function()
  print("🛑 Server shutdown initiated - Starting auto-rejoin process...")
  teleportPlayersOnShutdown()
end)

print("✅ Server Shutdown Handler loaded - Auto-rejoin enabled")
