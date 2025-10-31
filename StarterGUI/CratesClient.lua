-- CratesClient.lua
-- Client-side crate opening system with item database integration

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local rollCrateEvent = remoteEvents:WaitForChild("RollCrateEvent")
local crateOpenedEvent = remoteEvents:WaitForChild("CrateOpenedEvent")

-- Get ItemRarityModule
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

-- GUI Elements
local openedGui = script.Parent:WaitForChild("OpenedCrateGui")
openedGui.Enabled = false

local openedFrame = openedGui:WaitForChild("CrateFrame")
openedFrame.Visible = false

local closeOpenedBtn = openedFrame:WaitForChild("ContinueButton")
local openedItemsFrame = openedFrame:WaitForChild("ItemsFrame")

-- Templates under CratesClient LocalScript
local openingCrateItemTemplate = script:WaitForChild("OpeningCrateItemFrame")

local rnd = Random.new()

-- Roll button (in MainUI)
local mainUI = player.PlayerGui:WaitForChild("MainUI")
local rollButton = mainUI:WaitForChild("Roll")

-- Helper functions
function lerp(a, b, t)
  return a + (b - a) * t
end

function tweenGraph(x, pow)
  x = math.clamp(x, 0, 1)
  return 1 - (1 - x) ^ pow
end

-- Close button functionality
closeOpenedBtn.MouseButton1Click:Connect(function()
  openedFrame.Visible = false
  openedGui.Enabled = false

  -- Clear items
  for _, child in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do
    if child:IsA("Frame") or child:IsA("ImageLabel") then
      child:Destroy()
    end
  end

  -- Re-enable roll button (in case it wasn't already)
  rollButton.Text = "[ROLL]"
  rollButton.Active = true
end)

-- Roll button click
rollButton.MouseButton1Click:Connect(function()
  -- Check if already opening
  if openedFrame.Visible == true then
    return
  end

  -- Disable button and change text
  rollButton.Text = "[ROLLING]"
  rollButton.Active = false

  -- Fire server to request roll
  rollCrateEvent:FireServer()
end)

-- Handle crate opening animation
crateOpenedEvent.OnClientEvent:Connect(function(allItems, chosenItem, unboxTime)

  -- allItems is an array of items for the animation
  -- chosenItem is the actual item the player won
  
  print("🎰 Starting crate animation")
  print("🎯 Chosen item: " .. chosenItem.Name .. " (" .. chosenItem.Rarity .. ")")

  local numItems = 100  -- Fixed number for consistent scroll
  local chosenPosition = 25  -- Position where chosen item will appear

  -- Create item frames for animation
  for i = 1, numItems do
    local itemData
    
    if i == chosenPosition then
      -- This position gets the actual chosen item
      itemData = chosenItem
      print("✓ Placed chosen item at position " .. i)
    else
      -- All other positions get random items from allItems
      local randomIndex = rnd:NextInteger(1, #allItems)
      itemData = allItems[randomIndex]
    end

    local newItemFrame = openingCrateItemTemplate:Clone()
    newItemFrame.Name = "Item_" .. i

    -- Set item name
    if newItemFrame:FindFirstChild("ItemName") then
      newItemFrame.ItemName.Text = itemData.Name
      local rarityColor = ItemRarityModule:GetRarityColor(itemData.Value)
      newItemFrame.ItemName.TextColor3 = rarityColor
    end

    -- Set item image using Roblox thumbnail
    if newItemFrame:FindFirstChild("ItemImage") then
      local itemImage = newItemFrame.ItemImage
      if itemImage:IsA("ImageLabel") then
        itemImage.Image = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150"

        -- Set border color based on rarity
        local rarityColor = ItemRarityModule:GetRarityColor(itemData.Value)
        if itemImage:FindFirstChild("UIStroke") then
          itemImage.UIStroke.Color = rarityColor
        end
      end
    end

    newItemFrame.Parent = openedItemsFrame.ItemsContainer
  end

  -- Reset position
  openedItemsFrame.ItemsContainer.Position = UDim2.new(0, 0, 0.5, 0)

  -- Calculate animation parameters
  local cellSize = openingCrateItemTemplate.Size.X.Scale
  local padding = openedItemsFrame.ItemsContainer.UIListLayout.Padding.Scale
  local pos1 = 0.5 - cellSize / 2
  local nextOffset = -cellSize - padding

  local posFinal = pos1 + (chosenPosition - 1) * nextOffset
  local rndOffset = 0  -- No random offset - lands exactly on chosen item

  local timeOpened = tick()

  -- Show opening frame
  openedFrame.CrateName.Text = "Opening Case..."
  closeOpenedBtn.Visible = false
  openedFrame.Visible = true
  openedGui.Enabled = true

  -- Use consistent animation speed (easing power)
  local pow = 2.5  -- Fixed easing for consistent animation speed
  local lastSlot = 0

  -- Animation loop
  while true do
    local timeSinceOpened = tick() - timeOpened
    local x = timeSinceOpened / unboxTime

    local t = tweenGraph(x, pow)
    local newXPos = lerp(0, posFinal, t)

    local currentSlot = math.abs(math.floor((newXPos + rndOffset) / cellSize)) + 1
    if currentSlot ~= lastSlot then
      if script:FindFirstChild("TickSound") then
        script.TickSound:Play()
      end
      lastSlot = currentSlot
    end

    openedItemsFrame.ItemsContainer.Position = UDim2.new(newXPos, 0, 0.5, 0)

    if x >= 1 then
      break
    end

    RunService.Heartbeat:Wait()
  end

  -- Show won item
  openedFrame.CrateName.Text = "You won: " .. chosenItem.Name .. " (" .. chosenItem.Rarity .. ")!"
  closeOpenedBtn.Visible = true

  -- Re-enable roll button
  rollButton.Text = "[ROLL]"
  rollButton.Active = true
end)

print("✅ Crates Client loaded!")
