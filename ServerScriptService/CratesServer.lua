local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")

local ItemDatabase = require(script.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))
local WebhookHandler = require(script.Parent.WebhookHandler)
local EventSystem = require(script.Parent.EventSystem)

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
  remoteEvents = Instance.new("Folder")
  remoteEvents.Name = "RemoteEvents"
  remoteEvents.Parent = ReplicatedStorage
end

local rollCrateEvent = remoteEvents:FindFirstChild("RollCrateEvent") or Instance.new("RemoteEvent")
rollCrateEvent.Name = "RollCrateEvent"
rollCrateEvent.Parent = remoteEvents

local crateOpenedEvent = remoteEvents:FindFirstChild("CrateOpenedEvent") or Instance.new("RemoteEvent")
crateOpenedEvent.Name = "CrateOpenedEvent"
crateOpenedEvent.Parent = remoteEvents

local chatNotificationEvent = remoteEvents:FindFirstChild("ChatNotificationEvent") or Instance.new("RemoteEvent")
chatNotificationEvent.Name = "ChatNotificationEvent"
chatNotificationEvent.Parent = remoteEvents

local rnd = Random.new()
local playersRolling = {}

local function getValueColorTag(value)
  if value >= 10000000 then
    return "<font color=\"#FF00FF\">"
  elseif value >= 2500000 then
    return "<font color=\"#FF0000\">"
  elseif value >= 750000 then
    return "<font color=\"#FF5500\">"
  elseif value >= 250000 then
    return "<font color=\"#FFAA00\">"
  elseif value >= 50000 then
    return "<font color=\"#AA55FF\">"
  elseif value >= 10000 then
    return "<font color=\"#5555FF\">"
  elseif value >= 2500 then
    return "<font color=\"#55AA55\">"
  else
    return "<font color=\"#AAAAAA\">"
  end
end

local subscribeSuccess, subscribeErr = pcall(function()
  MessagingService:SubscribeAsync("HighValueUnbox", function(message)
    local data = message.Data
    if data and data.PlayerName and data.ItemName and data.ItemValue then
      local function formatNumber(n)
        local formatted = tostring(n)
        while true do
          formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
          if k == 0 then break end
        end
        return formatted
      end

      local colorTag = getValueColorTag(data.ItemValue)
      local closeTag = "</font>"
      local crossServerMessage = colorTag .. "[GLOBAL] " .. data.PlayerName .. " unboxed " .. data.ItemName

      if data.SerialNumber then
        crossServerMessage = crossServerMessage .. " #" .. data.SerialNumber
      end

      crossServerMessage = crossServerMessage .. " (R$" .. formatNumber(data.ItemValue) .. ")" .. closeTag
      chatNotificationEvent:FireAllClients(crossServerMessage)
    end
  end)
end)

if not subscribeSuccess then
  warn("failed to subscribe to cross-server messages: " .. tostring(subscribeErr))
end

local ROLL_TIME = 5
local FAST_ROLL_TIME = 2
local FAST_ROLL_GAMEPASS_ID = 1242040274
local GLOBAL_LUCK_MULTIPLIER = 1.5
local LUCK_MIN_VALUE = 250000
local MYTHIC_LUCK_MIN_VALUE = 2500000
local MYTHIC_LUCK_MAX_VALUE = 9999999
local INSANE_LUCK_MIN_VALUE = 10000000

local function pickRandomItem(items, luckMultiplier, mythicLuckMultiplier, insaneLuckMultiplier)
  if #items == 0 then
    return nil
  end

  luckMultiplier = luckMultiplier or 1.0
  mythicLuckMultiplier = mythicLuckMultiplier or 1.0
  insaneLuckMultiplier = insaneLuckMultiplier or 1.0

  local totalInverseValue = 0
  for _, item in ipairs(items) do
    local baseWeight = 1 / (item.Value ^ 1.1)
    if item.Value >= LUCK_MIN_VALUE then
      baseWeight *= luckMultiplier
    end
    if item.Value >= MYTHIC_LUCK_MIN_VALUE and item.Value <= MYTHIC_LUCK_MAX_VALUE then
      baseWeight *= mythicLuckMultiplier
    end
    if item.Value >= INSANE_LUCK_MIN_VALUE then
      baseWeight *= insaneLuckMultiplier
    end
    totalInverseValue += baseWeight
  end

  local randomValue = rnd:NextNumber() * totalInverseValue
  local cumulative = 0

  for _, item in ipairs(items) do
    local baseWeight = 1 / (item.Value ^ 1.1)
    if item.Value >= LUCK_MIN_VALUE then
      baseWeight *= luckMultiplier
    end
    if item.Value >= MYTHIC_LUCK_MIN_VALUE and item.Value <= MYTHIC_LUCK_MAX_VALUE then
      baseWeight *= mythicLuckMultiplier
    end
    if item.Value >= INSANE_LUCK_MIN_VALUE then
      baseWeight *= insaneLuckMultiplier
    end

    cumulative += baseWeight
    if randomValue <= cumulative then
      return item
    end
  end

  return items[#items]
end

local function sendUnboxChatMessage(player, item, serialNumber, isCrossServer)
  local success, err = pcall(function()
    local function formatNumber(n)
      local formatted = tostring(n)
      while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
      end
      return formatted
    end

    local colorTag = getValueColorTag(item.Value)
    local closeTag = "</font>"
    local message = colorTag .. player.Name .. " unboxed " .. item.Name

    if serialNumber then
      message = message .. " #" .. serialNumber
    end

    message = message .. " (R$" .. formatNumber(item.Value) .. ")" .. closeTag
    chatNotificationEvent:FireAllClients(message)

    if isCrossServer then
      local messageData = {
        PlayerName = player.Name,
        ItemName = item.Name,
        ItemValue = item.Value,
        SerialNumber = serialNumber
      }

      local publishSuccess, publishErr = pcall(function()
        MessagingService:PublishAsync("HighValueUnbox", messageData)
      end)

      if not publishSuccess then
        warn("failed to publish cross-server message: " .. tostring(publishErr))
      end
    end
  end)

  if not success then
    warn("failed to send chat message: " .. tostring(err))
  end
end

local function generateAnimationItems(chosenItem, numItems)
  local allItems = ItemDatabase:GetRollableItems()
  if #allItems == 0 then
    warn("no items in database, cannot generate animation")
    return { chosenItem }
  end

  local animationItems = {}
  local chosenPosition = rnd:NextInteger(15, numItems - 5)

  for i = 1, numItems do
    if i == chosenPosition then
      table.insert(animationItems, chosenItem)
    else
      local randomItem = pickRandomItem(allItems)
      table.insert(animationItems, randomItem or chosenItem)
    end
  end

  return animationItems
end

rollCrateEvent.OnServerEvent:Connect(function(player)
  if not ItemDatabase.IsReady then
    local waitStart = tick()
    while not ItemDatabase.IsReady and (tick() - waitStart) < 30 do
      task.wait(0.1)
    end
    if not ItemDatabase.IsReady then
      warn("itemdatabase failed to load in time")
      return
    end
  end

  if playersRolling[player] then
    return
  end

  playersRolling[player] = true

  local hasFastRoll = false
  local success, result = pcall(function()
    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, FAST_ROLL_GAMEPASS_ID)
  end)
  if success then
    hasFastRoll = result
  else
    warn("failed to check gamepass ownership: " .. tostring(result))
  end

  local allItems = ItemDatabase:GetRollableItems()
  if #allItems == 0 then
    warn("no items in database, cannot roll crate")
    playersRolling[player] = nil
    return
  end

  local playerLuck = player:GetAttribute("Luck") or 1.0
  local playerMythicLuck = player:GetAttribute("MythicLuck") or 1.0
  local playerInsaneLuck = player:GetAttribute("InsaneLuck") or 1.0

  local totalLuck = playerLuck * GLOBAL_LUCK_MULTIPLIER
  local totalMythicLuck = playerMythicLuck
  local totalInsaneLuck = playerInsaneLuck

  local chosenItem = pickRandomItem(allItems, totalLuck, totalMythicLuck, totalInsaneLuck)
  if not chosenItem then
    warn("failed to pick item")
    playersRolling[player] = nil
    return
  end

  local numAnimationItems = rnd:NextInteger(30, 60)
  local animationItems = generateAnimationItems(chosenItem, numAnimationItems)
  local unboxTime = hasFastRoll and FAST_ROLL_TIME or ROLL_TIME
  crateOpenedEvent:FireClient(player, animationItems, chosenItem, unboxTime, nil)

  task.wait(unboxTime)

  local stock = chosenItem.Stock or 0
  local serialNumber = nil

  if stock > 0 then
    serialNumber = ItemDatabase:IncrementStock(chosenItem)
    if not serialNumber then
      warn(chosenItem.Name .. " sold out during roll, rerolling")
      local newRollableItems = ItemDatabase:GetRollableItems()
      if #newRollableItems > 0 then
        chosenItem = pickRandomItem(newRollableItems, totalLuck, totalMythicLuck, totalInsaneLuck)
        local newStock = chosenItem.Stock or 0
        if newStock > 0 then
          serialNumber = ItemDatabase:IncrementStock(chosenItem)
          if not serialNumber then
            warn("reroll also sold out, converting to regular item")
          end
        end
      else
        warn("no rollable items available, cannot award item")
        playersRolling[player] = nil
        return
      end
    end
  end

  local itemToAdd = {
    RobloxId = chosenItem.RobloxId,
    Name = chosenItem.Name,
    Value = chosenItem.Value,
    Rarity = chosenItem.Rarity,
  }

  if serialNumber then
    itemToAdd.SerialNumber = serialNumber
    local updateResultEvent = remoteEvents:FindFirstChild("UpdateCrateResult") or Instance.new("RemoteEvent")
    updateResultEvent.Name = "UpdateCrateResult"
    updateResultEvent.Parent = remoteEvents
    updateResultEvent:FireClient(player, serialNumber)
  end

  DataStoreAPI:AddItem(player, itemToAdd)
  DataStoreAPI:IncrementRolls(player)

  if chosenItem.Value >= 5000000 then
    sendUnboxChatMessage(player, chosenItem, serialNumber, true)
  elseif chosenItem.Value >= 250000 then
    sendUnboxChatMessage(player, chosenItem, serialNumber, false)
  end

  if chosenItem.Value >= 250000 then
    task.spawn(function()
      WebhookHandler:SendItemDrop(player, chosenItem, serialNumber)
    end)
  end

  playersRolling[player] = nil
end)
