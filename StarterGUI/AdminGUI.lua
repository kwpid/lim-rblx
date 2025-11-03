local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local gui = script.Parent

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local checkAdminFunction = remoteEvents:WaitForChild("CheckAdminFunction")
local createItemEvent = remoteEvents:WaitForChild("CreateItemEvent")

local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

local getAllItemsFunction = remoteEvents:WaitForChild("GetAllItemsFunction")

local openAdminButton = gui:WaitForChild("Open_Admin")
local uiFrame = gui:WaitForChild("UIFrame")
local itemPreview = uiFrame:WaitForChild("ItemPreview"):WaitForChild("ActualPreview")
local itemIdBox = uiFrame:WaitForChild("Item_Id")
local itemNameBox = uiFrame:WaitForChild("Item_Name")
local itemValueBox = uiFrame:WaitForChild("Item_Value")
local itemStockBox = uiFrame:WaitForChild("Item_Stock_Optional")
local createButton = uiFrame:WaitForChild("CreateItem")
local limitedToggle = uiFrame:WaitForChild("LimitedToggle")

local isEditMode = false
local isLimitedEnabled = false

local giveItemIdBox = uiFrame:WaitForChild("Give_Item_Id")
local giveItemAmountBox = uiFrame:WaitForChild("Give_Item_Amount")
local playerIdBox = uiFrame:WaitForChild("Player_Id")
local giveItemButton = uiFrame:WaitForChild("GiveItem")

local deleteItemIdBox = uiFrame:WaitForChild("Delete_Item_Id")
local deleteItemButton = uiFrame:WaitForChild("DeleteItem")

local getItemByRobloxIdFunction = remoteEvents:FindFirstChild("GetItemByRobloxIdFunction")

local infoPreview = uiFrame:FindFirstChild("info_preview")
local deleteName = uiFrame:FindFirstChild("delete_name")

uiFrame.Visible = false

local isAdmin = checkAdminFunction:InvokeServer()

if isAdmin then
  openAdminButton.Visible = true
else
  openAdminButton.Visible = false
  gui.Enabled = false
  return
end

openAdminButton.MouseButton1Click:Connect(function()
  uiFrame.Visible = not uiFrame.Visible
end)

local function calculateRollPercentageForValue(itemValue)
  local success, allItems = pcall(function()
    return getAllItemsFunction:InvokeServer()
  end)

  if not success or not allItems or type(allItems) ~= "table" then
    return 0
  end

  local totalInverseValue = 0
  for _, item in ipairs(allItems) do
    totalInverseValue = totalInverseValue + (1 / (item.Value ^ 0.75))
  end

  totalInverseValue = totalInverseValue + (1 / (itemValue ^ 0.75))

  return ItemRarityModule:GetRollPercentage(itemValue, totalInverseValue)
end

limitedToggle.MouseButton1Click:Connect(function()
  isLimitedEnabled = not isLimitedEnabled

  if isLimitedEnabled then
    limitedToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    limitedToggle.Text = "Limited: ON"
  else
    limitedToggle.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
    limitedToggle.Text = "Limited: OFF"
  end
end)

itemIdBox:GetPropertyChangedSignal("Text"):Connect(function()
  local idText = itemIdBox.Text
  local itemId = tonumber(idText)

  if itemId then
    local success, allItems = pcall(function()
      return getAllItemsFunction:InvokeServer()
    end)

    if success and allItems and type(allItems) == "table" then
      local existingItem = nil
      for _, item in ipairs(allItems) do
        if item.RobloxId == itemId then
          existingItem = item
          break
        end
      end

      if existingItem then
        isEditMode = true
        createButton.Text = "Edit Item"

        itemNameBox.Text = existingItem.Name
        itemValueBox.Text = tostring(existingItem.Value)
        itemStockBox.Text = existingItem.Stock > 0 and tostring(existingItem.Stock) or ""

        isLimitedEnabled = existingItem.Limited or false
        if isLimitedEnabled then
          limitedToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
          limitedToggle.Text = "Limited: ON"
        else
          limitedToggle.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
          limitedToggle.Text = "Limited: OFF"
        end
      else
        isEditMode = false
        createButton.Text = "CreateItem"
      end
    end

    local productSuccess, productInfo = pcall(function()
      return MarketplaceService:GetProductInfo(itemId)
    end)

    if productSuccess and productInfo then
      itemPreview.Image = "rbxthumb://type=Asset&id=" .. itemId .. "&w=150&h=150"

      if not isEditMode and itemNameBox.Text == "" then
        itemNameBox.Text = productInfo.Name
      end
    else
      itemPreview.Image = ""
    end
  else
    itemPreview.Image = ""
    isEditMode = false
    createButton.Text = "CreateItem"
  end
end)

itemValueBox:GetPropertyChangedSignal("Text"):Connect(function()
  local valueText = itemValueBox.Text
  local itemValue = tonumber(valueText)

  if itemValue and itemValue > 0 and infoPreview then
    local rarity = ItemRarityModule:GetRarity(itemValue)

    local rollPercentage = calculateRollPercentageForValue(itemValue)

    local percentText = string.format("%.2f%%", rollPercentage)

    infoPreview.Text = rarity .. " | " .. percentText
  elseif infoPreview then
    infoPreview.Text = ""
  end
end)

createButton.MouseButton1Click:Connect(function()
  local itemId = tonumber(itemIdBox.Text)
  local itemName = itemNameBox.Text
  local itemValue = tonumber(itemValueBox.Text)
  local itemStock = tonumber(itemStockBox.Text) or 0

  if not itemId then
    warn("item id must be a number")
    return
  end

  if itemName == "" then
    warn("item name cannot be empty")
    return
  end

  if not itemValue or itemValue < 0 then
    warn("item value must be a positive number")
    return
  end

  if itemStock < 0 or itemStock > 100 then
    warn("stock must be between 0 and 100")
    return
  end

  if isEditMode then
    createButton.Text = "Editing..."
  else
    createButton.Text = "Creating..."
  end
  createButton.Active = false

  createItemEvent:FireServer(itemId, itemName, itemValue, itemStock, isLimitedEnabled, isEditMode)
end)

createItemEvent.OnClientEvent:Connect(function(success, message, itemData)
  if success then
    if isEditMode then
      createButton.Text = "✅ Edited!"
    else
      createButton.Text = "✅ Created!"
    end

    itemIdBox.Text = ""
    itemNameBox.Text = ""
    itemValueBox.Text = ""
    itemStockBox.Text = ""
    itemPreview.Image = ""
    if infoPreview then
      infoPreview.Text = ""
    end

    isLimitedEnabled = false
    limitedToggle.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
    limitedToggle.Text = "Limited: OFF"

    isEditMode = false
  else
    warn(message)
    createButton.Text = "❌ Failed"
  end

  task.wait(2)
  createButton.Text = "CreateItem"
  createButton.Active = true
  isEditMode = false
end)

local giveItemEvent = remoteEvents:WaitForChild("GiveItemEvent")
local deleteItemEvent = remoteEvents:WaitForChild("DeleteItemEvent")

giveItemButton.MouseButton1Click:Connect(function()
  local giveItemId = tonumber(giveItemIdBox.Text)
  local giveAmount = tonumber(giveItemAmountBox.Text) or 1
  local playerIdentifier = playerIdBox.Text

  if not giveItemId then
    warn("give item id must be a number")
    return
  end

  if not giveAmount or giveAmount < 1 then
    warn("give amount must be at least 1")
    return
  end

  if playerIdentifier == "" then
    warn("player id or username cannot be empty")
    return
  end

  giveItemButton.Text = "Giving..."
  giveItemButton.Active = false

  giveItemEvent:FireServer(giveItemId, giveAmount, playerIdentifier)
end)

giveItemEvent.OnClientEvent:Connect(function(success, message)
  if success then
    giveItemIdBox.Text = ""
    giveItemAmountBox.Text = ""
    playerIdBox.Text = ""

    giveItemButton.Text = "✅ Given!"
  else
    warn(message)
    giveItemButton.Text = "❌ Failed"
  end

  task.wait(2)
  giveItemButton.Text = "GiveItem"
  giveItemButton.Active = true
end)

local deleteConfirmation = false

deleteItemIdBox:GetPropertyChangedSignal("Text"):Connect(function()
  local deleteIdText = deleteItemIdBox.Text
  local deleteItemId = tonumber(deleteIdText)

  if deleteItemId and deleteName then
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

deleteItemButton.MouseButton1Click:Connect(function()
  local deleteItemId = tonumber(deleteItemIdBox.Text)

  if not deleteItemId then
    warn("delete item id must be a number")
    return
  end

  if not deleteConfirmation then
    deleteConfirmation = true
    deleteItemButton.Text = "Are you sure?"
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(198, 34, 34)

    task.delay(3, function()
      if deleteConfirmation then
        deleteConfirmation = false
        deleteItemButton.Text = "DeleteItem"
        deleteItemButton.BackgroundColor3 = Color3.fromRGB(85, 85, 85)
      end
    end)
  else
    deleteConfirmation = false
    deleteItemButton.Text = "Deleting..."
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(85, 85, 85)
    deleteItemButton.Active = false

    deleteItemEvent:FireServer(deleteItemId)
  end
end)

deleteItemEvent.OnClientEvent:Connect(function(success, message)
  if success then
    deleteItemIdBox.Text = ""
    if deleteName then
      deleteName.Text = ""
    end

    deleteItemButton.Text = "✅ Deleted!"
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(111, 218, 40)
  else
    warn(message)
    deleteItemButton.Text = "❌ Failed"
    deleteItemButton.BackgroundColor3 = Color3.fromRGB(198, 34, 34)
  end

  task.wait(2)
  deleteItemButton.Text = "DeleteItem"
  deleteItemButton.BackgroundColor3 = Color3.fromRGB(85, 85, 85)
  deleteItemButton.Active = true
  deleteConfirmation = false
end)
