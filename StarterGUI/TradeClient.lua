-- TradeClient.lua
-- Trading system client for crate opening game
-- Works with DataStoreAPI inventory system (NO AccessoryInventory)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local client = Players.LocalPlayer

-- Wait for Trade system setup
local rs = ReplicatedStorage:WaitForChild("TradeReplicatedStorage")
local re = rs:WaitForChild("RemoteEvent")
local config = require(rs:WaitForChild("CONFIGURATION"))

local tradeRequestsFolder = rs:WaitForChild("TRADE REQUESTS")
local ongoingTradesFolder = rs:WaitForChild("ONGOING TRADES")

-- UI elements
local gui = script.Parent
local openBtn = gui:WaitForChild("OpenSendTrades")
local sendTradesFrame = gui:WaitForChild("SendTradesFrame")
local tradeRequestFrame = gui:WaitForChild("TradeRequestFrame")
local tradeFrame = gui:WaitForChild("TradeFrame")

sendTradesFrame.Visible = false
tradeRequestFrame.Visible = false
tradeFrame.Visible = false

-- Local data (received from server)
local tradeableInventory = {}
local searchQuery = ""

-- Helper: Format numbers
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

-- Helper: Calculate offer value
local function calculateOfferValue(offerFolder)
	local totalValue = 0
	for _, item in pairs(offerFolder:GetChildren()) do
		if item:IsA("ObjectValue") and item.Value then
			local data = item.Value
			totalValue = totalValue + (data.Value * data.TradeAmount)
		end
	end
	return totalValue
end

-- Helper: Get amount in trade
local function getAmountInTrade(robloxId, serialNumber)
	for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
		if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
			if trade.Sender.Value == client.Name or trade.Receiver.Value == client.Name then
				local clientOffer = trade:FindFirstChild(client.Name .. "'s offer")
				if clientOffer then
					for _, tradeItem in pairs(clientOffer:GetChildren()) do
						if tradeItem:IsA("ObjectValue") and tradeItem.Value then
							local data = tradeItem.Value
							if data.RobloxId == robloxId and data.SerialNumber == serialNumber then
								return data.TradeAmount
							end
						end
					end
				end
			end
		end
	end
	return 0
end

-- Helper: Search filter
local function itemMatchesSearch(item, query)
	if query == "" then return true end
	return string.find(item.Name:lower(), query:lower(), 1, true) ~= nil
end

-- Helper: Sort by value
local function sortItemsByValue(items)
	local sorted = {}
	for _, item in pairs(items) do
		table.insert(sorted, item)
	end
	table.sort(sorted, function(a, b)
		return (a.Value or 0) > (b.Value or 0)
	end)
	return sorted
end

-- Create item button
local function createItemButton(item, isForInventory)
	local template = script:WaitForChild("ItemButton")
	local button = template:Clone()
	
	local totalAmount = item.Amount or 1
	local tradeAmount = getAmountInTrade(item.RobloxId, item.SerialNumber)
	local availableAmount = totalAmount - tradeAmount
	
	-- Set name
	if isForInventory then
		if item.SerialNumber then
			button.ItemName.Text = item.Name .. " #" .. item.SerialNumber
		elseif availableAmount > 1 then
			button.ItemName.Text = item.Name .. " x" .. availableAmount
		else
			button.ItemName.Text = item.Name
		end
	else
		if item.SerialNumber then
			button.ItemName.Text = item.Name .. " #" .. item.SerialNumber
		elseif tradeAmount > 1 then
			button.ItemName.Text = item.Name .. " x" .. tradeAmount
		else
			button.ItemName.Text = item.Name
		end
	end
	
	-- Set image
	if button:FindFirstChild("ItemImageLabel") then
		button.ItemImageLabel.Image = "rbxassetid://" .. item.RobloxId
	end
	
	-- In trade indicator
	if button:FindFirstChild("IsInTrade") then
		button.IsInTrade.Visible = (tradeAmount > 0) and isForInventory
	end
	
	return button
end

-- Update inventory display
local function updateInventoryDisplay()
	local inventoryList = tradeFrame.InventoryFrame.InventoryList
	
	-- Clear existing
	for _, child in pairs(inventoryList:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	
	-- Filter and sort
	local filtered = {}
	for _, item in pairs(tradeableInventory) do
		if itemMatchesSearch(item, searchQuery) then
			table.insert(filtered, item)
		end
	end
	
	local sorted = sortItemsByValue(filtered)
	
	-- Create buttons
	for _, item in pairs(sorted) do
		local button = createItemButton(item, true)
		
		button.MouseButton1Click:Connect(function()
			local tradeAmount = getAmountInTrade(item.RobloxId, item.SerialNumber)
			local availableAmount = (item.Amount or 1) - tradeAmount
			
			if availableAmount > 0 then
				re:FireServer("add item to trade", {
					RobloxId = item.RobloxId,
					Name = item.Name,
					Value = item.Value,
					Rarity = item.Rarity,
					SerialNumber = item.SerialNumber
				})
			end
		end)
		
		button.Parent = inventoryList
	end
end

-- Update trade offers display
local function updateTradeOffersDisplay()
	local currentTrade = nil
	for _, trade in pairs(ongoingTradesFolder:GetChildren()) do
		if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
			if trade.Sender.Value == client.Name or trade.Receiver.Value == client.Name then
				currentTrade = trade
				break
			end
		end
	end
	
	if not currentTrade then return end
	
	local clientOffer = currentTrade:FindFirstChild(client.Name .. "'s offer")
	local otherPlayer = currentTrade.Sender.Value == client.Name and currentTrade.Receiver.Value or currentTrade.Sender.Value
	local otherOffer = currentTrade:FindFirstChild(otherPlayer .. "'s offer")
	
	-- Update your offer
	local yourOfferList = tradeFrame.TradingFrame.YourOfferFrame.YourOfferList
	for _, child in pairs(yourOfferList:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	
	if clientOffer then
		for _, tradeItem in pairs(clientOffer:GetChildren()) do
			if tradeItem:IsA("ObjectValue") and tradeItem.Value then
				local data = tradeItem.Value
				local button = createItemButton(data, false)
				
				button.MouseButton1Click:Connect(function()
					re:FireServer("remove item from trade", {
						RobloxId = data.RobloxId,
						Name = data.Name,
						Value = data.Value,
						Rarity = data.Rarity,
						SerialNumber = data.SerialNumber
					})
				end)
				
				button.Parent = yourOfferList
			end
		end
	end
	
	-- Update their offer
	local theirOfferList = tradeFrame.TradingFrame.TheirOfferFrame.TheirOfferList
	for _, child in pairs(theirOfferList:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	
	if otherOffer then
		for _, tradeItem in pairs(otherOffer:GetChildren()) do
			if tradeItem:IsA("ObjectValue") and tradeItem.Value then
				local data = tradeItem.Value
				local button = createItemButton(data, false)
				button.Parent = theirOfferList
			end
		end
	end
	
	-- Update values
	local clientOfferValue = clientOffer and calculateOfferValue(clientOffer) or 0
	local otherOfferValue = otherOffer and calculateOfferValue(otherOffer) or 0
	
	if tradeFrame.TradingFrame.YourOfferFrame:FindFirstChild("YourValue") then
		tradeFrame.TradingFrame.YourOfferFrame.YourValue.Text = "Value: " .. formatNumber(clientOfferValue)
	end
	
	if tradeFrame.TradingFrame.TheirOfferFrame:FindFirstChild("TheirValue") then
		tradeFrame.TradingFrame.TheirOfferFrame.TheirValue.Text = "Value: " .. formatNumber(otherOfferValue)
	end
	
	if tradeFrame.TradingFrame.TheirOfferFrame:FindFirstChild("TheirOfferText") then
		tradeFrame.TradingFrame.TheirOfferFrame.TheirOfferText.Text = otherPlayer .. "'s offer"
	end
	
	-- Update accept button
	local accepted = false
	if currentTrade.Sender.Value == client.Name then
		accepted = currentTrade.Sender:FindFirstChild("ACCEPTED") ~= nil
	else
		accepted = currentTrade.Receiver:FindFirstChild("ACCEPTED") ~= nil
	end
	
	if tradeFrame.TradingFrame:FindFirstChild("AcceptButton") then
		tradeFrame.TradingFrame.AcceptButton.Text = accepted and "Unaccept" or "Accept"
	end
	
	-- Update timer
	local timer = currentTrade:FindFirstChild("TradeTimer")
	if timer and tradeFrame.TradingFrame:FindFirstChild("TimerText") then
		tradeFrame.TradingFrame.TimerText.Text = "Trade completing in: " .. math.ceil(timer.Value) .. "s"
		tradeFrame.TradingFrame.TimerText.Visible = true
	elseif tradeFrame.TradingFrame:FindFirstChild("TimerText") then
		tradeFrame.TradingFrame.TimerText.Visible = false
	end
end

-- Open/close trade UI
openBtn.MouseButton1Click:Connect(function()
	sendTradesFrame.Visible = not sendTradesFrame.Visible
end)

-- Update player list
local function updatePlayerList()
	if not sendTradesFrame:FindFirstChild("PlayerList") then return end
	
	for _, child in pairs(sendTradesFrame.PlayerList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= client then
			local playerButton = Instance.new("TextButton")
			playerButton.Size = UDim2.new(1, -10, 0, 30)
			playerButton.Text = player.Name
			playerButton.Parent = sendTradesFrame.PlayerList
			
			playerButton.MouseButton1Click:Connect(function()
				re:FireServer("send trade request", {player})
				sendTradesFrame.Visible = false
			end)
		end
	end
end

if sendTradesFrame:FindFirstChild("PlayerList") then
	sendTradesFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if sendTradesFrame.Visible then
			updatePlayerList()
		end
	end)
end

-- Handle trade requests
tradeRequestsFolder.ChildAdded:Connect(function(request)
	if request.Value == client.Name then
		tradeRequestFrame.Visible = true
		if tradeRequestFrame:FindFirstChild("RequestText") then
			tradeRequestFrame.RequestText.Text = request.Name .. " wants to trade!"
		end
		
		if tradeRequestFrame:FindFirstChild("AcceptButton") then
			tradeRequestFrame.AcceptButton.MouseButton1Click:Connect(function()
				re:FireServer("accept trade request")
				tradeRequestFrame.Visible = false
			end)
		end
		
		if tradeRequestFrame:FindFirstChild("DeclineButton") then
			tradeRequestFrame.DeclineButton.MouseButton1Click:Connect(function()
				re:FireServer("reject trade request")
				tradeRequestFrame.Visible = false
			end)
		end
	end
end)

tradeRequestsFolder.ChildRemoved:Connect(function()
	tradeRequestFrame.Visible = false
end)

-- Handle ongoing trades
ongoingTradesFolder.ChildAdded:Connect(function(trade)
	if trade:FindFirstChild("Sender") and trade:FindFirstChild("Receiver") then
		if trade.Sender.Value == client.Name or trade.Receiver.Value == client.Name then
			-- Request inventory from server
			re:FireServer("get tradeable inventory")
			
			tradeFrame.Visible = true
			updateInventoryDisplay()
			updateTradeOffersDisplay()
		end
	end
end)

ongoingTradesFolder.ChildRemoved:Connect(function()
	tradeFrame.Visible = false
	tradeableInventory = {}
end)

-- Monitor trade changes
ongoingTradesFolder.DescendantAdded:Connect(function()
	updateTradeOffersDisplay()
	updateInventoryDisplay()
end)

ongoingTradesFolder.DescendantRemoving:Connect(function()
	task.wait()
	updateTradeOffersDisplay()
	updateInventoryDisplay()
end)

-- Accept button
if tradeFrame.TradingFrame:FindFirstChild("AcceptButton") then
	tradeFrame.TradingFrame.AcceptButton.MouseButton1Click:Connect(function()
		re:FireServer("accept trade")
	end)
end

-- Cancel button
if tradeFrame.TradingFrame:FindFirstChild("CancelButton") then
	tradeFrame.TradingFrame.CancelButton.MouseButton1Click:Connect(function()
		re:FireServer("cancel trade")
		tradeFrame.Visible = false
	end)
end

-- Search bar
if tradeFrame.InventoryFrame:FindFirstChild("SearchBar") then
	tradeFrame.InventoryFrame.SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
		searchQuery = tradeFrame.InventoryFrame.SearchBar.Text
		updateInventoryDisplay()
	end)
end

-- Receive data from server
re.OnClientEvent:Connect(function(instruction, data)
	if instruction == "receive tradeable inventory" then
		tradeableInventory = data
		updateInventoryDisplay()
	elseif instruction == "trade completed" then
		tradeFrame.Visible = false
		tradeableInventory = {}
		print("✅ Trade completed successfully!")
	end
end)

print("✅ TradeClient loaded (using server inventory)")
