-- TabManager.lua
-- Unified tab system for all UI frames (Inventory, Index, Mastery, Marketplace, Trading)
-- Ensures only one tab is open at a time while preserving critical overlays (trade requests)

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent

-- Wait for all frames
local inventoryFrame = gui:WaitForChild("Inventory", 5)
local indexFrame = gui:WaitForChild("Index", 5)
local masteryFrame = gui:WaitForChild("Mastery", 5)
local marketplaceFrame = gui:WaitForChild("Marketplace", 5)
local tradingFrame = gui:WaitForChild("Trading", 5)

-- Wait for all open buttons
local inventoryOpenButton = gui:WaitForChild("InventoryOpen", 5)
local indexOpenButton = gui:WaitForChild("IndexOpen", 5)
local masteryOpenButton = gui:WaitForChild("MasteryOpen", 5)
local marketplaceOpenButton = gui:WaitForChild("MarketplaceOpen", 5)
local tradingOpenButton = gui:WaitForChild("TradingOpen", 5)

-- Get trading sub-frames for special handling
local sendTradesFrame = tradingFrame and tradingFrame:WaitForChild("SendTradesFrame", 5)
local tradeRequestFrame = tradingFrame and tradingFrame:WaitForChild("TradeRequestFrame", 5)
local tradeFrame = tradingFrame and tradingFrame:WaitForChild("TradeFrame", 5)
local tradeHistoryFrame = tradingFrame and tradingFrame:WaitForChild("TradeHistoryFrame", 5)
local viewInventoryFrame = tradingFrame and tradingFrame:WaitForChild("ViewInventoryFrame", 5)

-- Table of all frames for easy iteration
local allFrames = {
        Inventory = inventoryFrame,
        Index = indexFrame,
        Mastery = masteryFrame,
        Marketplace = marketplaceFrame,
        Trading = tradingFrame
}

-- Track currently open frame
local currentOpenFrame = nil

-- Function to close all frames
local function closeAllFrames()
        for frameName, frame in pairs(allFrames) do
                if frame then
                        if frameName == "Trading" then
                                -- For Trading, only hide the main content (SendTradesFrame)
                                -- Keep the parent Trading frame visible to allow overlays (TradeRequestFrame, TradeFrame) to work
                                if sendTradesFrame then
                                        sendTradesFrame.Visible = false
                                end
                                if tradeHistoryFrame then
                                        tradeHistoryFrame.Visible = false
                                end
                                if viewInventoryFrame then
                                        viewInventoryFrame.Visible = false
                                end
                                -- Note: TradeRequestFrame and TradeFrame control their own visibility based on trading state
                        else
                                -- For other frames, hide the entire frame
                                frame.Visible = false
                        end
                end
        end
        currentOpenFrame = nil
end

-- Function to open a specific frame and close all others
local function openFrame(frameName)
        if not allFrames[frameName] then
                warn("Frame " .. frameName .. " not found")
                return
        end
        
        -- Close all frames first
        closeAllFrames()
        
        if frameName == "Trading" then
                -- For Trading, keep the parent frame visible and show SendTradesFrame
                tradingFrame.Visible = true
                if sendTradesFrame then
                        sendTradesFrame.Visible = true
                end
        else
                -- For other frames, just make them visible
                allFrames[frameName].Visible = true
        end
        
        currentOpenFrame = frameName
end

-- Initialize: Close all frames on start but keep Trading frame visible for overlays
for frameName, frame in pairs(allFrames) do
        if frame then
                if frameName == "Trading" then
                        -- Keep Trading frame visible but hide its content
                        tradingFrame.Visible = true
                        if sendTradesFrame then
                                sendTradesFrame.Visible = false
                        end
                        if tradeFrame then
                                tradeFrame.Visible = false
                        end
                        if tradeRequestFrame then
                                tradeRequestFrame.Visible = false
                        end
                        if tradeHistoryFrame then
                                tradeHistoryFrame.Visible = false
                        end
                        if viewInventoryFrame then
                                viewInventoryFrame.Visible = false
                        end
                else
                        frame.Visible = false
                end
        end
end

-- Connect buttons to their respective frames with toggle functionality
if inventoryOpenButton then
        inventoryOpenButton.MouseButton1Click:Connect(function()
                if currentOpenFrame == "Inventory" then
                        closeAllFrames()
                else
                        openFrame("Inventory")
                end
        end)
end

if indexOpenButton then
        indexOpenButton.MouseButton1Click:Connect(function()
                if currentOpenFrame == "Index" then
                        closeAllFrames()
                else
                        openFrame("Index")
                end
        end)
end

if masteryOpenButton then
        masteryOpenButton.MouseButton1Click:Connect(function()
                if currentOpenFrame == "Mastery" then
                        closeAllFrames()
                else
                        openFrame("Mastery")
                end
        end)
end

if marketplaceOpenButton then
        marketplaceOpenButton.MouseButton1Click:Connect(function()
                if currentOpenFrame == "Marketplace" then
                        closeAllFrames()
                else
                        openFrame("Marketplace")
                end
        end)
end

if tradingOpenButton then
        tradingOpenButton.MouseButton1Click:Connect(function()
                if currentOpenFrame == "Trading" then
                        closeAllFrames()
                else
                        openFrame("Trading")
                end
        end)
end

-- Handle individual close buttons within frames (if they exist)
-- Inventory close button
local inventoryCloseButton = inventoryFrame and inventoryFrame:FindFirstChild("Close")
if inventoryCloseButton then
        inventoryCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

-- Index close button
local indexCloseButton = indexFrame and indexFrame:FindFirstChild("Close")
if indexCloseButton then
        indexCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

-- Mastery close button
local masteryCloseButton = masteryFrame and masteryFrame:FindFirstChild("Close")
if masteryCloseButton then
        masteryCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

-- Marketplace close button
local marketplaceCloseButton = marketplaceFrame and marketplaceFrame:FindFirstChild("Close")
if marketplaceCloseButton then
        marketplaceCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

-- Trading close buttons
-- SendTradesFrame close button
if sendTradesFrame then
        local tradingCloseButton = sendTradesFrame:FindFirstChild("CloseButton")
        if tradingCloseButton then
                tradingCloseButton.MouseButton1Click:Connect(closeAllFrames)
        end
end

-- ViewInventoryFrame close button
if viewInventoryFrame then
        local viewInvCloseButton = viewInventoryFrame:FindFirstChild("Close")
        if viewInvCloseButton then
                viewInvCloseButton.MouseButton1Click:Connect(closeAllFrames)
        end
end

-- TradeHistoryFrame close button
if tradeHistoryFrame then
        local historyCloseButton = tradeHistoryFrame:FindFirstChild("CloseButton")
        if historyCloseButton then
                historyCloseButton.MouseButton1Click:Connect(closeAllFrames)
        end
end

print("TabManager initialized - All tabs ready with trade overlay support")
