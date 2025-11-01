-- AntiAFKHandler.lua
-- Automatically rejoins AFK players (who haven't moved) every 15 minutes to prevent disconnect

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Configuration
local AFK_TIME_LIMIT = 15 * 60 -- 15 minutes in seconds
local POSITION_CHECK_INTERVAL = 5 -- Check position every 5 seconds
local MOVEMENT_THRESHOLD = 5 -- Consider player moved if they moved more than 5 studs

-- Track player data
local playerData = {} -- {lastPosition, lastMoveTime, checkThread}

-- Function to rejoin a player to the current game
local function rejoinPlayer(player)
        if not player or not player.Parent then
                return
        end

        local placeId = game.PlaceId
        local success, errorMsg = pcall(function()
                TeleportService:Teleport(placeId, player)
        end)

        if not success then
                warn(string.format("⚠️ Failed to auto-rejoin %s: %s", player.Name, tostring(errorMsg)))
        else
                print(string.format("🔄 Auto-rejoined AFK player: %s (inactive for 15 minutes)", player.Name))
        end
end

-- Check if player has moved
local function hasPlayerMoved(character, lastPosition)
        if not character or not character.PrimaryPart then
                return false
        end
        
        local currentPosition = character.PrimaryPart.Position
        local distance = (currentPosition - lastPosition).Magnitude
        
        return distance > MOVEMENT_THRESHOLD
end

-- Start AFK detection for a player
local function startAFKDetection(player)
        -- Wait for character to load
        local character = player.Character or player.CharacterAdded:Wait()
        
        -- Wait for HumanoidRootPart
        local rootPart = character:WaitForChild("HumanoidRootPart", 10)
        if not rootPart then
                warn("⚠️ HumanoidRootPart not found for " .. player.Name)
                return
        end
        
        -- Initialize player data
        playerData[player] = {
                lastPosition = rootPart.Position,
                lastMoveTime = tick(),
                checkThread = nil
        }
        
        -- Create monitoring thread
        local checkThread = task.spawn(function()
                while player and player.Parent and playerData[player] do
                        task.wait(POSITION_CHECK_INTERVAL)
                        
                        -- Get current character (in case of respawn)
                        character = player.Character
                        if character and character.PrimaryPart then
                                -- Check if player moved
                                if hasPlayerMoved(character, playerData[player].lastPosition) then
                                        -- Player moved - reset AFK timer
                                        playerData[player].lastPosition = character.PrimaryPart.Position
                                        playerData[player].lastMoveTime = tick()
                                else
                                        -- Player hasn't moved - check if AFK time exceeded
                                        local afkDuration = tick() - playerData[player].lastMoveTime
                                        
                                        if afkDuration >= AFK_TIME_LIMIT then
                                                -- Player is AFK - rejoin them
                                                print(string.format("⏰ %s has been AFK for %.1f minutes, rejoining...", 
                                                        player.Name, afkDuration / 60))
                                                rejoinPlayer(player)
                                                break
                                        end
                                end
                        else
                                -- Character not loaded or no PrimaryPart - reset timer
                                playerData[player].lastMoveTime = tick()
                        end
                end
        end)
        
        playerData[player].checkThread = checkThread
        
        -- Handle character respawn
        player.CharacterAdded:Connect(function(newCharacter)
                if not playerData[player] then return end
                
                local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
                if newRootPart then
                        -- Reset position and timer on respawn
                        playerData[player].lastPosition = newRootPart.Position
                        playerData[player].lastMoveTime = tick()
                end
        end)
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
        -- Wait a bit for player to fully load
        task.wait(1)
        startAFKDetection(player)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
        -- Clean up player data
        if playerData[player] then
                if playerData[player].checkThread then
                        task.cancel(playerData[player].checkThread)
                end
                playerData[player] = nil
        end
end)

-- Start detection for players already in game
for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
                startAFKDetection(player)
        end)
end

print("✅ Anti-AFK Handler loaded (only rejoins inactive players after 15 minutes)")
