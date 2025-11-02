-- RandomItemDrops.lua
-- Random item drop event - items fall from the sky and players can collect them

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local InsertService = game:GetService("InsertService")

local ItemDatabase = require(script.Parent.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.Parent.DataStoreAPI)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))
local WebhookHandler = require(script.Parent.Parent.WebhookHandler)

local RandomItemDrops = {}

-- Event configuration
local NUM_ITEMS_TO_DROP = math.random(15, 20)
local EVENT_DURATION = 3 * 60 -- 3 minutes
local ITEM_LIFETIME = math.random(60, 120) -- Items stay 1-2 minutes after landing
local DROP_INTERVAL = EVENT_DURATION / NUM_ITEMS_TO_DROP

-- Event drop probability system
-- Instead of using absolute probabilities, events use MULTIPLIERS on normal roll chances
-- This means events make items X times more likely than normal rolling, based on rarity
-- Higher multipliers = more common in events, but still respects rarity hierarchy
local RARITY_MULTIPLIERS = {
  ["Common"] = 1,       
  ["Uncommon"] = 2,     
  ["Rare"] = 30,       
  ["Ultra Rare"] = 50,  
  ["Epic"] = 75,         
  ["Ultra Epic"] = 65,   
  ["Mythic"] =75,       
  ["Insane"] = 30        
}

-- Chat notification and notification system
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local chatNotificationEvent = remoteEvents:FindFirstChild("ChatNotificationEvent")
local createNotificationEvent = remoteEvents:FindFirstChild("CreateNotification")

-- Helper function to get color tag based on item value
local function getValueColorTag(value)
  if value >= 10000000 then
    return "<font color=\"#FF00FF\">" -- Insane (Magenta)
  elseif value >= 2500000 then
    return "<font color=\"#FF0000\">" -- Mythic (Red)
  elseif value >= 750000 then
    return "<font color=\"#FF5500\">" -- Ultra Epic (Red-Orange)
  elseif value >= 250000 then
    return "<font color=\"#FFAA00\">" -- Epic (Orange)
  elseif value >= 50000 then
    return "<font color=\"#AA55FF\">" -- Ultra Rare (Purple)
  elseif value >= 10000 then
    return "<font color=\"#5555FF\">" -- Rare (Blue)
  elseif value >= 2500 then
    return "<font color=\"#55AA55\">" -- Uncommon (Green)
  else
    return "<font color=\"#AAAAAA\">" -- Common (Gray)
  end
end

-- Helper to format numbers with commas
local function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

-- Pick a random item using event probability
-- Events use normal roll probability multiplied by rarity-based multipliers
local function pickRandomEventItem(items)
  if #items == 0 then return nil end

  -- Calculate weights using normal roll probability * rarity multiplier
  -- Normal rolling: weight = 1 / (value ^ 0.9)
  -- Event rolling: weight = (1 / (value ^ 0.9)) * rarity_multiplier
  local totalWeight = 0
  local weights = {}

  for _, item in ipairs(items) do
    local normalRollChance = 1 / (item.Value ^ 0.9)
    local rarity = item.Rarity or ItemRarityModule.GetRarity(item.Value)
    local multiplier = RARITY_MULTIPLIERS[rarity] or 2
    local eventWeight = normalRollChance * multiplier

    table.insert(weights, eventWeight)
    totalWeight = totalWeight + eventWeight
  end

  -- Pick random item based on weighted probability
  local randomValue = math.random() * totalWeight
  local cumulative = 0
  for i, item in ipairs(items) do
    cumulative = cumulative + weights[i]
    if randomValue <= cumulative then
      return item
    end
  end

  return items[#items]
end

-- Create a physical item drop
local function createItemDrop(itemData, dropZone, onCollected)
  -- Try to load the actual Roblox item model
  local itemModel = nil
  local loadSuccess = false

  local success, assetContainer = pcall(function()
    return InsertService:LoadAsset(itemData.RobloxId)
  end)

  if success and assetContainer then
    -- Get the first child (the actual model)
    for _, child in ipairs(assetContainer:GetChildren()) do
      if child:IsA("Accoutrement") or child:IsA("Tool") or child:IsA("Hat") or child:IsA("Model") then
        itemModel = child:Clone()
        itemModel.Name = "DroppedItem_" .. itemData.Name
        loadSuccess = true
        print("✅ Loaded actual model for: " .. itemData.Name)
        break
      end
    end
    assetContainer:Destroy()
  end

  if not loadSuccess then
    warn("⚠️ Could not load model for " .. itemData.Name .. " (ID: " .. itemData.RobloxId .. "), using fallback")
  end

  -- Fallback: Create a simple visual if loading fails
  if not itemModel then
    itemModel = Instance.new("Model")
    itemModel.Name = "DroppedItem_" .. itemData.Name

    local part = Instance.new("Part")
    part.Name = "ItemPart"
    part.Size = Vector3.new(3, 3, 3)
    part.Anchored = false
    part.CanCollide = true
    part.Material = Enum.Material.Neon

    -- Set color based on rarity
    local rarityColors = {
      ["Common"] = Color3.fromRGB(170, 170, 170),
      ["Uncommon"] = Color3.fromRGB(85, 170, 85),
      ["Rare"] = Color3.fromRGB(85, 85, 255),
      ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
      ["Epic"] = Color3.fromRGB(255, 170, 0),
      ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
      ["Mythic"] = Color3.fromRGB(255, 0, 0),
      ["Insane"] = Color3.fromRGB(255, 0, 255)
    }
    part.Color = rarityColors[itemData.Rarity] or Color3.new(1, 1, 1)
    part.Parent = itemModel

    -- Add mesh/texture to show item
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Top
    surfaceGui.Parent = part

    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.Image = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150"
    imageLabel.Parent = surfaceGui
  end

  -- Set highlight color based on rarity
  local rarityColors = {
    ["Common"] = Color3.fromRGB(170, 170, 170),
    ["Uncommon"] = Color3.fromRGB(85, 170, 85),
    ["Rare"] = Color3.fromRGB(85, 85, 255),
    ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
    ["Epic"] = Color3.fromRGB(255, 170, 0),
    ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
    ["Mythic"] = Color3.fromRGB(255, 0, 0),
    ["Insane"] = Color3.fromRGB(255, 0, 255)
  }
  local rarityColor = rarityColors[itemData.Rarity] or Color3.new(1, 1, 1)

  -- Find the main part for the model (different for different types)
  local part
  if itemModel:IsA("Accoutrement") or itemModel:IsA("Hat") then
    -- Accessories and hats have a Handle part
    part = itemModel:FindFirstChild("Handle")
  elseif itemModel:IsA("Tool") then
    -- Tools also have a Handle
    part = itemModel:FindFirstChild("Handle")
  elseif itemModel:IsA("Model") then
    -- Models have PrimaryPart or we find the first BasePart
    part = itemModel.PrimaryPart or itemModel:FindFirstChildWhichIsA("BasePart", true)
  end

  -- Fallback: search for any BasePart if we still don't have one
  if not part then
    part = itemModel:FindFirstChildWhichIsA("BasePart", true)
  end

  -- Last resort: create a part if nothing exists
  if not part then
    part = Instance.new("Part")
    part.Name = "ItemPart"
    part.Size = Vector3.new(3, 3, 3)
    part.Anchored = false
    part.CanCollide = true
    part.Parent = itemModel
  end

  -- Add Highlight to show rarity (works on any model)
  local highlight = Instance.new("Highlight")
  highlight.Name = "RarityHighlight"
  highlight.Adornee = itemModel
  highlight.FillTransparency = 0.3
  highlight.OutlineTransparency = 0
  highlight.FillColor = rarityColor
  highlight.OutlineColor = rarityColor
  highlight.Parent = itemModel
  
  -- Add PointLight for glowing effect on the main part
  local pointLight = Instance.new("PointLight")
  pointLight.Name = "GlowLight"
  pointLight.Color = rarityColor
  pointLight.Brightness = 2
  pointLight.Range = 15
  pointLight.Parent = part
  
  -- Pulsing glow animation
  task.spawn(function()
    local pulseSpeed = 2
    local minBrightness = 1
    local maxBrightness = 3
    
    while itemModel and itemModel.Parent and pointLight and pointLight.Parent do
      for brightness = minBrightness, maxBrightness, 0.1 do
        if not itemModel or not itemModel.Parent or not pointLight or not pointLight.Parent then break end
        pointLight.Brightness = brightness
        task.wait(pulseSpeed / 20)
      end
      for brightness = maxBrightness, minBrightness, -0.1 do
        if not itemModel or not itemModel.Parent or not pointLight or not pointLight.Parent then break end
        pointLight.Brightness = brightness
        task.wait(pulseSpeed / 20)
      end
    end
  end)

  -- Add proximity prompt
  local proximityPrompt = Instance.new("ProximityPrompt")
  proximityPrompt.ActionText = "Collect Item"
  proximityPrompt.ObjectText = itemData.Name
  proximityPrompt.MaxActivationDistance = 10
  proximityPrompt.RequiresLineOfSight = false
  proximityPrompt.Parent = part

  -- Spawn at dropzone
  local spawnPosition = dropZone.Position + Vector3.new(
    math.random(-dropZone.Size.X/2, dropZone.Size.X/2),
    10,
    math.random(-dropZone.Size.Z/2, dropZone.Size.Z/2)
  )

  -- Parent to workspace first
  itemModel.Parent = workspace

  -- Position the model based on its type
  if itemModel:IsA("Model") and itemModel.PrimaryPart then
    -- Use SetPrimaryPartCFrame for models with PrimaryPart
    itemModel:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
  else
    -- For Accessories, Tools, or models without PrimaryPart, position the main part directly
    part.CFrame = CFrame.new(spawnPosition)
  end

  -- Add BodyVelocity for slow fall
  local bodyVelocity = Instance.new("BodyVelocity")
  bodyVelocity.Velocity = Vector3.new(0, -5, 0) -- Slow downward movement
  bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
  bodyVelocity.Parent = part

  -- Rotate the item for visual effect
  task.spawn(function()
    while itemModel and itemModel.Parent do
      part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(2), 0)
      task.wait(0.05)
    end
  end)

  -- Handle collection
  local collected = false
  proximityPrompt.Triggered:Connect(function(player)
    if collected then return end
    collected = true

    -- Add item to player inventory
    onCollected(player, itemData)

    -- Destroy the item
    itemModel:Destroy()
  end)

  -- Remove velocity when touching ground
  part.Touched:Connect(function(hit)
    if hit:IsA("BasePart") and not hit:IsDescendantOf(itemModel) then
      if bodyVelocity and bodyVelocity.Parent then
        bodyVelocity:Destroy()
      end
      part.Anchored = true
    end
  end)

  -- Auto-cleanup after lifetime
  task.delay(ITEM_LIFETIME, function()
    if itemModel and itemModel.Parent and not collected then
      itemModel:Destroy()
    end
  end)

  return itemModel
end

-- Handle item collection
local function handleItemCollection(player, itemData)
  -- If this is a stock item, claim the serial number NOW (not at drop creation)
  if itemData.IsStockItem then
    local item = ItemDatabase:GetItemByRobloxId(itemData.RobloxId)
    if item then
      local serialNumber = ItemDatabase:IncrementStock(item)
      if serialNumber then
        itemData.SerialNumber = serialNumber
        print("✅ " .. player.Name .. " collecting stock item " .. itemData.Name .. " #" .. serialNumber)
      else
        -- Stock sold out between drop and collection!
        warn("⚠️ Stock sold out for " .. itemData.Name .. " before " .. player.Name .. " could collect it")
        
        -- Notify player the item sold out
        if createNotificationEvent then
          createNotificationEvent:FireClient(player, {
            Type = "ERROR",
            Title = "Item Sold Out",
            Body = itemData.Name .. " sold out before you could collect it!"
          })
        end
        return
      end
    else
      warn("❌ Item not found in database: " .. itemData.Name)
      return
    end
  end
  
  -- Add to inventory (same as rolling)
  local success = DataStoreAPI:AddItem(player, itemData)

  if not success then
    warn("❌ Failed to give event item to player: " .. player.Name)
    return
  end

  if itemData.SerialNumber then
    print("✅ " .. player.Name .. " collected stock item " .. itemData.Name .. " #" .. itemData.SerialNumber .. " from event")
  else
    print("✅ " .. player.Name .. " collected " .. itemData.Name .. " from event")
  end

  -- Send notification to the player who collected the item
  if createNotificationEvent then
    -- Build the notification body with item name, rarity, and serial (if available)
    local notificationBody = itemData.Name .. "\n" .. itemData.Rarity
    if itemData.SerialNumber then
      notificationBody = notificationBody .. " #" .. itemData.SerialNumber
    end

    -- Get rarity color for the notification
    local rarityColors = {
      ["Common"] = Color3.fromRGB(170, 170, 170),
      ["Uncommon"] = Color3.fromRGB(85, 170, 85),
      ["Rare"] = Color3.fromRGB(85, 85, 255),
      ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
      ["Epic"] = Color3.fromRGB(255, 170, 0),
      ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
      ["Mythic"] = Color3.fromRGB(255, 0, 0),
      ["Insane"] = Color3.fromRGB(255, 0, 255)
    }
    local notificationColor = rarityColors[itemData.Rarity] or Color3.fromRGB(255, 215, 0)

    -- Fire notification to the specific player
    createNotificationEvent:FireClient(player, {
      Type = "EVENT_COLLECT",
      Title = "Event Item Collected!",
      Body = notificationBody,
      ImageId = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150",
      Color = notificationColor
    })
  end

  -- Send chat notifications for high-value items (250k+)
  if itemData.Value >= 250000 then
    local colorTag = getValueColorTag(itemData.Value)
    local closeTag = "</font>"

    local message = colorTag .. player.Name .. " got " .. itemData.Name

    if itemData.SerialNumber then
      message = message .. " #" .. itemData.SerialNumber
    end

    message = message .. " (R$" .. formatNumber(itemData.Value) .. ") from the event!" .. closeTag

    if chatNotificationEvent then
      -- Send to all clients in this server
      chatNotificationEvent:FireAllClients(message)
    end
  end

  -- Send webhook notification for high-value items
  if itemData.Value >= 250000 then
    WebhookHandler:SendHighValueUnbox(player, itemData, "event")
  end
end

-- Event info
function RandomItemDrops.GetEventInfo()
  return {
    Name = "Random Item Drops!",
    Description = "Items are falling from the sky! Collect them before they disappear!",
    Image = "rbxassetid://8150337440"
  }
end

-- Start the event
function RandomItemDrops.Start(onEventEnd)
  print("🎁 Starting Random Item Drops event")

  -- Find dropzone
  local dropZone = workspace:FindFirstChild("dropzone")
  if not dropZone then
    warn("❌ No dropzone found in workspace! Event cancelled.")
    if onEventEnd then onEventEnd() end
    return
  end

  -- Wait for ItemDatabase to be ready
  local maxWait = 30
  local waited = 0
  while not ItemDatabase.IsReady and waited < maxWait do
    task.wait(0.5)
    waited = waited + 0.5
  end

  if not ItemDatabase.IsReady then
    warn("❌ ItemDatabase not ready! Event cancelled.")
    if onEventEnd then onEventEnd() end
    return
  end

  -- Get all rollable items
  local allItems = ItemDatabase:GetRollableItems()
  if #allItems == 0 then
    warn("❌ No items available for event!")
    if onEventEnd then onEventEnd() end
    return
  end

  print("✅ Found " .. #allItems .. " items available for event drops")

  -- Spawn items over time
  task.spawn(function()
    for i = 1, NUM_ITEMS_TO_DROP do
      -- Get fresh rollable items (in case stock changed)
      local currentRollableItems = ItemDatabase:GetRollableItems()
      if #currentRollableItems == 0 then
        warn("⚠️ No rollable items available, ending event early")
        break
      end

      -- Pick random item (with event probability)
      local randomItem = pickRandomEventItem(currentRollableItems)
      if randomItem then
        -- Prepare item data (serial number will be claimed when collected, not now)
        local itemData = {
          RobloxId = randomItem.RobloxId,
          Name = randomItem.Name,
          Value = randomItem.Value,
          Rarity = randomItem.Rarity or ItemRarityModule.GetRarity(randomItem.Value),
          IsStockItem = (randomItem.Stock and randomItem.Stock > 0) or false
        }

        -- Create the drop (serial number will be claimed on collection)
        createItemDrop(itemData, dropZone, handleItemCollection)
        
        if itemData.IsStockItem then
          print("  📦 Dropping stock item: " .. itemData.Name .. " (serial will be claimed on pickup)")
        else
          print("  🎁 Dropped item " .. i .. "/" .. NUM_ITEMS_TO_DROP .. ": " .. itemData.Name)
        end
      else
        warn("⚠️ Failed to pick random item for event drop")
      end

      -- Wait before next drop
      if i < NUM_ITEMS_TO_DROP then
        task.wait(DROP_INTERVAL)
      end
    end

    print("✅ All event items dropped!")

    -- Event ends after all items are dropped
    if onEventEnd then
      onEventEnd()
    end
  end)
end

return RandomItemDrops
