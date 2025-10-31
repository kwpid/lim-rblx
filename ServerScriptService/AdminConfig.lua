-- AdminConfig.lua
-- Configuration for admin users

local AdminConfig = {}

-- Whitelisted admin user IDs
AdminConfig.AdminUserIds = {
  1547280148,  -- First admin
  -- Add more admin IDs here
}

-- Check if a player is an admin
function AdminConfig:IsAdmin(player)
  for _, adminId in ipairs(self.AdminUserIds) do
    if player.UserId == adminId then
      return true
    end
  end
  return false
end

return AdminConfig
