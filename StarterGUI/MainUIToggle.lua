local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent

local inventoryFrame = gui:WaitForChild("Inventory", 5)
local indexFrame = gui:WaitForChild("Index", 5)
local inventoryOpenButton = gui:WaitForChild("InventoryOpen", 5)
local indexOpenButton = gui:WaitForChild("IndexOpen", 5)


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
