local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local viewportFrame = script.Parent:WaitForChild("AvatarViewport")

local camera = Instance.new("Camera")
camera.Parent = viewportFrame
viewportFrame.CurrentCamera = camera

local character = nil
local isDragging = false
local lastMouseX = 0
local currentRotation = 0

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local getEquippedItemsFunction = remoteEvents:WaitForChild("GetEquippedItemsFunction")
local inventoryUpdatedEvent = remoteEvents:WaitForChild("InventoryUpdatedEvent")

local function clearViewport()
        for _, child in ipairs(viewportFrame:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                        child:Destroy()
                end
        end
end

local function updateCamera()
        if character then
                local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then
                        local distance = 5
                        local height = 1
                        local angle = math.rad(currentRotation)
                        
                        local offset = Vector3.new(
                                math.sin(angle) * distance,
                                height,
                                math.cos(angle) * distance
                        )
                        
                        local cameraPosition = humanoidRootPart.Position + offset
                        local lookAtPosition = humanoidRootPart.Position + Vector3.new(0, height, 0)
                        
                        camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
                end
        end
end

local function createAvatarModel()
        clearViewport()
        
        local playerCharacter = player.Character
        if not playerCharacter then
                return
        end
        
        character = playerCharacter:Clone()
        character.Name = "ViewportCharacter"
        character.Parent = viewportFrame
        
        for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                elseif part:IsA("Script") or part:IsA("LocalScript") then
                        part:Destroy()
                end
        end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
                humanoidRootPart.CFrame = CFrame.new(0, 0, 0)
        end
        
        updateCamera()
end

local function refreshEquippedItems()
        task.wait(0.2)
        createAvatarModel()
end

viewportFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDragging = true
                lastMouseX = input.Position.X
        end
end)

viewportFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDragging = false
        end
end)

viewportFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
                local deltaX = input.Position.X - lastMouseX
                lastMouseX = input.Position.X
                
                currentRotation = currentRotation + (deltaX * 0.5)
                
                updateCamera()
        end
end)

player.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 5)
        task.wait(1)
        createAvatarModel()
end)

inventoryUpdatedEvent.OnClientEvent:Connect(function()
        refreshEquippedItems()
end)

local inventoryFrame = script.Parent
inventoryFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if inventoryFrame.Visible then
                createAvatarModel()
        end
end)

if player.Character then
        task.wait(1)
        createAvatarModel()
end
