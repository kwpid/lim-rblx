local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))
local MasteryCollections = require(ReplicatedStorage:WaitForChild("MasteryCollections"))

local GetInventoryFunction = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GetInventoryFunction")
local GetAllItemsFunction = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GetAllItemsFunction")

local MasteryFrame = script.Parent
local Handler = MasteryFrame:WaitForChild("Handler")
local MasteryInfo = MasteryFrame:WaitForChild("Mastery_Info")
local MasteryInfoHandler = MasteryInfo:WaitForChild("Handler")
local MasteryName = MasteryInfo:WaitForChild("Mastery_Name")
local BackButton = MasteryInfo:WaitForChild("Back")
local CloseButton = MasteryFrame:WaitForChild("Close")

local Sample = script:WaitForChild("Sample")
local ItemSample = script:WaitForChild("ItemSample")

local playerInventory = {}
local itemDatabase = {}
local currentCollection = nil

local function getPlayerInventory()
        local success, inventory = pcall(function()
                return GetInventoryFunction:InvokeServer()
        end)
        
        if success and inventory then
                playerInventory = inventory
        else
                warn("Failed to get player inventory for Mastery system")
                playerInventory = {}
        end
end

local function getItemDatabase()
        local success, database = pcall(function()
                return GetAllItemsFunction:InvokeServer()
        end)
        
        if success and database then
                itemDatabase = database
        else
                warn("Failed to get item database for Mastery system")
                itemDatabase = {}
        end
end

local function playerOwnsItem(robloxId)
        for _, item in ipairs(playerInventory) do
                if item.RobloxId == robloxId then
                        return true
                end
        end
        return false
end

local function getItemFromDatabase(robloxId)
        for _, item in ipairs(itemDatabase) do
                if item.RobloxId == robloxId then
                        return item
                end
        end
        return nil
end

local function calculateCollectionProgress(collection)
        if #collection.Items == 0 then
                return 0, 0
        end
        
        local owned = 0
        for _, itemId in ipairs(collection.Items) do
                if playerOwnsItem(itemId) then
                        owned = owned + 1
                end
        end
        
        local percentage = math.floor((owned / #collection.Items) * 100)
        return owned, percentage
end

local function clearHandler(handler)
        for _, child in ipairs(handler:GetChildren()) do
                if child:IsA("GuiObject") then
                        child:Destroy()
                end
        end
end

local function showCollectionDetails(collection)
        currentCollection = collection
        clearHandler(MasteryInfoHandler)
        
        MasteryName.Text = collection.Name
        
        if #collection.Items == 0 then
                warn("Collection '" .. collection.Name .. "' has no items configured")
        end
        
        local totalInverseValue = 0
        for _, item in ipairs(itemDatabase) do
                if item.Rarity ~= "Limited" then
                        totalInverseValue = totalInverseValue + (1 / (item.Value ^ 0.9))
                end
        end
        
        local itemsFound = 0
        for _, itemId in ipairs(collection.Items) do
                local itemData = getItemFromDatabase(itemId)
                if itemData then
                        local itemButton = ItemSample:Clone()
                        itemButton.Name = itemData.Name
                        itemButton.Visible = true
                        
                        itemButton:WaitForChild("Name").Text = itemData.Name
                        
                        local rollPercent
                        if itemData.Rarity == "Limited" then
                                rollPercent = 0
                                itemButton:WaitForChild("Roll").Text = "Not Rollable"
                        else
                                rollPercent = ItemRarityModule:GetRollPercentage(itemData.Value, totalInverseValue)
                                itemButton:WaitForChild("Roll").Text = string.format("%.4f%%", rollPercent)
                        end
                        
                        local imageLabel = itemButton:WaitForChild("ImageLabel")
                        imageLabel.Image = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150"
                        
                        local uiStroke = itemButton:FindFirstChildOfClass("UIStroke")
                        if uiStroke then
                                uiStroke.Color = ItemRarityModule:GetRarityColor(itemData.Rarity)
                        end
                        
                        local lockedFrame = itemButton:WaitForChild("LockedFrame")
                        if playerOwnsItem(itemId) then
                                lockedFrame.Visible = false
                        else
                                lockedFrame.Visible = true
                        end
                        
                        itemButton.Parent = MasteryInfoHandler
                        itemsFound = itemsFound + 1
                else
                        warn("Item ID " .. itemId .. " not found in database for collection '" .. collection.Name .. "'")
                end
        end
        
        print("Loaded " .. itemsFound .. " items for collection: " .. collection.Name)
        
        MasteryInfo.Visible = true
end

local function populateCollections()
        clearHandler(Handler)
        
        for _, collection in ipairs(MasteryCollections.Collections) do
                local collectionButton = Sample:Clone()
                collectionButton.Name = collection.Name
                collectionButton.Visible = true
                
                collectionButton:WaitForChild("Name").Text = collection.Name
                
                local imageLabel = collectionButton:WaitForChild("ImageLabel")
                imageLabel.Image = collection.ImageId
                
                local owned, percentage = calculateCollectionProgress(collection)
                
                local bar = collectionButton:WaitForChild("Bar")
                local filled = bar:WaitForChild("Filled")
                local percentLabel = bar:WaitForChild("Percent")
                
                percentLabel.Text = percentage .. "%"
                
                if percentage == 0 then
                        filled.Size = UDim2.new(0, 0, 1, 0)
                else
                        filled.Size = UDim2.new(percentage / 100, 0, 1, 0)
                end
                
                collectionButton.MouseButton1Click:Connect(function()
                        showCollectionDetails(collection)
                end)
                
                collectionButton.Parent = Handler
        end
end

local function hideCollectionDetails()
        currentCollection = nil
        MasteryInfo.Visible = false
        clearHandler(MasteryInfoHandler)
end

BackButton.MouseButton1Click:Connect(function()
        hideCollectionDetails()
end)

CloseButton.MouseButton1Click:Connect(function()
        MasteryFrame.Visible = false
end)

local function initialize()
        getItemDatabase()
        getPlayerInventory()
        
        wait(0.5)
        
        populateCollections()
end

initialize()

local InventoryUpdatedEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("InventoryUpdatedEvent")
InventoryUpdatedEvent.OnClientEvent:Connect(function()
        getPlayerInventory()
        populateCollections()
        
        if MasteryInfo.Visible and currentCollection then
                showCollectionDetails(currentCollection)
        end
end)
