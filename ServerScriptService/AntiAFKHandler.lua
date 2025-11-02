local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Config: Auto-rejoin after 15 minutes of inactivity
local AFK_TIME_LIMIT = 15 * 60
local POSITION_CHECK_INTERVAL = 5
local MOVEMENT_THRESHOLD = 5

local playerData = {}

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

local function hasPlayerMoved(character, lastPosition)
        if not character or not character.PrimaryPart then
                return false
        end
        
        local currentPosition = character.PrimaryPart.Position
        local distance = (currentPosition - lastPosition).Magnitude
        
        return distance > MOVEMENT_THRESHOLD
end

local function startAFKDetection(player)
        local character = player.Character or player.CharacterAdded:Wait()
        
        local rootPart = character:WaitForChild("HumanoidRootPart", 10)
        if not rootPart then
                warn("⚠️ HumanoidRootPart not found for " .. player.Name)
                return
        end
        
        playerData[player] = {
                lastPosition = rootPart.Position,
                lastMoveTime = tick(),
                checkThread = nil
        }
        
        local checkThread = task.spawn(function()
                while player and player.Parent and playerData[player] do
                        task.wait(POSITION_CHECK_INTERVAL)
                        
                        character = player.Character
                        if character and character.PrimaryPart then
                                if hasPlayerMoved(character, playerData[player].lastPosition) then
                                        playerData[player].lastPosition = character.PrimaryPart.Position
                                        playerData[player].lastMoveTime = tick()
                                else
                                        local afkDuration = tick() - playerData[player].lastMoveTime
                                        
                                        if afkDuration >= AFK_TIME_LIMIT then
                                                print(string.format("⏰ %s has been AFK for %.1f minutes, rejoining...", 
                                                        player.Name, afkDuration / 60))
                                                rejoinPlayer(player)
                                                break
                                        end
                                end
                        else
                                playerData[player].lastMoveTime = tick()
                        end
                end
        end)
        
        playerData[player].checkThread = checkThread
        
        player.CharacterAdded:Connect(function(newCharacter)
                if not playerData[player] then return end
                
                local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
                if newRootPart then
                        playerData[player].lastPosition = newRootPart.Position
                        playerData[player].lastMoveTime = tick()
                end
        end)
end

Players.PlayerAdded:Connect(function(player)
        task.wait(1)
        startAFKDetection(player)
end)

Players.PlayerRemoving:Connect(function(player)
        if playerData[player] then
                if playerData[player].checkThread then
                        task.cancel(playerData[player].checkThread)
                end
                playerData[player] = nil
        end
end)

for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
                startAFKDetection(player)
        end)
end

print("✅ Anti-AFK Handler loaded (only rejoins inactive players after 15 minutes)")
