-- AntiAFKHandler.lua
-- Automatically rejoins AFK players every 15 minutes to prevent disconnect

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Configuration
local REJOIN_INTERVAL = 15 * 60 -- 15 minutes in seconds

-- Track player rejoin times
local playerRejoinTimers = {}

-- Function to rejoin a player to the current game
local function rejoinPlayer(player)
	if not player or not player.Parent then
		return
	end
	
	local placeId = game.PlaceId
	local success, errorMsg = pcall(function()
		print(string.format("🔄 Auto-rejoining %s to prevent AFK kick...", player.Name))
		TeleportService:Teleport(placeId, player)
	end)
	
	if not success then
		warn(string.format("⚠️ Failed to auto-rejoin %s: %s", player.Name, tostring(errorMsg)))
	end
end

-- Start timer for a player
local function startRejoinTimer(player)
	-- Cancel existing timer if any
	if playerRejoinTimers[player] then
		playerRejoinTimers[player]:Disconnect()
	end
	
	-- Create new timer that rejoins player every 15 minutes
	local timerThread = task.spawn(function()
		while player and player.Parent do
			-- Wait 15 minutes
			task.wait(REJOIN_INTERVAL)
			
			-- Check if player is still in game
			if player and player.Parent then
				rejoinPlayer(player)
				break -- Stop after rejoin (player will get new timer on rejoin)
			end
		end
	end)
	
	playerRejoinTimers[player] = {
		Disconnect = function()
			task.cancel(timerThread)
		end
	}
	
	print(string.format("⏰ Anti-AFK timer started for %s (15min rejoin)", player.Name))
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	-- Start rejoin timer for this player
	startRejoinTimer(player)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	-- Clean up timer
	if playerRejoinTimers[player] then
		playerRejoinTimers[player]:Disconnect()
		playerRejoinTimers[player] = nil
	end
end)

-- Start timers for players already in game
for _, player in ipairs(Players:GetPlayers()) do
	startRejoinTimer(player)
end

print("✅ Anti-AFK Handler loaded - players will auto-rejoin every 15 minutes")
