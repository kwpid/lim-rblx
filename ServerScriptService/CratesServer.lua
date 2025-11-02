-- CratesServer.lua
-- Server-side crate opening system with item database integration

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TextChatService = game:GetService("TextChatService")
local MessagingService = game:GetService("MessagingService")

local ItemDatabase = require(script.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))
local WebhookHandler = require(script.Parent.WebhookHandler)

-- Create RemoteEvents if they don't exist
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
  remoteEvents = Instance.new("Folder")
  remoteEvents.Name = "RemoteEvents"
  remoteEvents.Parent = ReplicatedStorage
end

local rollCrateEvent = remoteEvents:FindFirstChild("RollCrateEvent")
if not rollCrateEvent then
  rollCrateEvent = Instance.new("RemoteEvent")
  rollCrateEvent.Name = "RollCrateEvent"
  rollCrateEvent.Parent = remoteEvents
end

local crateOpenedEvent = remoteEvents:FindFirstChild("CrateOpenedEvent")
if not crateOpenedEvent then
  crateOpenedEvent = Instance.new("RemoteEvent")
  crateOpenedEvent.Name = "CrateOpenedEvent"
  crateOpenedEvent.Parent = remoteEvents
end

local chatNotificationEvent = remoteEvents:FindFirstChild("ChatNotificationEvent")
if not chatNotificationEvent then
  chatNotificationEvent = Instance.new("RemoteEvent")
  chatNotificationEvent.Name = "ChatNotificationEvent"
  chatNotificationEvent.Parent = remoteEvents
end

local rnd = Random.new()
local playersRolling = {}

-- Subscribe to cross-server high-value unbox messages
local subscribeSuccess, subscribeErr = pcall(function()
  MessagingService:SubscribeAsync("HighValueUnbox", function(message)
    -- Receive cross-server notifications from other servers
    local data = message.Data
    
    if data and data.PlayerName and data.ItemName and data.ItemValue then
      -- Format the item value with commas
      local function formatNumber(n)
        local formatted = tostring(n)
        while true do
          formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
          if k == 0 then break end
        end
        return formatted
      end
      
      -- Build the cross-server message
      local colorTag = getValueColorTag(data.ItemValue)
      local closeTag = "</font>"
      
      local crossServerMessage = colorTag .. "[GLOBAL] " .. data.PlayerName .. " unboxed " .. data.ItemName
      
      if data.SerialNumber then
        crossServerMessage = crossServerMessage .. " #" .. data.SerialNumber
      end
      
      crossServerMessage = crossServerMessage .. " (R$" .. formatNumber(data.ItemValue) .. ")" .. closeTag
      
      -- Send to all clients in this server to display
      chatNotificationEvent:FireAllClients(crossServerMessage)
    end
  end)
end)

if subscribeSuccess then
  print("✅ Subscribed to cross-server high-value unbox notifications")
else
  warn("⚠️ Failed to subscribe to cross-server messages: " .. tostring(subscribeErr))
end

-- Configuration
local ROLL_COST = 0 -- Free rolls
local ROLL_TIME = 5 -- Normal roll time in seconds
local FAST_ROLL_TIME = 2 -- Fast roll time (2.5x faster)
local FAST_ROLL_GAMEPASS_ID = 1242040274 -- Old game's fast roll gamepass

-- 🍀 LUCK MULTIPLIER CONFIGURATION
-- Change this value in Studio to give all players a global luck boost for updates/events
-- 1.0 = normal luck, 1.5 = 50% better odds for Epic+ items (recommended for events), 2.0 = double luck
local GLOBAL_LUCK_MULTIPLIER = 1.5

-- 🎃 LUCK RARITY THRESHOLD
-- Luck only applies to items of this rarity or higher (Epic = 250,000 Robux)
local LUCK_MIN_VALUE = 250000 -- Epic rarity and above

-- Helper function to pick random item based on value (inverse probability)
-- luckMultiplier: Player's luck multiplier (1.0 = normal, higher = better odds for rare items)
-- Luck ONLY affects items with value >= LUCK_MIN_VALUE (Epic rarity or higher)
function pickRandomItem(items, luckMultiplier)
  if #items == 0 then
    return nil
  end

  luckMultiplier = luckMultiplier or 1.0
  
  -- Clamp luck near 1.0 to prevent floating-point rounding issues
  local LUCK_EPSILON = 0.001
  if math.abs(luckMultiplier - 1.0) < LUCK_EPSILON then
    luckMultiplier = 1.0
  end
  
  -- Calculate total inverse value using power of 0.9 (steeper curve = rarer items)
  local totalInverseValue = 0
  for _, item in ipairs(items) do
    totalInverseValue = totalInverseValue + (1 / (item.Value ^ 0.9))
  end
  
  -- Helper function to pick a single item from the full list
  local function pickSingleItem()
    local randomValue = rnd:NextNumber() * totalInverseValue
    local cumulative = 0
    for _, item in ipairs(items) do
      cumulative = cumulative + (1 / (item.Value ^ 0.9))
      if randomValue <= cumulative then
        return item
      end
    end
    -- Fallback
    return items[#items]
  end
  
  -- If luck is exactly 1.0 (neutral), just do a single roll
  if luckMultiplier == 1.0 then
    return pickSingleItem()
  end
  
  -- Apply luck: perform multiple rolls and apply selection logic ONLY if an Epic+ item is rolled
  local numRolls = 1
  if luckMultiplier > 1.0 then
    -- Higher luck = more rolls (ceiling ensures any luck > 1.0 has effect)
    numRolls = math.min(math.ceil(luckMultiplier), 10)
  elseif luckMultiplier < 1.0 then
    -- Lower luck = more rolls (inverted)
    numRolls = math.min(math.ceil(1.0 / luckMultiplier), 10)
  end
  
  -- Debug: Log number of rolls
  if numRolls > 1 then
    print(string.format("  🎲 Performing %d rolls (luck=%.1fx)", numRolls, luckMultiplier))
  end
  
  -- Perform all rolls
  local allRolls = {}
  local epicPlusRolls = {}
  
  for i = 1, numRolls do
    local rolledItem = pickSingleItem()
    table.insert(allRolls, rolledItem)
    
    -- Track Epic+ rolls separately
    if rolledItem.Value >= LUCK_MIN_VALUE then
      table.insert(epicPlusRolls, rolledItem)
      print(string.format("  ✨ Roll #%d: EPIC+ %s (R$%s)", i, rolledItem.Name, tostring(rolledItem.Value)))
    end
  end
  
  -- Decision logic based on luck and what was rolled
  if #epicPlusRolls > 0 then
    -- At least one Epic+ item was rolled - apply luck selection logic
    print(string.format("  🎯 Got %d Epic+ items out of %d rolls", #epicPlusRolls, numRolls))
    if luckMultiplier > 1.0 then
      -- Higher luck: pick the HIGHEST value Epic+ item (most rare)
      local bestItem = epicPlusRolls[1]
      for _, item in ipairs(epicPlusRolls) do
        if item.Value > bestItem.Value then
          bestItem = item
        end
      end
      print(string.format("  ⬆️ Selected HIGHEST: %s (R$%s)", bestItem.Name, tostring(bestItem.Value)))
      return bestItem
    elseif luckMultiplier < 1.0 then
      -- Lower luck: pick the LOWEST value Epic+ item (least rare in Epic+ tier)
      local worstItem = epicPlusRolls[1]
      for _, item in ipairs(epicPlusRolls) do
        if item.Value < worstItem.Value then
          worstItem = item
        end
      end
      print(string.format("  ⬇️ Selected LOWEST: %s (R$%s)", worstItem.Name, tostring(worstItem.Value)))
      return worstItem
    end
  else
    -- No Epic+ items rolled
    if numRolls > 1 then
      print(string.format("  ❌ No Epic+ items in %d rolls, returning first roll: %s (R$%s)", 
        numRolls, allRolls[1].Name, tostring(allRolls[1].Value)))
    end
  end
  
  -- No Epic+ items were rolled, so luck doesn't apply
  -- Just return the first roll (luck has no effect on common items)
  return allRolls[1]
end

-- Helper function to get color tag based on item value
function getValueColorTag(value)
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

-- Helper function to send chat message about unboxed item
function sendUnboxChatMessage(player, item, serialNumber, isCrossServer)
  local success, err = pcall(function()
    -- Format the item value with commas
    local function formatNumber(n)
      local formatted = tostring(n)
      while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
      end
      return formatted
    end
    
    -- Build the message
    local colorTag = getValueColorTag(item.Value)
    local closeTag = "</font>"
    
    local message = colorTag .. player.Name .. " unboxed " .. item.Name
    
    if serialNumber then
      message = message .. " #" .. serialNumber
    end
    
    message = message .. " (R$" .. formatNumber(item.Value) .. ")" .. closeTag
    
    -- Send to all clients in the current server
    chatNotificationEvent:FireAllClients(message)
    
    -- If cross-server (5M+ items), announce to all servers
    if isCrossServer then
      local messageData = {
        PlayerName = player.Name,
        ItemName = item.Name,
        ItemValue = item.Value,
        SerialNumber = serialNumber
      }
      
      -- Publish to all servers via MessagingService
      local publishSuccess, publishErr = pcall(function()
        MessagingService:PublishAsync("HighValueUnbox", messageData)
      end)
      
      if not publishSuccess then
        warn("⚠️ Failed to publish cross-server message: " .. tostring(publishErr))
      end
    end
  end)
  
  if not success then
    warn("⚠️ Failed to send chat message: " .. tostring(err))
  end
end

-- Generate random items for animation
function generateAnimationItems(chosenItem, numItems)
  -- Use rollable items only (excludes sold-out stock items)
  local allItems = ItemDatabase:GetRollableItems()

  if #allItems == 0 then
    warn("⚠️ No items in database! Cannot generate animation.")
    return { chosenItem }
  end

  local animationItems = {}
  local chosenPosition = rnd:NextInteger(15, numItems - 5)

  for i = 1, numItems do
    if i == chosenPosition then
      -- Insert the actual chosen item
      table.insert(animationItems, chosenItem)
    else
      -- Pick random item for filler (only from rollable items)
      local randomItem = pickRandomItem(allItems)
      if randomItem then
        table.insert(animationItems, randomItem)
      else
        table.insert(animationItems, chosenItem)
      end
    end
  end

  return animationItems
end

-- Handle roll request
rollCrateEvent.OnServerEvent:Connect(function(player)
  -- Wait for ItemDatabase to be ready (if not ready yet)
  if not ItemDatabase.IsReady then
    print("⏳ ItemDatabase not ready yet, waiting...")
    local waitStart = tick()
    local maxWait = 30 -- Maximum 30 seconds wait
    
    while not ItemDatabase.IsReady and (tick() - waitStart) < maxWait do
      task.wait(0.1)
    end
    
    if not ItemDatabase.IsReady then
      warn("❌ ItemDatabase failed to load in time!")
      return
    end
  end
  
  -- Check if player is already rolling
  if playersRolling[player] then
    return
  end

  playersRolling[player] = true

  -- Check if player owns fast roll gamepass from old game
  local hasFastRoll = false
  local success, result = pcall(function()
    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, FAST_ROLL_GAMEPASS_ID)
  end)
  
  if success then
    hasFastRoll = result
  else
    warn("⚠️ Failed to check gamepass ownership: " .. tostring(result))
  end

  -- Get all rollable items from database (excludes sold out stock items)
  local allItems = ItemDatabase:GetRollableItems()

  if #allItems == 0 then
    warn("⚠️ No items in database! Cannot roll crate.")
    playersRolling[player] = nil
    return
  end

  -- Get player's luck multiplier (from attribute, default 1.0)
  local playerLuck = player:GetAttribute("Luck") or 1.0
  
  -- Apply global luck multiplier
  local totalLuck = playerLuck * GLOBAL_LUCK_MULTIPLIER
  
  -- Debug: Print luck values
  print(string.format("🍀 %s rolling with luck: Player=%.1fx, Global=%.1fx, Total=%.1fx", 
    player.Name, playerLuck, GLOBAL_LUCK_MULTIPLIER, totalLuck))
  
  -- Pick random item (weighted by inverse value with luck modifier)
  local chosenItem = pickRandomItem(allItems, totalLuck)

  if not chosenItem then
    warn("⚠️ Failed to pick item!")
    playersRolling[player] = nil
    return
  end

  -- Generate animation items
  local numAnimationItems = rnd:NextInteger(30, 60)
  local animationItems = generateAnimationItems(chosenItem, numAnimationItems)

  -- Use fast roll time if player has gamepass, otherwise normal time
  local unboxTime = hasFastRoll and FAST_ROLL_TIME or ROLL_TIME

  -- Send to client for animation (will send serial number later after claiming stock)
  crateOpenedEvent:FireClient(player, animationItems, chosenItem, unboxTime, nil)


  -- Wait for animation to finish
  task.wait(unboxTime)

  -- Check if this is a stock item and try to claim it
  local stock = chosenItem.Stock or 0
  local serialNumber = nil

  if stock > 0 then
    -- Try to increment stock (race condition protection)
    serialNumber = ItemDatabase:IncrementStock(chosenItem)

    if not serialNumber then
      -- Stock sold out during animation! Reroll a different item
      warn("⚠️ " .. chosenItem.Name .. " sold out during roll! Rerolling...")

      local newRollableItems = ItemDatabase:GetRollableItems()
      if #newRollableItems > 0 then
        -- Use same luck multiplier for reroll
        chosenItem = pickRandomItem(newRollableItems, totalLuck)

        -- Try to claim the new item if it's also a stock item
        local newStock = chosenItem.Stock or 0
        if newStock > 0 then
          serialNumber = ItemDatabase:IncrementStock(chosenItem)
          if not serialNumber then
            -- Even the reroll sold out, give a regular item instead
            warn("⚠️ Reroll also sold out, converting to regular item")
          end
        end
      else
        warn("⚠️ No rollable items available! Cannot award item.")
        playersRolling[player] = nil
        return
      end
    end
  end

  -- Add item to player's inventory
  local itemToAdd = {
    RobloxId = chosenItem.RobloxId,
    Name = chosenItem.Name,
    Value = chosenItem.Value,
    Rarity = chosenItem.Rarity,
  }

  if serialNumber then
    itemToAdd.SerialNumber = serialNumber


    -- Send serial number to client for display
    local updateResultEvent = remoteEvents:FindFirstChild("UpdateCrateResult")
    if not updateResultEvent then
      updateResultEvent = Instance.new("RemoteEvent")
      updateResultEvent.Name = "UpdateCrateResult"
      updateResultEvent.Parent = remoteEvents
    end
    updateResultEvent:FireClient(player, serialNumber)
  end

  DataStoreAPI:AddItem(player, itemToAdd)
  DataStoreAPI:IncrementRolls(player)

  -- Send chat notification for high-value items
  if chosenItem.Value >= 5000000 then
    -- 5M+ = Server-wide + Cross-server notification (all servers)
    sendUnboxChatMessage(player, chosenItem, serialNumber, true)
  elseif chosenItem.Value >= 250000 then
    -- 250k+ = Server-wide notification (current server only)
    sendUnboxChatMessage(player, chosenItem, serialNumber, false)
  end
  
  -- Send Discord webhook for high-value items (250k+)
  if chosenItem.Value >= 250000 then
    task.spawn(function()
      WebhookHandler:SendItemDrop(player, chosenItem, serialNumber)
    end)
  end

  playersRolling[player] = nil
end)
