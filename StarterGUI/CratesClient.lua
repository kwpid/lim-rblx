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

-- Wait for or create UpdateCrateResult event
local updateResultEvent = remoteEvents:FindFirstChild("UpdateCrateResult")
if not updateResultEvent then
  updateResultEvent = Instance.new("RemoteEvent")
  updateResultEvent.Name = "UpdateCrateResult"
  updateResultEvent.Parent = remoteEvents
end

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
local autoRollButton = mainUI:WaitForChild("AutoRoll")

-- Auto-roll variables
local isAutoRolling = false
local isCurrentlyRolling = false
local currentChosenItem = nil
local shouldStopAutoRoll = false -- Flag to stop after current roll finishes

local function stopAutoRoll()
  isAutoRolling = false
  shouldStopAutoRoll = false
  autoRollButton.Text = "[AUTOROLL: OFF]"
  autoRollButton.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red when off
end

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

  -- Always show buttons again
  rollButton.Visible = true
  autoRollButton.Visible = true
end)

-- Roll button click
rollButton.MouseButton1Click:Connect(function()
  -- Check if already opening
  if isCurrentlyRolling then
    return
  end

  isCurrentlyRolling = true

  -- Hide roll button but keep autoroll button visible
  rollButton.Visible = false

  -- Fire server to request roll
  rollCrateEvent:FireServer()
end)

-- Auto-roll button click (toggle on/off)
autoRollButton.MouseButton1Click:Connect(function()
  -- Toggle autoroll state
  isAutoRolling = not isAutoRolling

  if isAutoRolling then
    -- Turn ON autoroll
    autoRollButton.Text = "[AUTOROLL: ON]"
    autoRollButton.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green when on
    shouldStopAutoRoll = false

    -- Start first roll if not already rolling
    if not isCurrentlyRolling then
      isCurrentlyRolling = true
      rollButton.Visible = false
      rollCrateEvent:FireServer()
    end
  else
    -- Turn OFF autoroll (will stop after current roll finishes)
    if isCurrentlyRolling then
      -- Mark to stop after current roll completes
      shouldStopAutoRoll = true
      autoRollButton.Text = "[AUTOROLL: OFF]"
      autoRollButton.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red when off
    else
      -- Not rolling, stop immediately
      stopAutoRoll()
    end
  end
end)

-- Handle crate opening animation
crateOpenedEvent.OnClientEvent:Connect(function(allItems, chosenItem, unboxTime)
  -- allItems is an array of items for the animation
  -- chosenItem is the actual item the player won


  -- Clear any existing items from previous roll
  for _, child in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do
    if child:IsA("Frame") or child:IsA("ImageLabel") then
      child:Destroy()
    end
  end

  local numItems = 100      -- Fixed number for consistent scroll
  local chosenPosition = 25 -- Position where chosen item will appear

  -- Create item frames for animation
  for i = 1, numItems do
    local itemData

    if i == chosenPosition then
      -- This position gets the actual chosen item
      itemData = chosenItem
    else
      -- All other positions get random items from allItems
      local randomIndex = rnd:NextInteger(1, #allItems)
      itemData = allItems[randomIndex]
    end

    local newItemFrame = openingCrateItemTemplate:Clone()
    newItemFrame.Name = "Item_" .. i

    -- Set item name with rarity color
    if newItemFrame:FindFirstChild("ItemName") then
      newItemFrame.ItemName.Text = itemData.Name
      -- Get rarity color based on value
      local rarityColor = ItemRarityModule:GetRarityColor(itemData.Value)
      newItemFrame.ItemName.TextColor3 = rarityColor
      -- Debug log to verify coloring
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
  local rndOffset = 0 -- No random offset - lands exactly on chosen item

  local timeOpened = tick()

  -- Show opening frame
  openedFrame.CrateName.Text = "Rolling..."
  closeOpenedBtn.Visible = false -- Always hide at start
  openedFrame.Visible = true
  openedGui.Enabled = true

  -- Use consistent animation speed (easing power)
  local pow = 2.5 -- Fixed easing for consistent animation speed
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

  -- Store chosen item for serial number update
  currentChosenItem = chosenItem

  -- Show won item (serial number will be added later if it's a stock item)
  openedFrame.CrateName.Text = "You won: " .. chosenItem.Name .. " (" .. chosenItem.Rarity .. ")!"

  -- Always show continue button after every roll
  closeOpenedBtn.Visible = true

  -- Mark rolling as complete
  isCurrentlyRolling = false

  -- Show roll button again
  rollButton.Visible = true

  -- Handle auto-roll
  if isAutoRolling and not shouldStopAutoRoll then
    -- Continue auto-rolling
    -- Wait a moment before next roll
    task.delay(1.5, function()
      if isAutoRolling and not isCurrentlyRolling and not shouldStopAutoRoll then
        -- Hide the crate result and start next roll
        openedFrame.Visible = false

        -- Clear items for next animation
        for _, child in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do
          if child:IsA("Frame") or child:IsA("ImageLabel") then
            child:Destroy()
          end
        end

        -- Start next roll
        isCurrentlyRolling = true
        rollButton.Visible = false
        rollCrateEvent:FireServer()
      end
    end)
  elseif shouldStopAutoRoll then
    -- User requested to stop, turn off autoroll
    stopAutoRoll()
  end
end)

-- Handle serial number update from server (for stock items)
updateResultEvent.OnClientEvent:Connect(function(serialNumber)
  if currentChosenItem and serialNumber then
    -- Update the display to show serial number
    openedFrame.CrateName.Text = "You won: " ..
        currentChosenItem.Name .. " (#" .. serialNumber .. ") (" .. currentChosenItem.Rarity .. ")!"
  end
end)

-- Initialize autoroll button color to red (off state)
autoRollButton.TextColor3 = Color3.fromRGB(255, 0, 0)

-- Handle chat notifications (server-wide and cross-server)
local chatNotificationEvent = remoteEvents:WaitForChild("ChatNotificationEvent")
chatNotificationEvent.OnClientEvent:Connect(function(message)
  -- Display the formatted message in this player's chat
  local TextChatService = game:GetService("TextChatService")
  local generalChannel = TextChatService:FindFirstChild("TextChannels"):FindFirstChild("RBXGeneral")
  
  if generalChannel then
    -- Display the message in this player's chat
    generalChannel:DisplaySystemMessage(message)
  end
end)

print("Crates Client loaded!")
