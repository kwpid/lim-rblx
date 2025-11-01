local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent

-- Get the main UI elements
local inventoryFrame = gui:WaitForChild("Inventory", 5)
local indexFrame = gui:WaitForChild("Index", 5)
local inventoryOpenButton = gui:WaitForChild("InventoryOpen", 5)
local indexOpenButton = gui:WaitForChild("IndexOpen", 5)

if not inventoryFrame then
  warn("❌ Inventory frame not found in MainUI")
  return
end

if not indexFrame then
  warn("❌ Index frame not found in MainUI")
  return
end

if not inventoryOpenButton then
  warn("❌ InventoryOpen button not found in MainUI")
  return
end

if not indexOpenButton then
  warn("❌ IndexOpen button not found in MainUI")
  return
end

-- Start with both frames hidden
inventoryFrame.Visible = false
indexFrame.Visible = false

-- Function to open Inventory and close Index
local function openInventory()
  inventoryFrame.Visible = true
  indexFrame.Visible = false
end

-- Function to open Index and close Inventory
local function openIndex()
  indexFrame.Visible = true
  inventoryFrame.Visible = false
end

-- Connect button clicks
inventoryOpenButton.MouseButton1Click:Connect(openInventory)
indexOpenButton.MouseButton1Click:Connect(openIndex)

print("✅ MainUI toggle system loaded")
