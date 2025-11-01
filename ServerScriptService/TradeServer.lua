--VARIABLES
local rs = game.ReplicatedStorage:WaitForChild("TradeReplicatedStorage")
local re = rs:WaitForChild("RemoteEvent")
local config = require(rs:WaitForChild("CONFIGURATION"))

local tradeRequestsFolder = Instance.new("Folder")
tradeRequestsFolder.Name = "TRADE REQUESTS"
tradeRequestsFolder.Parent = rs

local ongoingTradesFolder = Instance.new("Folder")
ongoingTradesFolder.Name = "ONGOING TRADES"
ongoingTradesFolder.Parent = rs


local DataStoreService = game:GetService("DataStoreService")
local tradeHistoryStore = DataStoreService:GetDataStore("TradeHistoryStore")

local function saveTradeToHistory(player1, player2, player1Items, player2Items)
  local timestamp = os.time()

  -- Create trade data for player1
  local player1TradeData = {
    tradedWith = player2.Name,
    tradedWithUserId = player2.UserId,
    timestamp = timestamp,
    given = {},
    received = {}
  }

  -- Create trade data for player2
  local player2TradeData = {
    tradedWith = player1.Name,
    tradedWithUserId = player1.UserId,
    timestamp = timestamp,
    given = {},
    received = {}
  }

  -- Process player1's items (what they gave)
  for _, item in pairs(player1Items) do
    local tradeAmount = item:FindFirstChild("TradeAmount") and item.TradeAmount.Value or 1
    local itemData = {
      name = item.Name,
      amount = tradeAmount,
      value = item:FindFirstChild("Value") and item.Value.Value or 0,
      itemType = item:FindFirstChild("ItemType") and item.ItemType.Value or "unknown",
      decalId = item:FindFirstChild("DecalId") and item.DecalId.Value or ""
    }
    table.insert(player1TradeData.given, itemData)
    table.insert(player2TradeData.received, itemData)
  end

  -- Process player2's items (what they gave)
  for _, item in pairs(player2Items) do
    local tradeAmount = item:FindFirstChild("TradeAmount") and item.TradeAmount.Value or 1
    local itemData = {
      name = item.Name,
      amount = tradeAmount,
      value = item:FindFirstChild("Value") and item.Value.Value or 0,
      itemType = item:FindFirstChild("ItemType") and item.ItemType.Value or "unknown",
      decalId = item:FindFirstChild("DecalId") and item.DecalId.Value or ""
    }
    table.insert(player2TradeData.given, itemData)
    table.insert(player1TradeData.received, itemData)
  end

  -- Save to DataStore
  pcall(function()
    local player1History = tradeHistoryStore:GetAsync(player1.UserId) or {}
    table.insert(player1History, player1TradeData)

    -- Keep only last 50 trades to prevent data limit issues
    if #player1History > 50 then
      table.remove(player1History, 1)
    end

    tradeHistoryStore:SetAsync(player1.UserId, player1History)
  end)

  pcall(function()
    local player2History = tradeHistoryStore:GetAsync(player2.UserId) or {}
    table.insert(player2History, player2TradeData)

    -- Keep only last 50 trades to prevent data limit issues
    if #player2History > 50 then
      table.remove(player2History, 1)
    end

    tradeHistoryStore:SetAsync(player2.UserId, player2History)
  end)
end
local function removeItemFromPlayerCharacter(player, itemName)
  -- Remove from workspace (player character)
  if player.Character then
    local itemInWorkspace = player.Character:FindFirstChild(itemName)
    if itemInWorkspace then
      itemInWorkspace:Destroy()
    end
  end

  -- Remove from equipped items folder
  if player:FindFirstChild("EquippedItems") then
    local equippedItem = player.EquippedItems:FindFirstChild(itemName)
    if equippedItem then
      equippedItem:Destroy()
    end
  end

  -- Remove from player GUI equipped items (folder with string values)
  print("=== GUI DEBUG FOR PLAYER:", player.Name, "ITEM:", itemName, "===")
  print("PlayerGui exists:", player.PlayerGui ~= nil)

  if player.PlayerGui and player.PlayerGui:FindFirstChild("Inventory Gui") then
    print("Inventory Gui found")
    local inventoryGui = player.PlayerGui["Inventory Gui"]

    if inventoryGui:FindFirstChild("Frame") then
      print("Frame found")
      if inventoryGui.Frame:FindFirstChild("Handler") then
        print("Handler found")
        if inventoryGui.Frame.Handler:FindFirstChild("EquippedItems") then
          print("EquippedItems found")
          local equippedItemsFolder = inventoryGui.Frame.Handler.EquippedItems
          print("EquippedItems type:", equippedItemsFolder.ClassName)

          -- List all children in EquippedItems
          print("Children in EquippedItems:")
          for _, child in pairs(equippedItemsFolder:GetChildren()) do
            print("  - Name:", child.Name, "Type:", child.ClassName)
          end

          local guiEquippedItem = equippedItemsFolder:FindFirstChild(itemName)
          print("Found GUI equipped item:", guiEquippedItem ~= nil)
          if guiEquippedItem then
            print("Destroying GUI equipped item:", guiEquippedItem.Name)
            guiEquippedItem:Destroy()
          end
        else
          print("EquippedItems NOT found")
        end
      else
        print("Handler NOT found")
      end
    else
      print("Frame NOT found")
    end
  else
    print("Inventory Gui NOT found")
  end
  print("=== END GUI DEBUG ===")
end
-- HELPER FUNCTION: Find existing item by name (for stacking)
local function findExistingItem(inventory, itemName)
  for _, item in pairs(inventory:GetChildren()) do
    if item.Name == itemName then
      return item
    end
  end
  return nil
end
local function formatNumber(num)
  if num >= 1000000000 then
    return string.format("%.1fB", num / 1000000000)
  elseif num >= 1000000 then
    return string.format("%.1fM", num / 1000000)
  elseif num >= 1000 then
    return string.format("%.1fK", num / 1000)
  else
    return tostring(num)
  end
end

local function calculateOfferValue(offerFolder)
  local totalValue = 0
  for _, item in pairs(offerFolder:GetChildren()) do
    local itemValue = item:FindFirstChild("Value") and item.Value.Value or 0
    local tradeAmount = item:FindFirstChild("TradeAmount") and item.TradeAmount.Value or 1
    totalValue = totalValue + (itemValue * tradeAmount)
  end
  return totalValue
end

-- HELPER FUNCTION: Merge item into existing stack or create new one
local function mergeOrCreateItem(targetInventory, sourceItem, amount)
  local existingItem = findExistingItem(targetInventory, sourceItem.Name)

  if existingItem then
    -- Merge with existing stack
    local currentAmount = existingItem:FindFirstChild("Amount") and existingItem.Amount.Value or 1
    local newTotalAmount = currentAmount + amount

    local amountValue = existingItem:FindFirstChild("Amount") or Instance.new("NumberValue")
    amountValue.Name = "Amount"
    amountValue.Value = newTotalAmount
    amountValue.Parent = existingItem
  else
    -- Create new item
    local newItem = sourceItem:Clone()
    local amountValue = newItem:FindFirstChild("Amount") or Instance.new("NumberValue")
    amountValue.Name = "Amount"
    amountValue.Value = amount
    amountValue.Parent = newItem
    newItem.Parent = targetInventory
  end
end

--REMOVE TRADES FOR THIS PLAYER
function removeTrades(plr)
  for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
    if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
      trade:Destroy()
    end
  end

  for i, request in pairs(tradeRequestsFolder:GetChildren()) do
    if request.Name == plr.Name or request.Value == plr.Name then
      request:Destroy()
    end
  end
end

--REMOVE TRADES WHEN PLAYER DIES
game.Players.PlayerAdded:Connect(function(plr)
  plr.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid").Died:Connect(function()
      removeTrades(plr)
    end)
  end)
end)

--REMOVE TRADES WHEN PLAYER LEAVES
game.Players.PlayerRemoving:Connect(removeTrades)

--RECEIVE CLIENT INFORMATION
re.OnServerEvent:Connect(function(plr, instruction, data)
  --Send a request
  if instruction == "send trade request" then
    local playerSent = data[1]

    if playerSent and playerSent ~= plr then
      local inTrade = false

      for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
        if trade.Sender.Value == playerSent.Name or trade.Sender.Value == plr.Name or trade.Receiver.Value == playerSent.Name or trade.Receiver.Value == plr.Name then
          inTrade = true
          break
        end
      end

      for i, request in pairs(tradeRequestsFolder:GetChildren()) do
        if request.Name == playerSent.Name or request.Name == plr.Name or request.Value == playerSent.Name or request.Value == plr.Name then
          inTrade = true
          break
        end
      end

      if not inTrade then
        local newRequest = Instance.new("StringValue")
        newRequest.Name = plr.Name
        newRequest.Value = playerSent.Name
        newRequest.Parent = tradeRequestsFolder
      end
    end

    --Reject a request
  elseif instruction == "reject trade request" then
    local requestValue = nil
    for i, request in pairs(tradeRequestsFolder:GetChildren()) do
      if request.Name == plr.Name or request.Value == plr.Name then
        requestValue = request
        break
      end
    end

    if requestValue and requestValue.Parent == tradeRequestsFolder and (requestValue.Name == plr.Name or requestValue.Value == plr.Name) then
      requestValue:Destroy()
    end

    --Accept a request
  elseif instruction == "accept trade request" then
    local requestValue = nil
    for i, request in pairs(tradeRequestsFolder:GetChildren()) do
      if request.Name == plr.Name or request.Value == plr.Name then
        requestValue = request
        break
      end
    end

    if requestValue and requestValue.Parent == tradeRequestsFolder and requestValue.Value == plr.Name then
      local senderPlr = game.Players[requestValue.Name]
      local receiverPlr = game.Players[requestValue.Value]

      requestValue:Destroy()

      local tradeFolder = Instance.new("Folder")

      local senderValue = Instance.new("StringValue")
      senderValue.Name = "Sender"
      senderValue.Value = senderPlr.Name
      senderValue.Parent = tradeFolder

      local receiverValue = Instance.new("StringValue")
      receiverValue.Name = "Receiver"
      receiverValue.Value = receiverPlr.Name
      receiverValue.Parent = tradeFolder

      local senderOffer = Instance.new("Folder")
      senderOffer.Name = senderPlr.Name .. "'s offer"
      senderOffer.Parent = tradeFolder

      local receiverOffer = Instance.new("Folder")
      receiverOffer.Name = receiverPlr.Name .. "'s offer"
      receiverOffer.Parent = tradeFolder

      tradeFolder.Parent = ongoingTradesFolder

      local tradeIds = {}

      -- Assign trading IDs to sender's items
      if senderPlr.AccessoryInventory then
        for i, item in pairs(senderPlr.AccessoryInventory:GetChildren()) do
          local tradeId = item:FindFirstChild("TRADING ID") or Instance.new("NumberValue")
          tradeId.Name = "TRADING ID"

          while string.len(tostring(tradeId.Value)) < 1 or table.find(tradeIds, tradeId.Value) do
            tradeId.Value = Random.new():NextNumber(0, 1000000)
          end
          table.insert(tradeIds, tradeId.Value)

          tradeId.Parent = item
        end
      end

      -- Assign trading IDs to receiver's items
      if receiverPlr.AccessoryInventory then
        for i, item in pairs(receiverPlr.AccessoryInventory:GetChildren()) do
          local tradeId = item:FindFirstChild("TRADING ID") or Instance.new("NumberValue")
          tradeId.Name = "TRADING ID"

          while string.len(tostring(tradeId.Value)) < 1 or table.find(tradeIds, tradeId.Value) do
            tradeId.Value = Random.new():NextNumber(0, 1000000)
          end
          table.insert(tradeIds, tradeId.Value)

          tradeId.Parent = item
        end
      end
    end

    --Add an item to the trade (FIXED FOR STACKING - ONE AT A TIME)
  elseif instruction == "add item to trade" then
    local item = data[1]
    local amount = 1 -- Always add one at a time

    if item.Parent == plr.AccessoryInventory then
      local currentTrade = nil
      for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
        if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
          currentTrade = trade
          break
        end
      end

      if currentTrade then
        local plrSlots = currentTrade[plr.Name .. "'s offer"]
        local numItems = #plrSlots:GetChildren()

        if numItems < config.MaxSlots then
          local existingTradeItem = nil

          -- Check if same item type already exists in trade (for stacking)
          for i, plrItem in pairs(plrSlots:GetChildren()) do
            if plrItem.Name == item.Name then
              existingTradeItem = plrItem
              break
            end
          end

          -- Check if player has enough items
          local playerItemAmount = item:FindFirstChild("Amount") and item.Amount.Value or 1

          -- Reset acceptance status when trade changes
          if currentTrade.Receiver:FindFirstChild("ACCEPTED") then
            currentTrade.Receiver.ACCEPTED:Destroy()
          end
          if currentTrade.Sender:FindFirstChild("ACCEPTED") then
            currentTrade.Sender.ACCEPTED:Destroy()
          end

          if existingTradeItem then
            -- Add to existing stack in trade
            local currentTradeAmount = existingTradeItem:FindFirstChild("TradeAmount") and
                existingTradeItem.TradeAmount.Value or 1
            local newTradeAmount = currentTradeAmount + amount

            if newTradeAmount <= playerItemAmount then
              local tradeAmountValue = existingTradeItem:FindFirstChild("TradeAmount") or Instance.new("NumberValue")
              tradeAmountValue.Name = "TradeAmount"
              tradeAmountValue.Value = newTradeAmount
              tradeAmountValue.Parent = existingTradeItem
            end
          else
            -- Create new trade item (only if player has items)
            if playerItemAmount >= amount then
              local clonedItem = item:Clone()
              local tradeAmount = clonedItem:FindFirstChild("TradeAmount") or Instance.new("NumberValue")
              tradeAmount.Name = "TradeAmount"
              tradeAmount.Value = amount
              tradeAmount.Parent = clonedItem

              clonedItem.Parent = plrSlots
            end
          end
        end
      end
    end

    --Remove an item from the trade (ONE AT A TIME)
  elseif instruction == "remove item from trade" then
    local item = data[1]
    local amount = 1 -- Always remove one at a time

    if item.Parent == plr.AccessoryInventory then
      local currentTrade = nil
      for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
        if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
          currentTrade = trade
          break
        end
      end

      if currentTrade then
        local plrSlots = currentTrade[plr.Name .. "'s offer"]

        for i, plrItem in pairs(plrSlots:GetChildren()) do
          if plrItem.Name == item.Name then
            -- Reset acceptance status
            if currentTrade.Receiver:FindFirstChild("ACCEPTED") then
              currentTrade.Receiver.ACCEPTED:Destroy()
            end
            if currentTrade.Sender:FindFirstChild("ACCEPTED") then
              currentTrade.Sender.ACCEPTED:Destroy()
            end

            local currentTradeAmount = plrItem:FindFirstChild("TradeAmount") and plrItem.TradeAmount.Value or 1

            if amount >= currentTradeAmount then
              -- Remove entire stack from trade
              plrItem:Destroy()
            else
              -- Reduce stack size in trade
              local tradeAmountValue = plrItem:FindFirstChild("TradeAmount") or Instance.new("NumberValue")
              tradeAmountValue.Name = "TradeAmount"
              tradeAmountValue.Value = currentTradeAmount - amount
              tradeAmountValue.Parent = plrItem
            end
            break
          end
        end
      end
    end

    --Accept a trade
    -- SERVER SCRIPT CHANGES (paste.txt)

    -- Add this helper function after the mergeOrCreateItem function
    local function formatNumber(num)
      if num >= 1000000000 then
        return string.format("%.1fB", num / 1000000000)
      elseif num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
      elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
      else
        return tostring(num)
      end
    end

    -- Add this function to calculate offer values
    local function calculateOfferValue(offerFolder)
      local totalValue = 0
      for _, item in pairs(offerFolder:GetChildren()) do
        local itemValue = item:FindFirstChild("Value") and item.Value.Value or 0
        local tradeAmount = item:FindFirstChild("TradeAmount") and item.TradeAmount.Value or 1
        totalValue = totalValue + (itemValue * tradeAmount)
      end
      return totalValue
    end

    -- Replace the trade acceptance section (around line 258) with this updated version:
  elseif instruction == "accept trade" then
    local currentTrade = nil
    for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
      if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
        currentTrade = trade
        break
      end
    end

    if currentTrade then
      local plrValue = currentTrade.Sender.Value == plr.Name and currentTrade.Sender or
          currentTrade.Receiver.Value == plr.Name and currentTrade.Receiver

      if plrValue then
        if not plrValue:FindFirstChild("ACCEPTED") then
          local acceptedValue = Instance.new("StringValue")
          acceptedValue.Name = "ACCEPTED"
          acceptedValue.Parent = plrValue
        else
          plrValue.ACCEPTED:Destroy()
        end
      end

      if currentTrade.Sender:FindFirstChild("ACCEPTED") and currentTrade.Receiver:FindFirstChild("ACCEPTED") then
        -- Create countdown timer
        local timeLeft = config.TimeBeforeTradeConfirmed
        local timerValue = currentTrade:FindFirstChild("TradeTimer") or Instance.new("NumberValue")
        timerValue.Name = "TradeTimer"
        timerValue.Value = timeLeft
        timerValue.Parent = currentTrade

        -- Countdown loop
        local connection
        connection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
          timeLeft = timeLeft - deltaTime
          timerValue.Value = math.max(0, timeLeft)

          if timeLeft <= 0 then
            connection:Disconnect()
            timerValue:Destroy()
          end
        end)

        task.wait(config.TimeBeforeTradeConfirmed)

        if currentTrade.Sender:FindFirstChild("ACCEPTED") and currentTrade.Receiver:FindFirstChild("ACCEPTED") then
          local senderPlr = game.Players[currentTrade.Sender.Value]
          local senderSlots = currentTrade[senderPlr.Name .. "'s offer"]

          local receiverPlr = game.Players[currentTrade.Receiver.Value]
          local receiverSlots = currentTrade[receiverPlr.Name .. "'s offer"]

          -- Save trade to history BEFORE processing items
          local senderItemsCopy = {}
          local receiverItemsCopy = {}

          -- Copy sender's items for history
          for _, item in pairs(senderSlots:GetChildren()) do
            table.insert(senderItemsCopy, item)
          end

          -- Copy receiver's items for history
          for _, item in pairs(receiverSlots:GetChildren()) do
            table.insert(receiverItemsCopy, item)
          end

          -- Save trade history
          saveTradeToHistory(senderPlr, receiverPlr, senderItemsCopy, receiverItemsCopy)

          -- Process sender's items to receiver (WITH STACKING AND CLEANUP)
          if senderPlr.AccessoryInventory and receiverPlr.AccessoryInventory then
            for i, senderSlot in pairs(senderSlots:GetChildren()) do
              for x, senderItem in pairs(senderPlr.AccessoryInventory:GetChildren()) do
                if senderItem.Name == senderSlot.Name then
                  local tradeAmount = senderSlot:FindFirstChild("TradeAmount") and senderSlot.TradeAmount.Value or 1
                  local currentAmount = senderItem:FindFirstChild("Amount") and senderItem.Amount.Value or 1

                  -- Remove traded items from sender's character and equipped items
                  removeItemFromPlayerCharacter(senderPlr, senderItem.Name, tradeAmount)

                  -- Transfer to receiver with stacking
                  mergeOrCreateItem(receiverPlr.AccessoryInventory, senderItem, tradeAmount)

                  -- Update sender's item
                  if tradeAmount >= currentAmount then
                    senderItem:Destroy()
                  else
                    local amountValue = senderItem:FindFirstChild("Amount") or Instance.new("NumberValue")
                    amountValue.Name = "Amount"
                    amountValue.Value = currentAmount - tradeAmount
                    amountValue.Parent = senderItem
                  end
                  break
                end
              end
            end
          end

          -- Process receiver's items to sender (WITH STACKING AND CLEANUP)
          if receiverPlr.AccessoryInventory and senderPlr.AccessoryInventory then
            for i, receiverSlot in pairs(receiverSlots:GetChildren()) do
              for x, receiverItem in pairs(receiverPlr.AccessoryInventory:GetChildren()) do
                if receiverItem.Name == receiverSlot.Name then
                  local tradeAmount = receiverSlot:FindFirstChild("TradeAmount") and receiverSlot.TradeAmount.Value or 1
                  local currentAmount = receiverItem:FindFirstChild("Amount") and receiverItem.Amount.Value or 1

                  -- Remove traded items from receiver's character and equipped items
                  removeItemFromPlayerCharacter(receiverPlr, receiverItem.Name, tradeAmount)

                  -- Transfer to sender with stacking
                  mergeOrCreateItem(senderPlr.AccessoryInventory, receiverItem, tradeAmount)

                  -- Update receiver's item
                  if tradeAmount >= currentAmount then
                    receiverItem:Destroy()
                  else
                    local amountValue = receiverItem:FindFirstChild("Amount") or Instance.new("NumberValue")
                    amountValue.Name = "Amount"
                    amountValue.Value = currentAmount - tradeAmount
                    amountValue.Parent = receiverItem
                  end
                  break
                end
              end
            end
          end

          currentTrade:Destroy()
        end
      end
    end
  elseif instruction == "get trade history" then
    spawn(function()
      local success, history = pcall(function()
        return tradeHistoryStore:GetAsync(plr.UserId) or {}
      end)

      if success then
        re:FireClient(plr, "trade history response", history)
      else
        re:FireClient(plr, "trade history response", {})
      end
    end)


    --Reject a trade
  elseif instruction == "reject trade" then
    for i, trade in pairs(ongoingTradesFolder:GetChildren()) do
      if trade.Sender.Value == plr.Name or trade.Receiver.Value == plr.Name then
        trade:Destroy()
        break
      end
    end
  end
end)
