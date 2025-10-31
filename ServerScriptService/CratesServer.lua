-- CratesServer.lua
-- Server-side crate opening system with item database integration

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local ItemDatabase = require(script.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

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

local rnd = Random.new()
local playersRolling = {}

-- Configuration
local ROLL_COST = 0 -- Free rolls
local ROLL_TIME = 5 -- Normal roll time in seconds
local FAST_ROLL_TIME = 2 -- Fast roll time (2.5x faster)
local FAST_ROLL_GAMEPASS_ID = 1242040274 -- Old game's fast roll gamepass

-- Helper function to pick random item based on value (inverse probability)
function pickRandomItem(items)
  if #items == 0 then
    return nil
  end

  -- Calculate total inverse value
  local totalInverseValue = 0
  for _, item in ipairs(items) do
    totalInverseValue = totalInverseValue + (1 / item.Value)
  end

  -- Pick random item (weighted by inverse value - higher value = lower chance)
  local randomValue = rnd:NextNumber() * totalInverseValue
  local cumulative = 0

  for _, item in ipairs(items) do
    cumulative = cumulative + (1 / item.Value)
    if randomValue <= cumulative then
      return item
    end
  end

  -- Fallback (shouldn't happen)
  return items[#items]
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

  -- Pick random item (weighted by inverse value)
  local chosenItem = pickRandomItem(allItems)

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
        chosenItem = pickRandomItem(newRollableItems)

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
  DataStoreAPI:IncrementCasesOpened(player)

  playersRolling[player] = nil
end)
