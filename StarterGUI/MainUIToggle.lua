local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent

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

inventoryFrame.Visible = false
indexFrame.Visible = false

local function openInventory()
  inventoryFrame.Visible = true
  indexFrame.Visible = false
end

local function openIndex()
  indexFrame.Visible = true
  inventoryFrame.Visible = false
end

inventoryOpenButton.MouseButton1Click:Connect(openInventory)
indexOpenButton.MouseButton1Click:Connect(openIndex)

print("✅ MainUI toggle system loaded")
