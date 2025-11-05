local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local originalCameraType = nil
local originalCameraSubject = nil
local isPulling = false
local hiddenPlayersData = {}

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local setPlayerCameraEvent = remoteEvents:WaitForChild("SetPlayerCamera")

local function hideOtherPlayers()
        hiddenPlayersData = {}
        
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                        hiddenPlayersData[otherPlayer.UserId] = {}
                        
                        for _, descendant in ipairs(otherPlayer.Character:GetDescendants()) do
                                if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
                                        descendant.LocalTransparencyModifier = 1
                                elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") then
                                        table.insert(hiddenPlayersData[otherPlayer.UserId], {
                                                Object = descendant,
                                                OriginalEnabled = descendant.Enabled
                                        })
                                        descendant.Enabled = false
                                end
                        end
                end
        end
end

local function showOtherPlayers()
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                        for _, descendant in ipairs(otherPlayer.Character:GetDescendants()) do
                                if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
                                        descendant.LocalTransparencyModifier = 0
                                end
                        end
                        
                        local playerData = hiddenPlayersData[otherPlayer.UserId]
                        if playerData then
                                for _, effectData in ipairs(playerData) do
                                        if effectData.Object and effectData.Object.Parent then
                                                effectData.Object.Enabled = effectData.OriginalEnabled
                                        end
                                end
                        end
                end
        end
        
        hiddenPlayersData = {}
end

local function restoreCamera()
        if originalCameraType then
                camera.CameraType = originalCameraType
        end
        if originalCameraSubject then
                camera.CameraSubject = originalCameraSubject
        end
        
        if player.Character and player.Character:FindFirstChild("Humanoid") then
                camera.CameraSubject = player.Character.Humanoid
        end
        
        showOtherPlayers()
        
        originalCameraType = nil
        originalCameraSubject = nil
        isPulling = false
        
        print("📷 Camera restored to player")
end

setPlayerCameraEvent.OnClientEvent:Connect(function(camPart, spawnPart, finalPart, itemModel, primaryPart)
        if camPart and spawnPart and finalPart and itemModel then
                if isPulling then
                        warn("Already pulling from a barrel!")
                        return
                end
                
                if itemModel:GetAttribute("BarrelPullOwner") ~= player.UserId then
                        return
                end
                
                isPulling = true
                
                local success, err = pcall(function()
                        originalCameraType = camera.CameraType
                        originalCameraSubject = camera.CameraSubject
                        
                        camera.CameraType = Enum.CameraType.Scriptable
                        camera.CFrame = camPart.CFrame
                        
                        hideOtherPlayers()
                        
                        print("📷 Camera switched to barrel view")
                        
                        local targetPart = primaryPart
                        
                        if not targetPart then
                                if itemModel:IsA("Accoutrement") or itemModel:IsA("Hat") then
                                        targetPart = itemModel:FindFirstChild("Handle")
                                elseif itemModel:IsA("Model") then
                                        targetPart = itemModel.PrimaryPart or itemModel:FindFirstChild("Handle")
                                elseif itemModel:IsA("BasePart") then
                                        targetPart = itemModel
                                end
                        end
                        
                        if targetPart and targetPart:IsA("BasePart") then
                                if targetPart.CFrame.Position ~= spawnPart.CFrame.Position then
                                        targetPart.CFrame = spawnPart.CFrame
                                end
                                
                                local floatTween = TweenService:Create(
                                        targetPart,
                                        TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                        {CFrame = finalPart.CFrame}
                                )
                                floatTween:Play()
                                
                                task.spawn(function()
                                        for i = 1, 60 do
                                                if not targetPart or not targetPart.Parent then break end
                                                local success = pcall(function()
                                                        targetPart.CFrame = targetPart.CFrame * CFrame.Angles(0, math.rad(6), 0)
                                                end)
                                                if not success then break end
                                                task.wait(0.05)
                                        end
                                end)
                        else
                                warn("⚠️ Could not find valid part to animate for: " .. tostring(itemModel))
                        end
                        
                        task.wait(3)
                end)
                
                if not success then
                        warn("❌ Barrel pull animation error: " .. tostring(err))
                end
                
                restoreCamera()
        end
end)
