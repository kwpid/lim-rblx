local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local GetCurrentRotationFunction = RemoteEvents:WaitForChild("GetCurrentRotationFunction")
local PurchaseTixItemEvent = RemoteEvents:WaitForChild("PurchaseTixItemEvent")
local ShopRotationEvent = RemoteEvents:WaitForChild("ShopRotationEvent")
local OpenTixShopEvent = RemoteEvents:WaitForChild("OpenTixShopEvent")
local MarketplaceService = game:GetService("MarketplaceService")

local TixShopFrame = script.Parent
local Sample = script:WaitForChild("Sample")
local Handler = TixShopFrame:WaitForChild("Handler")
local Timer = TixShopFrame:WaitForChild("Timer")
local BuyConfirm = TixShopFrame:WaitForChild("BuyConfirm")
local Pop = BuyConfirm:WaitForChild("Pop")
local ConfirmButton = Pop:WaitForChild("Confirm")
local CancelButton = Pop:WaitForChild("Cancel")
local Text1 = Pop:WaitForChild("Text1")
local CloseButton = TixShopFrame:WaitForChild("Close")

local CurrentRotation = {}
local NextRotationTime = 0
local SelectedItem = nil

local function FormatCash(amount)
        if amount >= 1000000000 then
                return "$" .. string.format("%.2f", amount / 1000000000) .. "B"
        elseif amount >= 1000000 then
                return "$" .. string.format("%.2f", amount / 1000000) .. "M"
        elseif amount >= 1000 then
                return "$" .. string.format("%.2f", amount / 1000) .. "K"
        else
                return "$" .. tostring(amount)
        end
end

local function UpdateTimer()
        while true do
                task.wait(1)
                
                local timeLeft = NextRotationTime - os.time()
                if timeLeft < 0 then timeLeft = 0 end
                
                local hours = math.floor(timeLeft / 3600)
                local minutes = math.floor((timeLeft % 3600) / 60)
                local seconds = timeLeft % 60
                
                Timer.Text = string.format("Next Rotation: %02d:%02d:%02d", hours, minutes, seconds)
        end
end

local function ClearItems()
        for _, child in ipairs(Handler:GetChildren()) do
                if child:IsA("Frame") and child ~= Sample then
                        child:Destroy()
                end
        end
end

local function PopulateShop()
        ClearItems()
        
        for _, item in ipairs(CurrentRotation) do
                local itemFrame = Sample:Clone()
                itemFrame.Name = tostring(item.RobloxId)
                itemFrame.Visible = true
                
                local itemImage = itemFrame:WaitForChild("ItemImage")
                local itemName = itemFrame:WaitForChild("ItemName")
                local itemPrice = itemFrame:WaitForChild("ItemPrice")
                local purchaseButton = itemFrame:WaitForChild("Purchase")
                
                itemImage.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. tostring(item.RobloxId) .. "&width=150&height=150"
                
                itemName.Text = item.Name
                itemPrice.Text = FormatCash(item.Price)
                
                purchaseButton.MouseButton1Click:Connect(function()
                        SelectedItem = item
                        Text1.Text = "Are you sure you want to buy " .. item.Name .. " for " .. FormatCash(item.Price) .. "?"
                        BuyConfirm.Visible = true
                end)
                
                itemFrame.Parent = Handler
        end
end

local function LoadRotation()
        local rotation, nextTime = GetCurrentRotationFunction:InvokeServer()
        CurrentRotation = rotation or {}
        NextRotationTime = nextTime or (os.time() + 3600)
        
        PopulateShop()
end

ShopRotationEvent.OnClientEvent:Connect(function(rotation, nextTime)
        CurrentRotation = rotation or {}
        NextRotationTime = nextTime or (os.time() + 3600)
        
        PopulateShop()
        
        local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
        if NotificationEvent then
                game:GetService("ReplicatedStorage").RemoteEvents.NotificationEvent:FireServer("EVENT_START", "Tix Shop has rotated! Check out the new items!")
        end
end)

OpenTixShopEvent.OnClientEvent:Connect(function()
        TixShopFrame.Visible = not TixShopFrame.Visible
        
        if TixShopFrame.Visible then
                LoadRotation()
        end
end)

ConfirmButton.MouseButton1Click:Connect(function()
        if SelectedItem then
                PurchaseTixItemEvent:FireServer(SelectedItem.RobloxId)
                BuyConfirm.Visible = false
                
                local NotificationEvent = RemoteEvents:FindFirstChild("NotificationEvent")
                if NotificationEvent then
                        NotificationEvent:FireServer("SUCCESS", "Successfully purchased " .. SelectedItem.Name .. "!")
                end
                
                SelectedItem = nil
        end
end)

CancelButton.MouseButton1Click:Connect(function()
        BuyConfirm.Visible = false
        SelectedItem = nil
end)

CloseButton.MouseButton1Click:Connect(function()
        TixShopFrame.Visible = false
        BuyConfirm.Visible = false
        SelectedItem = nil
end)

BuyConfirm.Visible = false
TixShopFrame.Visible = false

LoadRotation()
task.spawn(UpdateTimer)
