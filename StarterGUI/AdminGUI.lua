-- AdminGUI.lua
-- Client-side script for the Admin GUI
-- This should be a LocalScript inside the AdminGUI ScreenGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local gui = script.Parent

-- Wait for RemoteEvents to load
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local checkAdminFunction = remoteEvents:WaitForChild("CheckAdminFunction")
local createItemEvent = remoteEvents:WaitForChild("CreateItemEvent")

-- Load the ItemRarityModule
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

-- Wait for GetAllItemsFunction
local getAllItemsFunction = remoteEvents:WaitForChild("GetAllItemsFunction")

-- GUI Elements - Create Item Section
local openAdminButton = gui:WaitForChild("Open_Admin")
local uiFrame = gui:WaitForChild("UIFrame")
local itemPreview = uiFrame:WaitForChild("ItemPreview"):WaitForChild("ActualPreview")
local itemIdBox = uiFrame:WaitForChild("Item_Id")
local itemNameBox = uiFrame:WaitForChild("Item_Name")
local itemValueBox = uiFrame:WaitForChild("Item_Value")
local itemStockBox = uiFrame:WaitForChild("Item_Stock_Optional")
local createButton = uiFrame:WaitForChild("CreateItem")

-- GUI Elements - Give Item Section
local giveItemIdBox = uiFrame:WaitForChild("Give_Item_Id")
local giveItemAmountBox = uiFrame:WaitForChild("Give_Item_Amount")
local playerIdBox = uiFrame:WaitForChild("Player_Id")
local giveItemButton = uiFrame:WaitForChild("GiveItem")

-- GUI Elements - Delete Item Section
local deleteItemIdBox = uiFrame:WaitForChild("Delete_Item_Id")
local deleteItemButton = uiFrame:WaitForChild("DeleteItem")

-- Wait for GetItemByRobloxIdFunction (if it exists)
local getItemByRobloxIdFunction = remoteEvents:FindFirstChild("GetItemByRobloxIdFunction")

-- GUI Elements - Info Preview (optional elements)
local infoPreview = uiFrame:FindFirstChild("info_preview")
local deleteName = uiFrame:FindFirstChild("delete_name")

-- Start with frame hidden
uiFrame.Visible = false

-- Check if player is admin
local isAdmin = checkAdminFunction:InvokeServer()

if isAdmin then
  openAdminButton.Visible = true
else
  openAdminButton.Visible = false
  gui.Enabled = false -- Disable entire GUI for non-admins
  return
end

-- Toggle admin panel
openAdminButton.MouseButton1Click:Connect(function()
  uiFrame.Visible = not uiFrame.Visible
end)

-- Helper function to calculate roll percentage for a single item value
local function calculateRollPercentageForValue(itemValue)
  -- Get all items from the database
  local success, allItems = pcall(function()
    return getAllItemsFunction:InvokeServer()
  end)
  
  if not success or not allItems or type(allItems) ~= "table" then
    return 0
  end
  
  -- Calculate total inverse value
  local totalInverseValue = 0
  for _, item in ipairs(allItems) do
    totalInverseValue = totalInverseValue + (1 / item.Value)
  end
  
  -- Add the new item's inverse value
  totalInverseValue = totalInverseValue + (1 / itemValue)
  
  -- Calculate the percentage for this item
  return ItemRarityModule:GetRollPercentage(itemValue, totalInverseValue)
end

-- Update item preview when ID changes
itemIdBox:GetPropertyChangedSignal("Text"):Connect(function()
  local idText = itemIdBox.Text
  local itemId = tonumber(idText)

  if itemId then
    -- Try to load the item thumbnail
    local success, productInfo = pcall(function()
      return MarketplaceService:GetProductInfo(itemId)
    end)

    if success and productInfo then
      -- Load the image
      itemPreview.Image = "rbxthumb://type=Asset&id=" .. itemId .. "&w=150&h=150"

      -- Auto-fill name if empty
      if itemNameBox.Text == "" then
        itemNameBox.Text = productInfo.Name
      end
    else
      itemPreview.Image = ""
    end
  else
    itemPreview.Image = ""
  end
end)

-- Update info preview when value changes (show rarity and roll %)
itemValueBox:GetPropertyChangedSignal("Text"):Connect(function()
  local valueText = itemValueBox.Text
  local itemValue = tonumber(valueText)
  
  if itemValue and itemValue > 0 and infoPreview then
    -- Get the rarity for this value
    local rarity = ItemRarityModule:GetRarity(itemValue)
    
    -- Calculate the roll percentage
    local rollPercentage = calculateRollPercentageForValue(itemValue)
    
    -- Format the percentage with 2 decimal places
    local percentText = string.format("%.2f%%", rollPercentage)
    
    -- Update the info preview text
    infoPreview.Text = rarity .. " | " .. percentText
  elseif infoPreview then
    infoPreview.Text = ""
  end
end)

-- Create item button
createButton.MouseButton1Click:Connect(function()
  local itemId = tonumber(itemIdBox.Text)
  local itemName = itemNameBox.Text
  local itemValue = tonumber(itemValueBox.Text)
  local itemStock = tonumber(itemStockBox.Text) or 0 -- Default to 0 if empty

  -- Validate inputs
  if not itemId then
    warn("❌ Item ID must be a number!")
    return
  end

  if itemName == "" then
    warn("❌ Item name cannot be empty!")
    return
  end

  if not itemValue or itemValue < 0 then
    warn("❌ Item value must be a positive number!")
    return
  end

  -- Validate stock (0-100)
  if itemStock < 0 or itemStock > 100 then
    warn("❌ Stock must be between 0 and 100!")
    return
  end

  -- Disable button while processing
  createButton.Text = "Creating..."
  createButton.Active = false

  -- Send to server
  createItemEvent:FireServer(itemId, itemName, itemValue, itemStock)
end)

-- Handle server response
createItemEvent.OnClientEvent:Connect(function(success, message, itemData)
  if success then
    -- Clear fields
    itemIdBox.Text = ""
    itemNameBox.Text = ""
    itemValueBox.Text = ""
    itemStockBox.Text = ""
    itemPreview.Image = ""
    if infoPreview then
      infoPreview.Text = ""
    end

    createButton.Text = "✅ Created!"
  else
    warn("❌ " .. message)
    createButton.Text = "❌ Failed"
  end

  -- Reset button after delay
  task.wait(2)
  createButton.Text = "CreateItem"
  createButton.Active = true
end)

-- ═══════════════════════════════════════════════════
-- GIVE ITEM FUNCTIONALITY
-- ═══════════════════════════════════════════════════

-- Wait for GiveItemEvent and DeleteItemEvent
local giveItemEvent = remoteEvents:WaitForChild("GiveItemEvent")
local deleteItemEvent = remoteEvents:WaitForChild("DeleteItemEvent")

-- Give item button
giveItemButton.MouseButton1Click:Connect(function()
  local giveItemId = tonumber(giveItemIdBox.Text)
  local giveAmount = tonumber(giveItemAmountBox.Text) or 1
  local playerIdentifier = playerIdBox.Text

  -- Validate inputs
  if not giveItemId then
    warn("❌ Give Item ID must be a number!")
    return
  end

  if not giveAmount or giveAmount < 1 then
    warn("❌ Give Amount must be at least 1!")
    return
  end

  if playerIdentifier == "" then
    warn("❌ Player ID/Username cannot be empty!")
    return
  end

  -- Disable button while processing
  giveItemButton.Text = "Giving..."
  giveItemButton.Active = false

  -- Send to server
  giveItemEvent:FireServer(giveItemId, giveAmount, playerIdentifier)
end)

-- Handle give item response
giveItemEvent.OnClientEvent:Connect(function(success, message)
  if success then
    -- Clear fields
    giveItemIdBox.Text = ""
    giveItemAmountBox.Text = ""
    playerIdBox.Text = ""

    giveItemButton.Text = "✅ Given!"
  else
    warn("❌ " .. message)
    giveItemButton.Text = "❌ Failed"
  end

  -- Reset button after delay
  task.wait(2)
  giveItemButton.Text = "GiveItem"
  giveItemButton.Active = true
end)

-- ═══════════════════════════════════════════════════
-- DELETE ITEM FUNCTIONALITY
-- ═══════════════════════════════════════════════════

local deleteConfirmation = false

-- Update delete_name when delete item ID changes (show item name)
deleteItemIdBox:GetPropertyChangedSignal("Text"):Connect(function()
  local deleteIdText = deleteItemIdBox.Text
  local deleteItemId = tonumber(deleteIdText)
  
  if deleteItemId and deleteName then
    -- Get all items and find the one with this ID
    local success, allItems = pcall(function()
      return getAllItemsFunction:InvokeServer()
    end)
    
    if success and allItems and type(allItems) == "table" then
      local foundItem = nil
      for _, item in ipairs(allItems) do
        if item.RobloxId == deleteItemId then
          foundItem = item
          break
        end
      end
      
      if foundItem then
        deleteName.Text = foundItem.Name
      else
        deleteName.Text = "Item not found"
      end
    else
      deleteName.Text = ""
    end
  elseif deleteName then
    deleteName.Text = ""
  end
end)

-- Delete item button
deleteItemButton.MouseButton1Click:Connect(function()
  local deleteItemId = tonumber(deleteItemIdBox.Text)

  -- Validate inputs
  if not deleteItemId then
    warn("❌ Delete Item ID must be a number!")
    return
  end

  -- Confirmation system (similar to sell system)
  if not deleteConfirmation then
    -- First click - ask for confirmation
    deleteConfirmation = true
    deleteItemButton.Text = "Are you sure?"
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(198, 34, 34) -- Red

    -- Reset after 3 seconds if not clicked again
    task.delay(3, function()
      if deleteConfirmation then
        deleteConfirmation = false
        deleteItemButton.Text = "DeleteItem"
        deleteItemButton.BackgroundColor3 = Color3.fromRGB(85, 85, 85) -- Default gray
      end
    end)
  else
    -- Second click - confirmed, proceed with deletion
    deleteConfirmation = false
    deleteItemButton.Text = "Deleting..."
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(85, 85, 85)
    deleteItemButton.Active = false

    -- Send to server
    deleteItemEvent:FireServer(deleteItemId)
  end
end)

-- Handle delete item response
deleteItemEvent.OnClientEvent:Connect(function(success, message)
  if success then
    -- Clear fields
    deleteItemIdBox.Text = ""
    if deleteName then
      deleteName.Text = ""
    end

    deleteItemButton.Text = "✅ Deleted!"
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(111, 218, 40) -- Green
  else
    warn("❌ " .. message)
    deleteItemButton.Text = "❌ Failed"
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(198, 34, 34) -- Red
  end

  -- Reset button after delay
  task.wait(2)
  deleteItemButton.Text = "DeleteItem"
  deleteItemButton.BackgroundColor3 = Color3.fromRGB(85, 85, 85) -- Default gray
  deleteItemButton.Active = true
  deleteConfirmation = false
end)
