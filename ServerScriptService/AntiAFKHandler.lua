local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local AFK_TIME_LIMIT = 15 * 60
local POSITION_CHECK_INTERVAL = 5
local MOVEMENT_THRESHOLD = 5

local playerData = {}

local function rejoinPlayer(player)
        if not player or not player.Parent then
                return
        end

        local notificationEvent = game.ReplicatedStorage:FindFirstChild("RemoteEvents")
        if notificationEvent then
                notificationEvent = notificationEvent:FindFirstChild("CreateNotification")
                if notificationEvent then
                        notificationEvent:FireClient(player, {
                                Type = "ERROR",
                                Title = "AFK Detected",
                                Body = "You've been inactive for too long. Rejoining...",
                        })
                end
        end

        task.wait(2)

        local placeId = game.PlaceId
        local teleportOptions = Instance.new("TeleportOptions")
        teleportOptions.ShouldReserveServer = false
        
        local success, errorMsg = pcall(function()
                TeleportService:TeleportAsync(placeId, {player}, teleportOptions)
        end)

        if not success then
                warn(string.format("Failed to auto-rejoin %s: %s", player.Name, tostring(errorMsg)))
                pcall(function()
                        player:Kick("You were inactive for too long. Please rejoin the game.")
                end)
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
                warn("humanoidrootpart not found for " .. player.Name)
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
