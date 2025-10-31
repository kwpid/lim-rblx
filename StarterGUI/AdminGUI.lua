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

-- Wait for GiveItemEvent
local giveItemEvent = remoteEvents:WaitForChild("GiveItemEvent")

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
