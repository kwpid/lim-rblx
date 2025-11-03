local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent

local inventoryFrame = gui:WaitForChild("Inventory", 5)
local indexFrame = gui:WaitForChild("Index", 5)
local inventoryOpenButton = gui:WaitForChild("InventoryOpen", 5)
local indexOpenButton = gui:WaitForChild("IndexOpen", 5)

if not inventoryFrame then
  warn("inventory frame not found in mainui")
  return
end

if not indexFrame then
  warn("index frame not found in mainui")
  return
end

if not inventoryOpenButton then
  warn("inventoryopen button not found in mainui")
  return
end

if not indexOpenButton then
  warn("indexopen button not found in mainui")
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
