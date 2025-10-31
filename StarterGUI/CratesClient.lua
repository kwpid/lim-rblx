-- Variables
local FAST_UNBOX_GAMEPASS_ID = 1242040274 -- Replace with your Gamepass ID
local AUTO_ROLL_GAMEPASS_ID = 1241785029  -- Auto-roll gamepass ID

local EVERYONE_HAS_FAST_ROLL = true


local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local rs = game:GetService("ReplicatedStorage")
local remotes = rs:WaitForChild("RemoteEvents")
local rarityProperties = rs:WaitForChild("RarityProperties")
local items = rs:WaitForChild("Items")
local crates = rs:WaitForChild("Crates")

local shopGui = script.Parent:WaitForChild("CrateShopGui"); shopGui.Enabled = true
local openShopBtn = shopGui:WaitForChild("OpenButton"); openShopBtn.Visible = true
local shopFrame = shopGui:WaitForChild("CrateShopFrame"); shopFrame.Visible = false
local closeShopBtn = shopFrame:WaitForChild("CloseButton")
local cratesList = shopFrame:WaitForChild("CratesList")
local selectedCrate = shopFrame:WaitForChild("SelectedCrate"); selectedCrate.Visible = false

local openedGui = script.Parent:WaitForChild("OpenedCrateGui"); openedGui.Enabled = false
local openedFrame = openedGui:WaitForChild("CrateFrame"); openedFrame.Visible = false
local closeOpenedBtn = openedFrame:WaitForChild("ContinueButton")
local openedItemsFrame = openedFrame:WaitForChild("ItemsFrame")

local crateButtonTemplate = script:WaitForChild("CrateShopButton")
local selectedCrateItemTemplate = script:WaitForChild("SelectedCrateItemFrame")
local openingCrateItemTemplate = script:WaitForChild("OpeningCrateItemFrame")

local rnd = Random.new()
local hasFastUnboxPass = false
local hasAutoRollPass = false
local ShowNotificationEvent = rs:FindFirstChild("ShowNotification")
local selectedCratePrice = 0
local function sendNotification(player, message)
  local StarterGui = game:GetService("StarterGui")

  -- Add a small delay to ensure StarterGui is ready
  task.wait(0.1)

  local success, err = pcall(function()
    StarterGui:SetCore("SendNotification", {
      Title = "Case System",
      Text = message,
      Duration = 5,
    })
  end)

  if not success then
    warn("Notification failed: " .. tostring(err))
    -- Fallback: print to console so you can see it's working
  end
end

local function formatNumber(num)
  if num >= 1e15 then     -- 1 quadrillion+
    return string.format("%.0fQ", num / 1e15)
  elseif num >= 1e14 then -- 100 trillion
    return string.format("%.0fT", num / 1e12)
  elseif num >= 1e13 then -- 10 trillion
    return string.format("%.0fT", num / 1e12)
  elseif num >= 1e12 then -- 1 trillion
    return string.format("%.0fT", num / 1e12)
  elseif num >= 1e11 then -- 100 billion
    return string.format("%.0fB", num / 1e9)
  elseif num >= 1e10 then -- 10 billion
    return string.format("%.0fB", num / 1e9)
  elseif num >= 1e9 then  -- 1 billion
    return string.format("%.0fB", num / 1e9)
  elseif num >= 1000 then -- 1,000+
    local str = tostring(num)
    local formatted = ""
    local count = 0

    -- Add commas from right to left
    for i = #str, 1, -1 do
      if count > 0 and count % 3 == 0 then
        formatted = "," .. formatted
      end
      formatted = str:sub(i, i) .. formatted
      count = count + 1
    end

    return formatted
  else
    return tostring(num)
  end
end
-- Auto-roll variables
local isAutoRolling = false
local autoRollConnection = nil
local lastPlayerPosition = nil

local function checkGamepasses()
  if EVERYONE_HAS_FAST_ROLL then
    hasFastUnboxPass = true
  else
    local success1, hasFast = pcall(function()
      return MarketplaceService:UserOwnsGamePassAsync(player.UserId, FAST_UNBOX_GAMEPASS_ID)
    end)

    if success1 then
      hasFastUnboxPass = hasFast
    else
      warn("Failed to check Fast Unbox Gamepass ownership")
    end
  end

  local success2, hasAuto = pcall(function()
    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, AUTO_ROLL_GAMEPASS_ID)
  end)

  if success2 then
    hasAutoRollPass = hasAuto
  else
    warn("Failed to check Auto-Roll Gamepass ownership")
  end
end

checkGamepasses()

-- Function to check if player moved
local function hasPlayerMoved()
  if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
    return false
  end

  local currentPosition = player.Character.HumanoidRootPart.Position
  if lastPlayerPosition then
    local distance = (currentPosition - lastPlayerPosition).Magnitude
    return distance > 1 -- Threshold for movement detection
  end

  lastPlayerPosition = currentPosition
  return false
end

-- Function to update player position
local function updatePlayerPosition()
  if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
    lastPlayerPosition = player.Character.HumanoidRootPart.Position
  end
end

-- Function to stop auto-roll
local function stopAutoRoll()
  if isAutoRolling then
    isAutoRolling = false
    if autoRollConnection then
      autoRollConnection:Disconnect()
      autoRollConnection = nil
    end

    -- Update button text
    if selectedCrate.Visible then
      selectedCrate.AutoRollButton.Text = "Auto Roll"
      selectedCrate.AutoRollButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255) -- Green
    end
  end
end

-- Function to start auto-roll
local function startAutoRoll()
  if not selectedCrate.Visible then
    return
  end

  local crateName = selectedCrate.CrateName.Text
  local cratePrice = selectedCratePrice -- Use stored price instead of parsing text

  if not crateName or crateName == "" or not cratePrice then
    return
  end

  isAutoRolling = true
  selectedCrate.AutoRollButton.Text = "Stop Auto Roll"
  selectedCrate.AutoRollButton.BackgroundColor3 = Color3.fromRGB(170, 85, 85) -- Red

  -- Update initial position
  updatePlayerPosition()

  -- Auto-roll loop
  autoRollConnection = game:GetService("RunService").Heartbeat:Connect(function()
    -- Check if player moved
    if hasPlayerMoved() then
      -- Wait for current crate opening to finish if one is in progress
      if openedFrame.Visible then
        -- Wait until crate opening is complete
        repeat
          game:GetService("RunService").Heartbeat:Wait()
        until not openedFrame.Visible or not isAutoRolling
      end
      stopAutoRoll()
      return
    end

    -- Check if we have enough cash and no crate is currently opening
    if player.leaderstats.Cash.Value >= cratePrice and not openedFrame.Visible then
      -- Small delay between rolls to prevent issues
      task.wait(0.5)

      -- Double check we still have cash and aren't opening a crate
      if player.leaderstats.Cash.Value >= cratePrice and not openedFrame.Visible and isAutoRolling then
        remotes:WaitForChild("BuyCrate"):FireServer(crateName)
      end
    elseif player.leaderstats.Cash.Value < cratePrice then
      -- Not enough cash, stop auto-roll
      stopAutoRoll()
      sendNotification(player, "You don't have enough cash!")
    end
  end)
end

-- Setup item preview
local function setupItemViewport(viewportFrame, itemSource)
  local itemModel = Instance.new("Model")
  itemModel.Name = itemSource.Name

  local thumbCam = itemSource:FindFirstChildWhichIsA("Camera")

  for _, child in pairs(itemSource:GetChildren()) do
    if not (child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") or child:IsA("Sound")) then
      local cloned = child:Clone()
      cloned.Parent = itemModel
    end
  end

  itemModel:PivotTo(CFrame.Angles(0, math.rad(180), 0))

  itemModel.Parent = viewportFrame

  if thumbCam then
    local clonedCam = thumbCam:Clone()
    clonedCam.Parent = viewportFrame
    viewportFrame.CurrentCamera = clonedCam
  else
    local fallbackCam = Instance.new("Camera")
    local center = itemModel:GetPivot().Position
    local offset = Vector3.new(1.2, 1.2, 2.2) -- Closer view
    fallbackCam.CFrame = CFrame.new(center + offset, center)
    fallbackCam.Parent = viewportFrame
    viewportFrame.CurrentCamera = fallbackCam
  end
end

-- Function to handle crate opening completion (auto-continue during auto-roll)
local function handleCrateOpeningComplete()
  if isAutoRolling then
    -- Auto-continue during auto-roll
    task.wait(0.5) -- Small delay to see the result

    -- Simulate the continue button click by executing the same logic
    openedFrame.Visible = false
    openedGui.Enabled = false

    for _, child in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do
      if child:IsA("Frame") then
        child:Destroy()
      end
    end
  end
end

-- Open and close buttons
openShopBtn.MouseButton1Click:Connect(function()
  if not openedFrame.Visible then
    shopFrame.Visible = not shopFrame.Visible
  end
end)

closeShopBtn.MouseButton1Click:Connect(function()
  shopFrame.Visible = false
  stopAutoRoll() -- Stop auto-roll when closing shop
end)

closeOpenedBtn.MouseButton1Click:Connect(function()
  openedFrame.Visible = false
  openedGui.Enabled = false

  for _, child in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do
    if child:IsA("Frame") then
      child:Destroy()
    end
  end
end)

-- Setting up crates shop
local crateButtons = {}

for _, crate in pairs(crates:GetChildren()) do
  local crateProperties = require(crate)

  local newBtn = crateButtonTemplate:Clone()
  newBtn.Name = crate.Name
  newBtn.CrateName.Text = crate.Name
  newBtn.CrateImage.Image = crateProperties["Image"]


  -- Replace the crate selection logic section (around line 280-320)
  -- Find this part in your code and replace it:

  newBtn.MouseButton1Click:Connect(function()
    -- Stop auto-roll when selecting a different crate
    if selectedCrate.CrateName.Text ~= crate.Name then
      stopAutoRoll()
    end

    if selectedCrate.CrateName.Text ~= crate.Name then
      selectedCrate.CrateName.Text = crate.Name
      selectedCrate.CrateImage.Image = crateProperties["Image"]
      selectedCrate.UnboxButton.Text = "$" .. formatNumber(crateProperties["Price"])

      -- IMPORTANT: Set the selected crate price here
      selectedCratePrice = crateProperties["Price"]

      local rarities = {}
      for rarityName, chance in pairs(crateProperties["Chances"]) do
        table.insert(rarities, { rarityName, chance })
      end
      table.sort(rarities, function(a, b)
        return rarityProperties[a[1]].Order.Value < rarityProperties[b[1]].Order.Value
      end)

      local raritiesText = ""
      for _, rarity in pairs(rarities) do
        local color = rarityProperties[rarity[1]].Color.Value
        color = { R = math.round(color.R * 255), G = math.round(color.G * 255), B = math.round(color.B * 255) }
        raritiesText = raritiesText ..
        '<font color="rgb(' ..
        color.R .. ',' .. color.G .. ',' .. color.B .. ')">' .. rarity[1] .. ': <b>' .. rarity[2] .. '%</b></font><br />'
      end
      selectedCrate.RaritiesText.RichText = true
      selectedCrate.RaritiesText.Text = raritiesText

      for _, child in pairs(selectedCrate.ItemsList:GetChildren()) do
        if child:IsA("Frame") then
          child:Destroy()
        end
      end

      local unboxableItems = crateProperties["Items"]
      table.sort(unboxableItems, function(a, b)
        return
            (rarityProperties[items:FindFirstChild(a, true).Parent.Name].Order.Value < rarityProperties[items:FindFirstChild(b, true).Parent.Name].Order.Value)
            or
            (rarityProperties[items:FindFirstChild(a, true).Parent.Name].Order.Value == rarityProperties[items:FindFirstChild(b, true).Parent.Name].Order.Value)
            and (a < b)
      end)

      for _, unboxableItemName in pairs(unboxableItems) do
        local itemSource = items:FindFirstChild(unboxableItemName, true)
        if itemSource then
          local ownersValue = itemSource:FindFirstChild("Owners")
          local stockValue = itemSource:FindFirstChild("Stock")
          if stockValue and stockValue:IsA("IntValue") and ownersValue and ownersValue:IsA("IntValue") then
            -- Only show if not out of stock
            if ownersValue.Value < stockValue.Value then
              local newItemFrame = selectedCrateItemTemplate:Clone()
              newItemFrame.ItemName.Text = unboxableItemName
              newItemFrame.ItemName.TextColor3 = rarityProperties[itemSource.Parent.Name].Color.Value
              setupItemViewport(newItemFrame.ItemImage, itemSource)
              newItemFrame.Parent = selectedCrate.ItemsList
            end
          else
            -- No stock value (infinite stock) or missing Owners/Stock: always show
            local newItemFrame = selectedCrateItemTemplate:Clone()
            newItemFrame.ItemName.Text = unboxableItemName
            newItemFrame.ItemName.TextColor3 = rarityProperties[itemSource.Parent.Name].Color.Value
            setupItemViewport(newItemFrame.ItemImage, itemSource)
            newItemFrame.Parent = selectedCrate.ItemsList
          end
        end
      end

      selectedCrate.Visible = true
    else
      -- If clicking the same crate, make sure price is still set
      selectedCratePrice = crateProperties["Price"]
    end
  end)


  table.insert(crateButtons, { newBtn, crateProperties["Price"] })
end

table.sort(crateButtons, function(a, b)
  return (a[2] < b[2]) or (a[2] == b[2] and a[1].Name < b[1].Name)
end)

for _, crateButton in pairs(crateButtons) do
  crateButton[1].Parent = cratesList
end

-- Purchasing crates
selectedCrate.UnboxButton.MouseButton1Click:Connect(function()
  if selectedCrate.Visible then
    local playerCash = game.Players.LocalPlayer.leaderstats.Cash.Value


    if playerCash >= selectedCratePrice then
      remotes:WaitForChild("BuyCrate"):FireServer(selectedCrate.CrateName.Text)
    else
      -- Show notification when player doesn't have enough cash
      sendNotification(player, "You don't have enough cash!")
    end
  end
end)
-- Auto-roll button
selectedCrate.AutoRollButton.MouseButton1Click:Connect(function()
  if not isAutoRolling then
    startAutoRoll()
  else
    stopAutoRoll()
  end
end)

-- Stop auto-roll when player leaves the game or their character is removed
game.Players.PlayerRemoving:Connect(function(plr)
  if plr == player then
    stopAutoRoll()
  end
end)

player.CharacterRemoving:Connect(function()
  stopAutoRoll()
end)

-- Crate opening logic
function lerp(a, b, t)
  return a + (b - a) * t
end

function tweenGraph(x, pow)
  x = math.clamp(x, 0, 1)
  return 1 - (1 - x) ^ pow
end

remotes:WaitForChild("CrateOpened").OnClientEvent:Connect(function(crateName, itemChosen, unboxTime)
  local crateProperties = require(crates[crateName])

  local numItems = 100      -- consistent scroll length
  local chosenPosition = 25 -- center-ish in the list

  for i = 1, numItems do
    local rarityChosen = itemChosen.Parent.Name
    local randomItemChosen = itemChosen

    if i ~= chosenPosition then
      local rndChance = rnd:NextNumber() * 100
      local n = 0
      for rarity, chance in pairs(crateProperties["Chances"]) do
        n += chance
        if rndChance <= n then
          rarityChosen = rarity
          break
        end
      end

      local unboxableItems = crateProperties["Items"]
      for i = #unboxableItems, 2, -1 do
        local j = rnd:NextInteger(1, i)
        unboxableItems[i], unboxableItems[j] = unboxableItems[j], unboxableItems[i]
      end

      for _, itemName in pairs(unboxableItems) do
        if items:FindFirstChild(itemName, true).Parent.Name == rarityChosen then
          randomItemChosen = items:FindFirstChild(itemName, true)
          break
        end
      end
    end

    local newItemFrame = openingCrateItemTemplate:Clone()
    newItemFrame.ItemName.Text = randomItemChosen.Name
    newItemFrame.ItemName.TextColor3 = rarityProperties[rarityChosen].Color.Value

    setupItemViewport(newItemFrame.ItemImage, randomItemChosen)
    newItemFrame.Parent = openedItemsFrame.ItemsContainer
  end

  openedItemsFrame.ItemsContainer.Position = UDim2.new(0, 0, 0.5, 0)

  local cellSize = openingCrateItemTemplate.Size.X.Scale
  local padding = openedItemsFrame.ItemsContainer.UIListLayout.Padding.Scale
  local pos1 = 0.5 - cellSize / 2
  local nextOffset = -cellSize - padding
  local posFinal = pos1 + (chosenPosition - 1) * nextOffset
  local rndOffset = 0 -- keep consistent speed and position


  local timeOpened = tick()
  unboxTime = hasFastUnboxPass and (unboxTime * 0.2) or unboxTime
  local pow = 2.5
  local lastSlot = 0

  openedFrame.CrateName.Text = crateName
  shopFrame.Visible = false
  closeOpenedBtn.Visible = false
  openedFrame.Visible = true
  openedGui.Enabled = true

  while true do
    local timeSinceOpened = tick() - timeOpened
    local x = timeSinceOpened / unboxTime
    local t = tweenGraph(x, pow)
    local newXPos = lerp(0, posFinal, t)
    local currentSlot = math.abs(math.floor((newXPos + rndOffset) / cellSize)) + 1
    if currentSlot ~= lastSlot then
      script.TickSound:Play()
      lastSlot = currentSlot
    end

    openedItemsFrame.ItemsContainer.Position = UDim2.new(newXPos, 0, 0.5, 0)
    if x >= 1 then
      break
    end
    game:GetService("RunService").Heartbeat:Wait()
  end

  closeOpenedBtn.Visible = true

  -- Handle auto-continue during auto-roll
  handleCrateOpeningComplete()
end)
