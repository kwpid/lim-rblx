local config = {}


-------Settings you can change-------
config.MaxSlots = 25
config.TimeBeforeTradeConfirmed = 5
-------------------------------------


--Funcion for getting all the tools a player has
function config.GetTools(plr)

  local plrTools = plr.Backpack:GetChildren()

  local toolEquipped = plr.Character:FindFirstChildOfClass("Tool")
  if toolEquipped then
    table.insert(plrTools, toolEquipped)
  end

  return plrTools
end

return config