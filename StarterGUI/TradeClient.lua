-- TradeClient.lua  
-- Client-side trading system for crate opening game
-- NOTE: This is a basic implementation. You'll need to create UI in StarterGui for full functionality

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Wait for trade system
local tradeRS = ReplicatedStorage:WaitForChild("TradeReplicatedStorage")
local tradeEvent = tradeRS:WaitForChild("TradeEvent")
local getTradeDataFunction = tradeRS:WaitForChild("GetTradeDataFunction")
local config = require(tradeRS:WaitForChild("TRADE_CONFIG"))

-- Current trade state
local currentTradeId = nil
local currentOtherPlayer = nil
local currentTrade = nil

-- Helper function to format numbers
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

-- Helper function to calculate offer value
local function calculateOfferValue(offer)
	local total = 0
	for _, item in ipairs(offer) do
		total = total + (item.Value * item.Amount)
	end
	return total
end

-- PUBLIC API: Send trade request to another player
function SendTradeRequest(targetPlayer)
	if not targetPlayer or targetPlayer == player then
		warn("Cannot trade with yourself")
		return
	end
	
	tradeEvent:FireServer("SendRequest", {targetPlayer = targetPlayer})
	print("📤 Sent trade request to " .. targetPlayer.Name)
end

-- PUBLIC API: Accept trade request
function AcceptTradeRequest(senderName)
	tradeEvent:FireServer("AcceptRequest", {senderName = senderName})
end

-- PUBLIC API: Reject trade request
function RejectTradeRequest()
	tradeEvent:FireServer("RejectRequest", {})
end

-- PUBLIC API: Cancel trade request
function CancelTradeRequest()
	tradeEvent:FireServer("CancelRequest", {})
end

-- PUBLIC API: Add item to current trade
function AddItemToTrade(robloxId)
	if not currentTradeId then
		warn("No active trade")
		return
	end
	
	tradeEvent:FireServer("AddItem", {tradeId = currentTradeId, robloxId = robloxId})
end

-- PUBLIC API: Remove item from current trade
function RemoveItemFromTrade(robloxId)
	if not currentTradeId then
		warn("No active trade")
		return
	end
	
	tradeEvent:FireServer("RemoveItem", {tradeId = currentTradeId, robloxId = robloxId})
end

-- PUBLIC API: Accept/toggle trade acceptance
function AcceptTrade()
	if not currentTradeId then
		warn("No active trade")
		return
	end
	
	tradeEvent:FireServer("AcceptTrade", {tradeId = currentTradeId})
end

-- PUBLIC API: Cancel current trade
function CancelTrade()
	if not currentTradeId then
		warn("No active trade")
		return
	end
	
	tradeEvent:FireServer("CancelTrade", {tradeId = currentTradeId})
	currentTradeId = nil
	currentOtherPlayer = nil
	currentTrade = nil
end

-- PUBLIC API: Get tradeable inventory
function GetTradeableInventory()
	local success, inventory = pcall(function()
		return getTradeDataFunction:InvokeServer("GetInventory", {})
	end)
	
	if success then
		return inventory
	else
		warn("Failed to get tradeable inventory")
		return {}
	end
end

-- PUBLIC API: Get trade history
function GetTradeHistory()
	local success, history = pcall(function()
		return getTradeDataFunction:InvokeServer("GetTradeHistory", {})
	end)
	
	if success then
		return history
	else
		warn("Failed to get trade history")
		return {}
	end
end

-- Listen for trade events from server
tradeEvent.OnClientEvent:Connect(function(eventType, data)
	
	if eventType == "RequestReceived" then
		local sender = data.sender
		print("📨 Trade request received from " .. sender.Name)
		
		-- TODO: Show UI notification to accept/reject
		-- For now, print to console
		print("Call AcceptTradeRequest('" .. sender.Name .. "') to accept")
		print("Call RejectTradeRequest() to reject")
		
	elseif eventType == "RequestSent" then
		local receiver = data.receiver
		print("📤 Trade request sent to " .. receiver.Name)
		
	elseif eventType == "RequestCancelled" then
		print("🚫 Trade request cancelled")
		
	elseif eventType == "TradeStarted" then
		currentTradeId = data.tradeId
		currentOtherPlayer = data.otherPlayer
		currentTrade = {
			player1Name = player.Name,
			player2Name = currentOtherPlayer.Name,
			player1Offer = {},
			player2Offer = {},
			player1Accepted = false,
			player2Accepted = false
		}
		
		print("🤝 Trade started with " .. currentOtherPlayer.Name)
		print("Trade ID: " .. currentTradeId)
		
		-- TODO: Open trade UI
		-- Get tradeable inventory
		local inventory = GetTradeableInventory()
		print("You have " .. #inventory .. " tradeable items")
		
	elseif eventType == "OfferUpdated" then
		currentTrade = data.trade
		
		local yourOffer = currentTrade.player1Name == player.Name and currentTrade.player1Offer or currentTrade.player2Offer
		local theirOffer = currentTrade.player1Name == player.Name and currentTrade.player2Offer or currentTrade.player1Offer
		
		local yourValue = calculateOfferValue(yourOffer)
		local theirValue = calculateOfferValue(theirOffer)
		
		print("📊 Trade updated:")
		print("  Your offer: " .. #yourOffer .. " items (Value: " .. formatNumber(yourValue) .. ")")
		print("  Their offer: " .. #theirOffer .. " items (Value: " .. formatNumber(theirValue) .. ")")
		
		-- TODO: Update trade UI
		
	elseif eventType == "AcceptanceChanged" then
		currentTrade = data.trade
		
		local youAccepted = currentTrade.player1Name == player.Name and currentTrade.player1Accepted or currentTrade.player2Accepted
		local theyAccepted = currentTrade.player1Name == player.Name and currentTrade.player2Accepted or currentTrade.player1Accepted
		
		print("✅ Acceptance changed:")
		print("  You: " .. (youAccepted and "ACCEPTED" or "not accepted"))
		print("  Them: " .. (theyAccepted and "ACCEPTED" or "not accepted"))
		
		if youAccepted and theyAccepted then
			print("⏳ Trade will complete in " .. config.TimeBeforeTradeConfirmed .. " seconds...")
		end
		
		-- TODO: Update trade UI
		
	elseif eventType == "TradeCompleted" then
		print("✅ Trade completed successfully!")
		currentTradeId = nil
		currentOtherPlayer = nil
		currentTrade = nil
		
		-- TODO: Close trade UI and refresh inventory
		
	elseif eventType == "TradeCancelled" then
		local message = data.message or "Trade was cancelled"
		print("🚫 " .. message)
		currentTradeId = nil
		currentOtherPlayer = nil
		currentTrade = nil
		
		-- TODO: Close trade UI
		
	elseif eventType == "TradeFailed" then
		local message = data.message or "Trade failed"
		warn("❌ " .. message)
		currentTradeId = nil
		currentOtherPlayer = nil
		currentTrade = nil
		
		-- TODO: Close trade UI
		
	elseif eventType == "Error" then
		warn("⚠️ Trade error: " .. data.message)
	end
end)

-- Example commands (You can test these in the console or integrate with your UI)
-- To send a trade request to a player: SendTradeRequest(game.Players.PlayerName)
-- To add an item (by RobloxId) to trade: AddItemToTrade(12345)
-- To remove an item: RemoveItemFromTrade(12345)
-- To accept the trade: AcceptTrade()
-- To cancel the trade: CancelTrade()

print("✅ Trade Client loaded - Use SendTradeRequest(player) to start trading")
print("📖 Trading API available:")
print("  - SendTradeRequest(player)")
print("  - AcceptTradeRequest(senderName)")
print("  - RejectTradeRequest()")
print("  - AddItemToTrade(robloxId)")
print("  - RemoveItemFromTrade(robloxId)")
print("  - AcceptTrade()")
print("  - CancelTrade()")
print("  - GetTradeableInventory()")
print("  - GetTradeHistory()")
