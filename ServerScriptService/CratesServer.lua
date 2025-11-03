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
local EventSystem = require(script.Parent.EventSystem)

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

-- 🎃 LUCK RARITY THRESHOLDS
-- Regular Luck applies to items of this rarity or higher (Epic = 250,000 Robux)
local LUCK_MIN_VALUE = 250000 -- Epic rarity and above
-- Mythic Luck applies ONLY to Mythic items (2,500,000 - 9,999,999 Robux)
local MYTHIC_LUCK_MIN_VALUE = 2500000 -- Mythic rarity
local MYTHIC_LUCK_MAX_VALUE = 9999999 -- Below Insane
-- Insane Luck applies ONLY to Insane items (10,000,000+ Robux)
local INSANE_LUCK_MIN_VALUE = 10000000 -- Insane rarity

-- Helper function to pick random item based on value (inverse probability)
-- luckMultiplier: Player's luck multiplier for Epic+ (1.0 = normal, higher = better odds)
-- mythicLuckMultiplier: Player's mythic luck multiplier for Mythic ONLY (1.0 = normal, admin only)
-- insaneLuckMultiplier: Player's insane luck multiplier for Insane ONLY (1.0 = normal, admin only)
-- Luck affects items by modifying their roll weights
function pickRandomItem(items, luckMultiplier, mythicLuckMultiplier, insaneLuckMultiplier)
  if #items == 0 then
    return nil
  end

  luckMultiplier = luckMultiplier or 1.0
  mythicLuckMultiplier = mythicLuckMultiplier or 1.0
  insaneLuckMultiplier = insaneLuckMultiplier or 1.0

  -- Calculate total inverse value with luck applied
  local totalInverseValue = 0
  for _, item in ipairs(items) do
    local baseWeight = 1 / (item.Value ^ 0.9)

    -- Apply luck multiplier to Epic+ items (250k+)
    if item.Value >= LUCK_MIN_VALUE then
      baseWeight = baseWeight * luckMultiplier
    end

    -- Apply ADDITIONAL mythic luck multiplier to Mythic items ONLY (2.5M-9.9M)
    if item.Value >= MYTHIC_LUCK_MIN_VALUE and item.Value <= MYTHIC_LUCK_MAX_VALUE then
      baseWeight = baseWeight * mythicLuckMultiplier
    end

    -- Apply ADDITIONAL insane luck multiplier to Insane items ONLY (10M+)
    if item.Value >= INSANE_LUCK_MIN_VALUE then
      baseWeight = baseWeight * insaneLuckMultiplier
    end

    totalInverseValue = totalInverseValue + baseWeight
  end

  -- Pick a random item using the luck-adjusted weights
  local randomValue = rnd:NextNumber() * totalInverseValue
  local cumulative = 0

  for _, item in ipairs(items) do
    local baseWeight = 1 / (item.Value ^ 0.9)

    -- Apply same luck adjustments
    if item.Value >= LUCK_MIN_VALUE then
      baseWeight = baseWeight * luckMultiplier
    end

    if item.Value >= MYTHIC_LUCK_MIN_VALUE and item.Value <= MYTHIC_LUCK_MAX_VALUE then
      baseWeight = baseWeight * mythicLuckMultiplier
    end

    if item.Value >= INSANE_LUCK_MIN_VALUE then
      baseWeight = baseWeight * insaneLuckMultiplier
    end

    cumulative = cumulative + baseWeight
    if randomValue <= cumulative then
      -- Debug log if luck affected this roll
      if insaneLuckMultiplier ~= 1.0 and item.Value >= INSANE_LUCK_MIN_VALUE then
        print(string.format("  🔥 INSANE LUCK boosted Insane item: %s (R$%s) with %.1fx × %.1fx = %.1fx total", 
          item.Name, tostring(item.Value), luckMultiplier, insaneLuckMultiplier, luckMultiplier * insaneLuckMultiplier))
      elseif mythicLuckMultiplier ~= 1.0 and item.Value >= MYTHIC_LUCK_MIN_VALUE and item.Value <= MYTHIC_LUCK_MAX_VALUE then
        print(string.format("  💎 MYTHIC LUCK boosted Mythic item: %s (R$%s) with %.1fx × %.1fx = %.1fx total", 
          item.Name, tostring(item.Value), luckMultiplier, mythicLuckMultiplier, luckMultiplier * mythicLuckMultiplier))
      elseif luckMultiplier ~= 1.0 and item.Value >= LUCK_MIN_VALUE then
        print(string.format("  🍀 Luck boosted Epic+ item: %s (R$%s) with %.1fx multiplier", 
          item.Name, tostring(item.Value), luckMultiplier))
      end
      return item
    end
  end

  -- Fallback
  return items[#items]
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

  -- Get player's luck multipliers (from attributes, default 1.0)
  local playerLuck = player:GetAttribute("Luck") or 1.0
  local playerMythicLuck = player:GetAttribute("MythicLuck") or 1.0
  local playerInsaneLuck = player:GetAttribute("InsaneLuck") or 1.0

  -- Apply global luck multiplier to regular luck only
  local totalLuck = playerLuck * GLOBAL_LUCK_MULTIPLIER
  local totalMythicLuck = playerMythicLuck
  local totalInsaneLuck = playerInsaneLuck


  -- Pick random item (weighted by inverse value with luck modifiers)
  local chosenItem = pickRandomItem(allItems, totalLuck, totalMythicLuck, totalInsaneLuck)

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
        -- Use same luck multipliers for reroll
        chosenItem = pickRandomItem(newRollableItems, totalLuck, totalMythicLuck, totalInsaneLuck)

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
