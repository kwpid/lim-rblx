local client = game.Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("TradeConfiguration"))

local tradeRequestsFolder = ReplicatedStorage:WaitForChild("TRADE REQUESTS")
local ongoingTradesFolder = ReplicatedStorage:WaitForChild("ONGOING TRADES")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
if not remoteEvents then
	warn("❌ TradeClient: RemoteEvents folder not found!")
	return
end

local tradeEvent = remoteEvents:WaitForChild("TradeEvent", 30)
if not tradeEvent then
	warn("❌ TradeClient: TradeEvent not found!")
	return
end

local getInventoryFunction = remoteEvents:WaitForChild("GetInventoryFunction", 30)
if not getInventoryFunction then
	warn("❌ TradeClient: GetInventoryFunction not found!")
	return
end

local gui = script.Parent

local openBtn = gui:WaitForChild("OpenSendTrades")
local sendTradesFrame = gui:WaitForChild("SendTradesFrame")
local tradeRequestFrame = gui:WaitForChild("TradeRequestFrame")
local tradeFrame = gui:WaitForChild("TradeFrame")

sendTradesFrame.Visible = false
tradeRequestFrame.Visible = false
tradeFrame.Visible = false

tradeRequestsFolder.ChildAdded:Connect(function(child)
	if child.Value == client.Name then
		tradeRequestFrame.TradeText.Text = child.Name .. " sent you a trade request!"

		tradeRequestFrame.AcceptButton.Visible = true
		tradeRequestFrame.RejectButton.Visible = true
		tradeRequestFrame.Visible = true
	elseif child.Name == client.Name then
		tradeRequestFrame.TradeText.Text = "You sent a trade request to " .. child.Value

		tradeRequestFrame.AcceptButton.Visible = false
		tradeRequestFrame.RejectButton.Visible = true
		tradeRequestFrame.Visible = true
	end
end)

tradeRequestsFolder.ChildRemoved:Connect(function(child)
	if child.Value == client.Name or child.Name == client.Name then
		tradeRequestFrame.Visible = false
	end
end)

local function getItemThumbnail(robloxId)
	local success, result = pcall(function()
		return "rbxthumb://type=Asset&id=" .. robloxId .. "&w=150&h=150"
	end)
	if success then
		return result
	else
		return ""
	end
end

local currentInventoryButtons = {}

ongoingTradesFolder.ChildAdded:Connect(function(child)
	if child:WaitForChild("Sender").Value == client.Name or child:WaitForChild("Receiver").Value == client.Name then
		local clientValue = child:WaitForChild("Sender").Value == client.Name and child.Sender or child.Receiver
		local otherPlrValue = clientValue.Name == "Sender" and child.Receiver or child.Sender

		clientValue.AncestryChanged:Connect(function()
			if clientValue.Parent == nil then
				tradeFrame.Visible = false
				openBtn.Visible = true
				for _, btn in pairs(currentInventoryButtons) do
					if btn then
						btn:Destroy()
					end
				end
				currentInventoryButtons = {}
			end
		end)

		tradeRequestFrame.Visible = false
		sendTradesFrame.Visible = false
		openBtn.Visible = false

		tradeFrame.TradingFrame.TradingWithName.Text = "Trading with " .. otherPlrValue.Value
		tradeFrame.TradingFrame.TheirOfferFrame.TheirOfferText.Text = otherPlrValue.Value .. "'s offer"
		tradeFrame.TradingFrame.PlayerAccepted.Text = ""

		tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(58, 191, 232)

		for _, child in pairs(tradeFrame.TradingFrame.YourOfferFrame.Slots:GetChildren()) do
			if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, child in pairs(tradeFrame.TradingFrame.TheirOfferFrame.Slots:GetChildren()) do
			if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
				child:Destroy()
			end
		end

		otherPlrValue.ChildAdded:Connect(function(child)
			if child.Name == "ACCEPTED" then
				tradeFrame.TradingFrame.PlayerAccepted.Text = otherPlrValue.Value .. " has accepted"
			end
		end)
		otherPlrValue.ChildRemoved:Connect(function(child)
			if child.Name == "ACCEPTED" then
				tradeFrame.TradingFrame.PlayerAccepted.Text = ""
			end
		end)

		local inventoryList = tradeFrame.InventoryFrame.InventoryList
		for _, child in pairs(inventoryList:GetChildren()) do
			if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame") then
				child:Destroy()
			end
		end
		currentInventoryButtons = {}

		local success, inventory = pcall(function()
			return getInventoryFunction:InvokeServer()
		end)

		if not success then
			warn("❌ TradeClient: Failed to get inventory: " .. tostring(inventory))
			return
		end

		if not inventory then
			warn("❌ TradeClient: Inventory is nil")
			return
		end

		local itemsToDisplay = {}

		for _, item in ipairs(inventory) do
			if item.SerialNumber then
				table.insert(itemsToDisplay, {
					RobloxId = item.RobloxId,
					Name = item.Name,
					Value = item.Value,
					Rarity = item.Rarity,
					SerialNumber = item.SerialNumber,
					Amount = 1,
					MaxAmount = 1,
					isSerial = true
				})
			else
				local found = false
				for _, displayItem in ipairs(itemsToDisplay) do
					if displayItem.RobloxId == item.RobloxId and not displayItem.isSerial then
						displayItem.MaxAmount = item.Amount or 1
						found = true
						break
					end
				end
				if not found then
					table.insert(itemsToDisplay, {
						RobloxId = item.RobloxId,
						Name = item.Name,
						Value = item.Value,
						Rarity = item.Rarity,
						Amount = 0,
						MaxAmount = item.Amount or 1,
						isSerial = false
					})
				end
			end
		end

		for _, displayItem in ipairs(itemsToDisplay) do
			local newItemButton = script:WaitForChild("ItemButton"):Clone()
			local uniqueId = displayItem.RobloxId .. "_" .. (displayItem.SerialNumber or "regular")
			newItemButton.Name = uniqueId

			if displayItem.isSerial then
				newItemButton.ItemName.Text = displayItem.Name .. " #" .. displayItem.SerialNumber
			else
				newItemButton.ItemName.Text = displayItem.Name
			end

			newItemButton.ItemImageLabel.Image = getItemThumbnail(displayItem.RobloxId)

			if not displayItem.isSerial then
				local amountLabel = Instance.new("TextLabel")
				amountLabel.Name = "AmountLabel"
				amountLabel.Size = UDim2.new(1, 0, 0.2, 0)
				amountLabel.Position = UDim2.new(0, 0, 0.8, 0)
				amountLabel.BackgroundTransparency = 0.5
				amountLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				amountLabel.Text = "0/" .. displayItem.MaxAmount
				amountLabel.TextScaled = true
				amountLabel.Font = Enum.Font.GothamBold
				amountLabel.Parent = newItemButton
			end

			newItemButton.MouseButton1Click:Connect(function()
				if displayItem.isSerial then
					local alreadyInTrade = tradeFrame.TradingFrame.YourOfferFrame.Slots:FindFirstChild("Offer_" .. uniqueId)
					if alreadyInTrade then
						tradeEvent:FireServer("remove item from trade", {displayItem.RobloxId, displayItem.SerialNumber})
					else
						tradeEvent:FireServer("add item to trade", {displayItem.RobloxId, displayItem.SerialNumber})
					end
				else
					if displayItem.Amount < displayItem.MaxAmount then
						displayItem.Amount = displayItem.Amount + 1
						local amountLabel = newItemButton:FindFirstChild("AmountLabel")
						if amountLabel then
							amountLabel.Text = displayItem.Amount .. "/" .. displayItem.MaxAmount
						end
						tradeEvent:FireServer("add item to trade", {displayItem.RobloxId, nil, 1})
					end
				end
			end)

			newItemButton.MouseButton2Click:Connect(function()
				if not displayItem.isSerial then
					if displayItem.Amount > 0 then
						displayItem.Amount = displayItem.Amount - 1
						local amountLabel = newItemButton:FindFirstChild("AmountLabel")
						if amountLabel then
							amountLabel.Text = displayItem.Amount .. "/" .. displayItem.MaxAmount
						end
						tradeEvent:FireServer("remove item from trade", {displayItem.RobloxId, nil, 1})
					end
				end
			end)

			newItemButton.Parent = inventoryList
			table.insert(currentInventoryButtons, newItemButton)
		end

		local clientOffer = child[clientValue.Value .. "'s offer"]

		clientOffer.ChildAdded:Connect(function(slotChild)
			task.wait()
			local robloxId = slotChild:FindFirstChild("RobloxId")
			local serialNumber = slotChild:FindFirstChild("SerialNumber")
			local amount = slotChild:FindFirstChild("Amount")
			local itemName = slotChild:FindFirstChild("ItemName")

			if not robloxId or not itemName then return end

			local newToolButton = script.ItemButton:Clone()
			newToolButton.Name = "Offer_" .. (serialNumber and (robloxId.Value .. "_" .. serialNumber.Value) or robloxId.Value)
			newToolButton.ItemName.Text = itemName.Value
			if serialNumber then
				newToolButton.ItemName.Text = itemName.Value .. " #" .. serialNumber.Value
			elseif amount then
				newToolButton.ItemName.Text = itemName.Value .. " x" .. amount.Value
			end

			newToolButton.ItemImageLabel.Image = getItemThumbnail(robloxId.Value)

			newToolButton.MouseButton1Click:Connect(function()
				if serialNumber then
					tradeEvent:FireServer("remove item from trade", {robloxId.Value, serialNumber.Value})
				else
					tradeEvent:FireServer("remove item from trade", {robloxId.Value, nil, 1})
				end
			end)

			slotChild.ChildAdded:Connect(function(child)
				if child.Name == "Amount" then
					task.wait(0.1)
					newToolButton.ItemName.Text = itemName.Value .. " x" .. child.Value
				end
			end)

			slotChild.ChildRemoved:Connect(function(child)
				if child.Name == "Amount" then
					task.wait(0.1)
					local currentAmount = slotChild:FindFirstChild("Amount")
					if currentAmount then
						newToolButton.ItemName.Text = itemName.Value .. " x" .. currentAmount.Value
					else
						newToolButton:Destroy()
					end
				end
			end)

			slotChild:GetPropertyChangedSignal("Parent"):Connect(function()
				if slotChild.Parent == nil then
					newToolButton:Destroy()
				end
			end)

			newToolButton.Parent = tradeFrame.TradingFrame.YourOfferFrame.Slots
		end)

		local otherPlrOffer = child[otherPlrValue.Value .. "'s offer"]

		otherPlrOffer.ChildAdded:Connect(function(slotChild)
			task.wait()
			local robloxId = slotChild:FindFirstChild("RobloxId")
			local serialNumber = slotChild:FindFirstChild("SerialNumber")
			local amount = slotChild:FindFirstChild("Amount")
			local itemName = slotChild:FindFirstChild("ItemName")

			if not robloxId or not itemName then return end

			local newToolButton = script.ItemButton:Clone()
			newToolButton.Name = "TheirOffer_" .. (serialNumber and (robloxId.Value .. "_" .. serialNumber.Value) or robloxId.Value)
			newToolButton.ItemName.Text = itemName.Value
			if serialNumber then
				newToolButton.ItemName.Text = itemName.Value .. " #" .. serialNumber.Value
			elseif amount then
				newToolButton.ItemName.Text = itemName.Value .. " x" .. amount.Value
			end

			newToolButton.ItemImageLabel.Image = getItemThumbnail(robloxId.Value)
			newToolButton.AutoButtonColor = false

			slotChild.ChildAdded:Connect(function(child)
				if child.Name == "Amount" then
					task.wait(0.1)
					newToolButton.ItemName.Text = itemName.Value .. " x" .. child.Value
				end
			end)

			slotChild.ChildRemoved:Connect(function(child)
				if child.Name == "Amount" then
					task.wait(0.1)
					local currentAmount = slotChild:FindFirstChild("Amount")
					if currentAmount then
						newToolButton.ItemName.Text = itemName.Value .. " x" .. currentAmount.Value
					else
						newToolButton:Destroy()
					end
				end
			end)

			slotChild:GetPropertyChangedSignal("Parent"):Connect(function()
				if slotChild.Parent == nil then
					newToolButton:Destroy()
				end
			end)

			newToolButton.Parent = tradeFrame.TradingFrame.TheirOfferFrame.Slots
		end)

		tradeFrame.Visible = true
	end
end)

openBtn.MouseButton1Click:Connect(function()
	if sendTradesFrame.Visible == true then
		sendTradesFrame.Visible = false
	elseif tradeFrame.Visible == false then
		for _, child in pairs(sendTradesFrame.PlayerList:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		for _, plr in pairs(game.Players:GetPlayers()) do
			if plr ~= client then
				local playerFrame = script:WaitForChild("PlayerFrame"):Clone()
				playerFrame.PlayerDisplayName.Text = plr.DisplayName
				playerFrame.PlayerUserName.Text = "@" .. plr.Name
				playerFrame.PlayerImage.Image = game.Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100)

				playerFrame.SendButton.MouseButton1Click:Connect(function()
					if tradeRequestFrame.Visible == false then
						tradeEvent:FireServer("send trade request", { plr })
					end
				end)

				playerFrame.Parent = sendTradesFrame.PlayerList
			end
		end

		sendTradesFrame.Visible = true
	end
end)

sendTradesFrame.CloseButton.MouseButton1Click:Connect(function()
	sendTradesFrame.Visible = false
end)

tradeRequestFrame.RejectButton.MouseButton1Click:Connect(function()
	tradeEvent:FireServer("reject trade request")
end)

tradeRequestFrame.AcceptButton.MouseButton1Click:Connect(function()
	tradeEvent:FireServer("accept trade request")
end)

tradeFrame.TradingFrame.RejectButton.MouseButton1Click:Connect(function()
	tradeEvent:FireServer("reject trade")
end)

tradeFrame.TradingFrame.AcceptButton.MouseButton1Click:Connect(function()
	tradeEvent:FireServer("accept trade")

	if tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 == Color3.fromRGB(58, 191, 232) then
		tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(40, 109, 152)
	else
		tradeFrame.TradingFrame.AcceptButton.BackgroundColor3 = Color3.fromRGB(58, 191, 232)
	end
end)
