local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local PLACE_ID = game.PlaceId


local function teleportPlayersOnShutdown()
  local players = Players:GetPlayers()

  if #players > 0 then
    local teleportOptions = Instance.new("TeleportOptions")
    teleportOptions.ShouldReserveServer = false
    local success, errorMessage = pcall(function()
      TeleportService:TeleportAsync(PLACE_ID, players, teleportOptions)
    end)
    if success then
      print("players teleported successfully for auto rejoin")
    else
      for _, player in ipairs(players) do
        local individualSuccess = pcall(function()
          TeleportService:Teleport(PLACE_ID, player)
        end)

        if individualSuccess then
          print("" .. player.Name .. " teleported individually")
        else
          warn("⚠Failed to teleport " .. player.Name)
        end
      end
    end

    task.wait(5)
  else
    print("no players to teleport on shutdown")
  end
end

game:BindToClose(function()
  teleportPlayersOnShutdown()
end)
