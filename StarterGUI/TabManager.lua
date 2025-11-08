-- TabManager.lua
-- Unified tab system for Inventory, Index, Mastery, and Marketplace
-- Ensures only one tab is open at a time
-- Note: Trading UI is handled separately and is not part of this tab system

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent

-- Wait for all frames (Trading excluded - it manages itself)
local inventoryFrame = gui:WaitForChild("Inventory", 5)
local indexFrame = gui:WaitForChild("Index", 5)
local masteryFrame = gui:WaitForChild("Mastery", 5)
local marketplaceFrame = gui:WaitForChild("Marketplace", 5)

-- Wait for all open buttons
local inventoryOpenButton = gui:WaitForChild("InventoryOpen", 5)
local indexOpenButton = gui:WaitForChild("IndexOpen", 5)
local masteryOpenButton = gui:WaitForChild("MasteryOpen", 5)
local marketplaceOpenButton = gui:WaitForChild("MarketplaceOpen", 5)

-- Table of all frames for easy iteration
local allFrames = {
	Inventory = inventoryFrame,
	Index = indexFrame,
	Mastery = masteryFrame,
	Marketplace = marketplaceFrame
}

-- Track currently open frame
local currentOpenFrame = nil

-- Function to close all frames
local function closeAllFrames()
	for frameName, frame in pairs(allFrames) do
		if frame then
			frame.Visible = false
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
	
	-- Open the requested frame
	allFrames[frameName].Visible = true
	currentOpenFrame = frameName
end

-- Initialize: Close all frames on start
closeAllFrames()

-- Connect buttons to their respective frames
if inventoryOpenButton then
	inventoryOpenButton.MouseButton1Click:Connect(function()
		openFrame("Inventory")
	end)
end

if indexOpenButton then
	indexOpenButton.MouseButton1Click:Connect(function()
		openFrame("Index")
	end)
end

if masteryOpenButton then
	masteryOpenButton.MouseButton1Click:Connect(function()
		openFrame("Mastery")
	end)
end

if marketplaceOpenButton then
	marketplaceOpenButton.MouseButton1Click:Connect(function()
		openFrame("Marketplace")
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

print("TabManager initialized - 4 tabs ready (Inventory, Index, Mastery, Marketplace)")
