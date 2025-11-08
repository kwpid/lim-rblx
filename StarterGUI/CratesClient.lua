local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local rollCrateEvent = remoteEvents:WaitForChild("RollCrateEvent")
local crateOpenedEvent = remoteEvents:WaitForChild("CrateOpenedEvent")
local updateResultEvent = remoteEvents:FindFirstChild("UpdateCrateResult") or Instance.new("RemoteEvent")
updateResultEvent.Name = "UpdateCrateResult"
updateResultEvent.Parent = remoteEvents

local setAutoRollEvent = remoteEvents:WaitForChild("SetAutoRollEvent")
local getAutoRollFunction = remoteEvents:WaitForChild("GetAutoRollFunction")
local serverShutdownEvent = remoteEvents:WaitForChild("ServerShutdownEvent")
local setHideRollsEvent = remoteEvents:WaitForChild("SetHideRollsEvent")
local getHideRollsFunction = remoteEvents:WaitForChild("GetHideRollsFunction")
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

local openedGui = script.Parent:WaitForChild("OpenedCrateGui")
local openedFrame = openedGui:WaitForChild("CrateFrame")
local closeOpenedBtn = openedFrame:WaitForChild("ContinueButton")
local openedItemsFrame = openedFrame:WaitForChild("ItemsFrame")
local openingCrateItemTemplate = script:WaitForChild("OpeningCrateItemFrame")

local rnd = Random.new()
local mainUI = player.PlayerGui:WaitForChild("MainUI")
local rollButton = mainUI:WaitForChild("Roll")
local autoRollButton = mainUI:WaitForChild("AutoRoll")
local hideRollsButton = mainUI:WaitForChild("HideRolls")

local isAutoRolling, isCurrentlyRolling, currentChosenItem, shouldStopAutoRoll = false, false, nil, false
local hideRollsEnabled = false

local RARITY_SHAKE_SETTINGS = {
        ["Common"] = {intensity = 0, duration = 0},
        ["Uncommon"] = {intensity = 0, duration = 0},
        ["Rare"] = {intensity = 0.15, duration = 0.4},
        ["Ultra Rare"] = {intensity = 0.35, duration = 0.6},
        ["Epic"] = {intensity = 0.6, duration = 0.8},
        ["Ultra Epic"] = {intensity = 1.0, duration = 1.0},
        ["Mythic"] = {intensity = 1.5, duration = 1.2},
        ["Insane"] = {intensity = 2.5, duration = 1.5}
}

local function shakeCamera(rarity)
        local shakeSettings = RARITY_SHAKE_SETTINGS[rarity]
        if not shakeSettings or shakeSettings.intensity == 0 then return end
        
        local intensity = shakeSettings.intensity
        local duration = shakeSettings.duration
        local startTime = tick()
        local originalCF = camera.CFrame
        
        task.spawn(function()
                while tick() - startTime < duration do
                        local elapsed = tick() - startTime
                        local fadeOut = 1 - (elapsed / duration)
                        local currentIntensity = intensity * fadeOut
                        
                        local randomX = (math.random() - 0.5) * currentIntensity
                        local randomY = (math.random() - 0.5) * currentIntensity
                        local randomZ = (math.random() - 0.5) * currentIntensity
                        
                        camera.CFrame = camera.CFrame * CFrame.Angles(
                                math.rad(randomX),
                                math.rad(randomY),
                                math.rad(randomZ)
                        )
                        
                        RunService.Heartbeat:Wait()
                end
        end)
end

local function stopAutoRoll()
  isAutoRolling, shouldStopAutoRoll = false, false
  autoRollButton.TextColor3 = Color3.fromRGB(255, 0, 0)
  if autoRollButton:FindFirstChild("UIStroke") then autoRollButton.UIStroke.Color = Color3.fromRGB(255, 0, 0) end
  setAutoRollEvent:FireServer(false)
end

local function startAutoRoll()
  isAutoRolling, shouldStopAutoRoll = true, false
  autoRollButton.TextColor3 = Color3.fromRGB(0, 255, 0)
  if autoRollButton:FindFirstChild("UIStroke") then autoRollButton.UIStroke.Color = Color3.fromRGB(0, 255, 0) end
  setAutoRollEvent:FireServer(true)
end

local function lerp(a, b, t) return a + (b - a) * t end
local function tweenGraph(x, pow)
  x = math.clamp(x, 0, 1)
  return 1 - (1 - x) ^ pow
end

closeOpenedBtn.MouseButton1Click:Connect(function()
  openedFrame.Visible, openedGui.Enabled = false, false
  for _, c in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do if c:IsA("Frame") or c:IsA("ImageLabel") then c
          :Destroy() end end
end)

rollButton.MouseButton1Click:Connect(function()
  if isCurrentlyRolling then return end
  isCurrentlyRolling = true
  rollButton.Text = "[ROLLING...]"
  rollCrateEvent:FireServer()
end)

autoRollButton.MouseButton1Click:Connect(function()
  isAutoRolling = not isAutoRolling
  if isAutoRolling then
    startAutoRoll()
    if not isCurrentlyRolling then
      isCurrentlyRolling = true
      rollButton.Text = "[ROLLING...]"
      rollCrateEvent:FireServer()
    end
  else
    if isCurrentlyRolling then
      shouldStopAutoRoll = true
      autoRollButton.TextColor3 = Color3.fromRGB(255, 0, 0)
      if autoRollButton:FindFirstChild("UIStroke") then autoRollButton.UIStroke.Color = Color3.fromRGB(255, 0, 0) end
      setAutoRollEvent:FireServer(false)
    else
      stopAutoRoll()
    end
  end
end)

hideRollsButton.MouseButton1Click:Connect(function()
  hideRollsEnabled = not hideRollsEnabled
  local color = hideRollsEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
  hideRollsButton.TextColor3 = color
  if hideRollsButton:FindFirstChild("UIStroke") then hideRollsButton.UIStroke.Color = color end
  setHideRollsEvent:FireServer(hideRollsEnabled)
end)

crateOpenedEvent.OnClientEvent:Connect(function(allItems, chosenItem, unboxTime)
  for _, c in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do if c:IsA("Frame") or c:IsA("ImageLabel") then c
          :Destroy() end end
  local numItems, chosenPosition = 100, 25
  for i = 1, numItems do
    local itemData = i == chosenPosition and chosenItem or allItems[rnd:NextInteger(1, #allItems)]
    local newItem = openingCrateItemTemplate:Clone()
    if newItem:FindFirstChild("ItemName") then
      newItem.ItemName.Text, newItem.ItemName.TextColor3 = itemData.Name, ItemRarityModule:GetRarityColor(itemData.Value)
    end
    if newItem:FindFirstChild("ItemImage") then
      newItem.ItemImage.Image = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150"
      if newItem.ItemImage:FindFirstChild("UIStroke") then
        newItem.ItemImage.UIStroke.Color = ItemRarityModule:GetRarityColor(itemData.Value)
      end
    end
    newItem.Parent = openedItemsFrame.ItemsContainer
  end
  openedItemsFrame.ItemsContainer.Position = UDim2.new(0, 0, 0.5, 0)
  local cellSize = openingCrateItemTemplate.Size.X.Scale
  local padding = openedItemsFrame.ItemsContainer.UIListLayout.Padding.Scale
  local posFinal = (0.5 - cellSize / 2) + (chosenPosition - 1) * (-cellSize - padding)
  local pow, timeOpened, lastSlot = 2.5, tick(), 0

  openedFrame.CrateName.Text, closeOpenedBtn.Visible = "Rolling...", false
  if not hideRollsEnabled then openedFrame.Visible, openedGui.Enabled = true, true else openedFrame.Visible, openedGui.Enabled =
    false, false end

  if not hideRollsEnabled then
    while true do
      local t = tweenGraph((tick() - timeOpened) / unboxTime, pow)
      local newXPos = lerp(0, posFinal, t)
      local currentSlot = math.abs(math.floor(newXPos / cellSize)) + 1
      if currentSlot ~= lastSlot and script:FindFirstChild("TickSound") then script.TickSound:Play() end
      lastSlot = currentSlot
      openedItemsFrame.ItemsContainer.Position = UDim2.new(newXPos, 0, 0.5, 0)
      if t >= 1 then break end
      RunService.Heartbeat:Wait()
    end
  else
    task.wait(unboxTime)
  end

  currentChosenItem = chosenItem
  openedFrame.CrateName.Text = "You won: " .. chosenItem.Name .. " (" .. chosenItem.Rarity .. ")!"
  if not hideRollsEnabled then closeOpenedBtn.Visible = true end
  
  shakeCamera(chosenItem.Rarity)
  
  isCurrentlyRolling = false
  rollButton.Text = "[ROLL]"

  if isAutoRolling and not shouldStopAutoRoll then
    task.delay(hideRollsEnabled and 0.5 or 1.5, function()
      if isAutoRolling and not isCurrentlyRolling and not shouldStopAutoRoll then
        openedFrame.Visible, openedGui.Enabled = false, false
        for _, c in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do if c:IsA("Frame") or c:IsA("ImageLabel") then
            c:Destroy() end end
        isCurrentlyRolling = true
        rollButton.Text = "[ROLLING...]"
        rollCrateEvent:FireServer()
      end
    end)
  elseif shouldStopAutoRoll then
    stopAutoRoll()
  elseif hideRollsEnabled then
    task.delay(0.5, function()
      for _, c in pairs(openedItemsFrame.ItemsContainer:GetChildren()) do if c:IsA("Frame") or c:IsA("ImageLabel") then c
              :Destroy() end end
      openedFrame.Visible, openedGui.Enabled = false, false
    end)
  end
end)

updateResultEvent.OnClientEvent:Connect(function(serial)
  if currentChosenItem and serial then
    openedFrame.CrateName.Text = "You won: " ..
    currentChosenItem.Name .. " (#" .. serial .. ") (" .. currentChosenItem.Rarity .. ")!"
  end
end)

rollButton.Text = "[ROLL]"
autoRollButton.Text = "[AUTOROLL]"
autoRollButton.TextColor3 = Color3.fromRGB(255, 0, 0)
if autoRollButton:FindFirstChild("UIStroke") then autoRollButton.UIStroke.Color = Color3.fromRGB(255, 0, 0) end
hideRollsButton.Text = "[HIDE ROLLS]"
hideRollsButton.TextColor3 = Color3.fromRGB(255, 0, 0)
if hideRollsButton:FindFirstChild("UIStroke") then hideRollsButton.UIStroke.Color = Color3.fromRGB(255, 0, 0) end

remoteEvents:WaitForChild("ChatNotificationEvent").OnClientEvent:Connect(function(msg)
  local channel = game:GetService("TextChatService"):FindFirstChild("TextChannels"):FindFirstChild("RBXGeneral")
  if channel then channel:DisplaySystemMessage(msg) end
end)

task.spawn(function()
  task.wait(0.1)
  local ok, saved = pcall(function() return getAutoRollFunction:InvokeServer() end)
  if ok and saved then
    startAutoRoll()
    if not isCurrentlyRolling then
      isCurrentlyRolling = true
      rollButton.Text = "[ROLLING...]"
      rollCrateEvent:FireServer()
    end
  end
  local ok2, hide = pcall(function() return getHideRollsFunction:InvokeServer() end)
  if ok2 and hide then
    hideRollsEnabled = true
    hideRollsButton.TextColor3 = Color3.fromRGB(0, 255, 0)
    if hideRollsButton:FindFirstChild("UIStroke") then hideRollsButton.UIStroke.Color = Color3.fromRGB(0, 255, 0) end
  else
    hideRollsEnabled = false
    hideRollsButton.TextColor3 = Color3.fromRGB(255, 0, 0)
    if hideRollsButton:FindFirstChild("UIStroke") then hideRollsButton.UIStroke.Color = Color3.fromRGB(255, 0, 0) end
  end
end)

if serverShutdownEvent then
  serverShutdownEvent.OnClientEvent:Connect(function()
    print("Server is shutting down - AutoRoll will be enabled on reconnect")
  end)
end
