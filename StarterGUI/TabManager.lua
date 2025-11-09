local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = script.Parent

local inventoryFrame = gui:WaitForChild("Inventory", 5)
local indexFrame = gui:WaitForChild("Index", 5)
local masteryFrame = gui:WaitForChild("Mastery", 5)
local marketplaceFrame = gui:WaitForChild("Marketplace", 5)
local tradingFrame = gui:WaitForChild("Trading", 5)

local buttonContainer = gui:WaitForChild("ButtonContainer", 5)

local inventoryOpenButton = buttonContainer:WaitForChild("InventoryOpen", 5)
local indexOpenButton = buttonContainer:WaitForChild("IndexOpen", 5)
local masteryOpenButton = buttonContainer:WaitForChild("MasteryOpen", 5)
local marketplaceOpenButton = buttonContainer:WaitForChild("MarketplaceOpen", 5)
local tradingOpenButton = buttonContainer:WaitForChild("TradingOpen", 5)

local sendTradesFrame = tradingFrame and tradingFrame:WaitForChild("SendTradesFrame", 5)
local tradeRequestFrame = tradingFrame and tradingFrame:WaitForChild("TradeRequestFrame", 5)
local tradeFrame = tradingFrame and tradingFrame:WaitForChild("TradeFrame", 5)
local tradeHistoryFrame = tradingFrame and tradingFrame:WaitForChild("TradeHistoryFrame", 5)
local viewInventoryFrame = tradingFrame and tradingFrame:WaitForChild("ViewInventoryFrame", 5)

local allFrames = {
        Inventory = inventoryFrame,
        Index = indexFrame,
        Mastery = masteryFrame,
        Marketplace = marketplaceFrame,
        Trading = tradingFrame
}

local currentOpenFrame = nil

local function closeAllFrames()
        for frameName, frame in pairs(allFrames) do
                if frame then
                        if frameName == "Trading" then
                                if sendTradesFrame then
                                        sendTradesFrame.Visible = false
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
        currentOpenFrame = nil
end

local function openFrame(frameName)
        if not allFrames[frameName] then
                warn("Frame " .. frameName .. " not found")
                return
        end
        closeAllFrames()
        if frameName == "Trading" then
                tradingFrame.Visible = true
                if sendTradesFrame then
                        sendTradesFrame.Visible = true
                end
        else
                allFrames[frameName].Visible = true
        end
        currentOpenFrame = frameName
end

for frameName, frame in pairs(allFrames) do
        if frame then
                if frameName == "Trading" then
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

local inventoryCloseButton = inventoryFrame and inventoryFrame:FindFirstChild("Close")
if inventoryCloseButton then
        inventoryCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

local indexCloseButton = indexFrame and indexFrame:FindFirstChild("Close")
if indexCloseButton then
        indexCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

local masteryCloseButton = masteryFrame and masteryFrame:FindFirstChild("Close")
if masteryCloseButton then
        masteryCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

local marketplaceCloseButton = marketplaceFrame and marketplaceFrame:FindFirstChild("Close")
if marketplaceCloseButton then
        marketplaceCloseButton.MouseButton1Click:Connect(closeAllFrames)
end

if sendTradesFrame then
        local tradingCloseButton = sendTradesFrame:FindFirstChild("CloseButton")
        if tradingCloseButton then
                tradingCloseButton.MouseButton1Click:Connect(closeAllFrames)
        end
end

if viewInventoryFrame then
        local viewInvCloseButton = viewInventoryFrame:FindFirstChild("Close")
        if viewInvCloseButton then
                viewInvCloseButton.MouseButton1Click:Connect(closeAllFrames)
        end
end

if tradeHistoryFrame then
        local historyCloseButton = tradeHistoryFrame:FindFirstChild("CloseButton")
        if historyCloseButton then
                historyCloseButton.MouseButton1Click:Connect(closeAllFrames)
        end
end
